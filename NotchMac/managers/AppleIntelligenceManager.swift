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
    let id: UUID
    let role: Role
    var text: String

    init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
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

    // One persistent chat session per document. The document is sent in the FIRST
    // prompt (not in instructions — that hangs); follow-up questions send only the
    // question, and Foundation Models keeps the running transcript itself. This is
    // what stops the model from echoing the conversation back ("Q: … A: …").
    private var chatSessionBox: Any?
    private var chatPrimed = false

    /// Drop the chat session (call when a new PDF loads or the chat closes).
    func endChat() {
        chatSessionBox = nil
        chatPrimed = false
    }

    /// Answers a question about the document. Short instructions; the document goes
    /// in the first prompt; later turns reuse the same session so history is kept
    /// internally (no manual transcript in the prompt, so no echoing).
    func ask(question: String, context: String, history: [ChatMessage], allowRetry: Bool = true) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), isAvailable {
            let session: LanguageModelSession
            if let existing = chatSessionBox as? LanguageModelSession {
                session = existing
            } else {
                session = LanguageModelSession(instructions: """
                You are a helpful assistant answering questions about a document the user shares. Use only that document; if the answer isn't in it, say so plainly. Reply in the same language as the question and keep answers short and direct. Plain text only — do NOT repeat the question, do NOT prefix answers with "A:" or "Q:", and use **bold** only for a few key terms.
                """)
                chatSessionBox = session
                chatPrimed = false
            }

            do {
                let prompt: String
                if chatPrimed {
                    prompt = question
                } else {
                    prompt = """
                    Here is the document. Read it, then answer my questions about it.

                    DOCUMENT:
                    \(truncated(context, limit: 12_000))

                    First question: \(question)
                    """
                    chatPrimed = true
                }
                let response = try await session.respond(to: prompt)
                return response.content
            } catch let error as LanguageModelSession.GenerationError {
                // Rebuild + re-prime once on context overflow instead of failing.
                if case .exceededContextWindowSize = error, allowRetry {
                    chatSessionBox = nil
                    chatPrimed = false
                    return try await ask(question: question, context: context, history: history, allowRetry: false)
                }
                throw AppleIntelligenceError.sessionFailed(error.localizedDescription)
            } catch {
                throw AppleIntelligenceError.sessionFailed(error.localizedDescription)
            }
        }
        #endif
        throw AppleIntelligenceError.unavailable
    }

    private func truncated(_ s: String, limit: Int) -> String {
        if s.count <= limit { return s }
        return String(s.prefix(limit)) + "\n…[truncated]"
    }
}
