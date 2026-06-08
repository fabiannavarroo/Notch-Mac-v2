//
//  AppleIntelligenceManager.swift
//  NotchMac
//
//  PDF summarization + chat backed by Apple Foundation Models.
//
//  Privacy: 100% on-device. No network calls, no telemetry. PDF text
//  never leaves the user's machine. Requires Apple Intelligence
//  (macOS 26+ with supported Mac silicon). Falls back to a clear
//  "unavailable" error on older systems or hardware without AI.
//

import Foundation
import AppKit
import PDFKit

#if canImport(FoundationModels)
import FoundationModels
#endif

struct ChatMessage: Identifiable, Equatable, Hashable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}

enum AppleIntelligenceError: LocalizedError {
    case unavailable
    case pdfUnreadable
    case emptyPDF
    case sessionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Apple Intelligence is unavailable on this Mac."
        case .pdfUnreadable: return "Could not read the PDF."
        case .emptyPDF: return "The PDF contains no extractable text."
        case .sessionFailed(let msg): return msg
        }
    }
}

enum AppleIntelligenceStatus: Equatable {
    case available
    case unsupportedOS
    case appleIntelligenceNotEnabled
    case modelNotReady
    case deviceNotEligible
    case other(String)

    var isAvailable: Bool { self == .available }

    var userMessage: String {
        switch self {
        case .available:
            return "Available on this Mac"
        case .unsupportedOS:
            return "Requires macOS 26 Tahoe or later"
        case .appleIntelligenceNotEnabled:
            return "Enable Apple Intelligence in System Settings → Apple Intelligence & Siri"
        case .modelNotReady:
            return "Apple Intelligence model is still downloading. Try again later."
        case .deviceNotEligible:
            return "This Mac or Siri language is not eligible for Apple Intelligence"
        case .other(let s):
            return "Unavailable: \(s)"
        }
    }
}

@MainActor
final class AppleIntelligenceManager {
    static let shared = AppleIntelligenceManager()
    private init() {}

    var isAvailable: Bool { status.isAvailable }

    var status: AppleIntelligenceStatus {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                switch reason {
                case .appleIntelligenceNotEnabled:
                    return .appleIntelligenceNotEnabled
                case .modelNotReady:
                    return .modelNotReady
                case .deviceNotEligible:
                    return .deviceNotEligible
                @unknown default:
                    return .other(String(describing: reason))
                }
            @unknown default:
                return .other("unknown availability")
            }
        }
        #endif
        return .unsupportedOS
    }

    func extractText(from pdfURL: URL) throws -> String {
        guard let doc = PDFDocument(url: pdfURL) else { throw AppleIntelligenceError.pdfUnreadable }
        var chunks: [String] = []
        for i in 0..<doc.pageCount {
            if let s = doc.page(at: i)?.string, !s.isEmpty { chunks.append(s) }
        }
        let text = chunks.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw AppleIntelligenceError.emptyPDF }
        return text
    }

    func summarize(pdf url: URL) async throws -> (summary: String, context: String) {
        let text = try extractText(from: url)
        let summary = try await summarize(text: text)
        return (summary, text)
    }

    func summarize(text: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), isAvailable {
            let session = LanguageModelSession(instructions: """
            You are a concise document summarizer. Given the text of a PDF, produce a clear, well-structured summary in the same language as the document. Use short paragraphs and bullet points for key facts. Keep it under 400 words.
            """)
            let prompt = "Summarize this document:\n\n\(truncated(text, limit: 16_000))"
            do {
                let response = try await session.respond(to: prompt)
                return response.content
            } catch {
                throw AppleIntelligenceError.sessionFailed(error.localizedDescription)
            }
        }
        #endif
        throw AppleIntelligenceError.unavailable
    }

    // Persistent chat session for the active document. Reusing one session keeps
    // the document in context only once (no costly re-prefill per question, which
    // looked like a hang) and lets Foundation Models manage the running transcript.
    // Stored as `Any?` so the property doesn't require macOS 26 availability.
    private var chatSessionBox: Any?

    /// Drop the current chat session (e.g. when a new PDF is loaded or the chat closes).
    func endChat() {
        chatSessionBox = nil
    }

    func ask(question: String, context: String, history: [ChatMessage]) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), isAvailable {
            let session = chatSession(for: context)

            // Issuing a request while one is in flight traps in Foundation Models.
            guard !session.isResponding else {
                throw AppleIntelligenceError.sessionFailed("Still answering the previous question — please wait.")
            }

            do {
                let response = try await session.respond(to: question)
                return response.content
            } catch let error as LanguageModelSession.GenerationError {
                // Context overflow (long doc + long chat): rebuild a fresh session
                // with just the document and retry once, instead of crashing.
                if case .exceededContextWindowSize = error {
                    chatSessionBox = nil
                    let fresh = chatSession(for: context)
                    let response = try await fresh.respond(to: question)
                    return response.content
                }
                throw AppleIntelligenceError.sessionFailed(error.localizedDescription)
            } catch {
                throw AppleIntelligenceError.sessionFailed(error.localizedDescription)
            }
        }
        #endif
        throw AppleIntelligenceError.unavailable
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func chatSession(for context: String) -> LanguageModelSession {
        if let existing = chatSessionBox as? LanguageModelSession {
            return existing
        }
        let session = LanguageModelSession(instructions: """
        You answer questions about the PDF document below. Use only this document; \
        if the answer is not in it, say so plainly. Reply in the same language as the \
        question, be concise, and format with simple Markdown (use ** for bold and \
        - for bullet lists).

        DOCUMENT:
        \(truncated(context, limit: 10_000))
        """)
        chatSessionBox = session
        return session
    }
    #endif

    private func truncated(_ s: String, limit: Int) -> String {
        if s.count <= limit { return s }
        return String(s.prefix(limit)) + "\n…[truncated]"
    }
}
