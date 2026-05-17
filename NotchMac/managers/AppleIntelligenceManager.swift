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

@MainActor
final class AppleIntelligenceManager {
    static let shared = AppleIntelligenceManager()
    private init() {}

    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
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

    func ask(question: String, context: String, history: [ChatMessage]) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), isAvailable {
            let session = LanguageModelSession(instructions: """
            You are answering questions about a specific PDF document. Use only the provided document context to answer. If the answer is not in the document, say so plainly. Answer in the same language as the question. Keep answers concise.

            DOCUMENT:
            \(truncated(context, limit: 14_000))
            """)
            var convo = ""
            for m in history.suffix(10) {
                let tag = m.role == .user ? "User" : "Assistant"
                convo += "\(tag): \(m.text)\n"
            }
            convo += "User: \(question)"
            do {
                let response = try await session.respond(to: convo)
                return response.content
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
