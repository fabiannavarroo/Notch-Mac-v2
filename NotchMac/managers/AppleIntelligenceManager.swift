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
import Vision

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
    case ocrFailed
    case sessionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Apple Intelligence is unavailable on this Mac."
        case .pdfUnreadable: return "Could not read the PDF."
        case .emptyPDF: return "The PDF has no readable text, even after OCR."
        case .ocrFailed: return "Could not recognize text in the scanned PDF."
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

    /// Extracts the document text off the main thread. Uses PDFKit's embedded text
    /// when present; for scanned PDFs (image-only pages) it falls back to on-device
    /// OCR with Vision. Heavy work (PDF render + OCR) runs on a detached task so the
    /// `@MainActor` UI never blocks.
    func extractText(from pdfURL: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try Self.extract(from: pdfURL)
        }.value
    }

    func summarize(pdf url: URL) async throws -> (summary: String, context: String) {
        let text = try await extractText(from: url)
        let summary = try await summarize(text: text)
        return (summary, text)
    }

    // MARK: - Text extraction (nonisolated, runs off the main thread)

    nonisolated private static func extract(from pdfURL: URL) throws -> String {
        guard let doc = PDFDocument(url: pdfURL) else { throw AppleIntelligenceError.pdfUnreadable }
        let embedded = embeddedText(doc)
        // Embedded text is enough for normal (text-layer) PDFs; bail early to skip OCR.
        if isEnoughText(embedded, pageCount: doc.pageCount) { return embedded }
        // Scanned / image-only PDF: OCR the rendered pages.
        let ocr = ocrText(doc)
        let best = ocr.count > embedded.count ? ocr : embedded
        let trimmed = best.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppleIntelligenceError.emptyPDF }
        return trimmed
    }

    nonisolated private static func embeddedText(_ doc: PDFDocument) -> String {
        var chunks: [String] = []
        for i in 0..<doc.pageCount {
            if let s = doc.page(at: i)?.string, !s.isEmpty { chunks.append(s) }
        }
        return chunks.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when the embedded text layer looks real (not a few stray glyphs from a scan).
    nonisolated private static func isEnoughText(_ text: String, pageCount: Int) -> Bool {
        let minChars = max(40, pageCount * 10)
        return text.count >= minChars
    }

    /// On-device OCR of each page via Vision. Renders the page to a bitmap and runs
    /// `VNRecognizeTextRequest` (accurate, with language correction). Capped to a
    /// sane page count so a huge scan can't run unbounded.
    nonisolated private static func ocrText(_ doc: PDFDocument) -> String {
        let maxPages = min(doc.pageCount, 30)
        var out: [String] = []
        for i in 0..<maxPages {
            guard let page = doc.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width > 0, bounds.height > 0 else { continue }
            let scale: CGFloat = 2.0 // upscale so small print is legible to Vision
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let thumb = page.thumbnail(of: size, for: .mediaBox)
            guard let cg = thumb.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do {
                try handler.perform([request])
                let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                if !lines.isEmpty { out.append(lines.joined(separator: "\n")) }
            } catch {
                continue // one bad page shouldn't sink the whole document
            }
        }
        return out.joined(separator: "\n\n")
    }

    func summarize(text: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), isAvailable {
            let session = LanguageModelSession(instructions: """
            You are a concise document summarizer. Given the text of a PDF, produce a clear, well-structured summary in the same language as the document. Use short paragraphs and bullet points for key facts. Keep it under 400 words.
            """)
            // Foundation Models has a small context window (~4k tokens incl. output),
            // so keep the document slice well under that to avoid a context-overflow throw.
            let prompt = "Summarize this document:\n\n\(truncated(text, limit: 9_000))"
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

    /// Answers a question about the document. Mirrors `summarize` exactly (short
    /// instructions, document + history carried in the *prompt*, fresh session,
    /// non-streaming `respond`) because that path is proven to work — putting a large
    /// document in the session `instructions` is what made earlier attempts hang.
    func ask(question: String, context: String, history: [ChatMessage]) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), isAvailable {
            let session = LanguageModelSession(instructions: """
            You answer questions about the document provided in the prompt. Use only that document. If the answer is not in it, say so plainly. Reply in the same language as the question, be concise, and use simple Markdown (** for bold, - for bullet lists).
            """)
            var convo = ""
            for m in history.suffix(6) {
                convo += (m.role == .user ? "Q: " : "A: ") + m.text + "\n"
            }
            // Keep the document slice small so document + history + question + answer
            // all fit Foundation Models' context window.
            let prompt = """
            DOCUMENT:
            \(truncated(context, limit: 5_000))

            \(convo)Question: \(question)
            """
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

    private func truncated(_ s: String, limit: Int) -> String {
        if s.count <= limit { return s }
        return String(s.prefix(limit)) + "\n…[truncated]"
    }
}
