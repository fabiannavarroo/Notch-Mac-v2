//
//  AppleIntelligencePDFSummaryOverlay.swift
//  NotchMac
//
//  Expanded-notch overlay: PDF summary + on-device chat over the document.
//

import SwiftUI
import AppKit

@MainActor
struct AppleIntelligencePDFSummaryOverlay: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var state = AppleIntelligencePDFState.shared
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @State private var input: String = ""
    @FocusState private var inputFocused: Bool
    private let transcriptHeight = summaryNotchSize.height - 92

    var body: some View {
        VStack(spacing: 6) {
            header
            Divider().background(Color.white.opacity(0.08))
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    summaryBlock
                    ForEach(state.messages) { msg in
                        ChatBubble(message: msg)
                    }
                    // Animated "typing" dots while the model prepares the answer.
                    if state.isAsking {
                        ThinkingBubble()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: transcriptHeight)
            inputBar
        }
        // Fill the notch width so the parent's rounded notch shape clips the corners
        // exactly like the other interfaces (don't force a fixed width — that overflows
        // the window and produces square corners). The parent already paints the black
        // background and applies the notch clip shape.
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 8)
        // Allow the (normally non-key) notch panel to take keyboard focus while the
        // chat is on screen, so the text field accepts clicks and typing.
        .background(NotchKeyWindowActivator())
        .onAppear {
            Task { @MainActor in
                for delay in [0.1, 0.3, 0.6] {
                    try? await Task.sleep(for: .seconds(delay))
                    inputFocused = true
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(LinearGradient(colors: [.purple, .pink, .cyan], startPoint: .leading, endPoint: .trailing))
            VStack(alignment: .leading, spacing: 1) {
                Text("Summary")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                if !state.fileName.isEmpty {
                    Text(state.fileName)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            Button {
                close()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private var summaryBlock: some View {
        if !state.summary.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Summary")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .textCase(.uppercase)
                Text(MarkdownText.render(state.summary))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineSpacing(2)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
            )
            .padding(.top, 4)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 6) {
            TextField("Ask about this PDF…", text: $input)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                )
                .focused($inputFocused)
                .onSubmit { send() }
                .disabled(state.isAsking)
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(canSend ? AnyShapeStyle(LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(0.25)))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            inputFocused = true
        }
    }

    private var canSend: Bool {
        !state.isAsking && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        let q = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !state.isAsking else { return }
        input = ""
        state.ask(q)
    }

    private func close() {
        inputFocused = false
        state.reset()
        coordinator.currentView = .home
        vm.close()
    }
}

/// Bridges into the hosting notch panel to (de)authorize keyboard focus. The notch
/// is non-key by default to avoid stealing focus on hover; this enables it only
/// while the PDF chat is visible so the input field can be clicked and typed into.
private struct NotchKeyWindowActivator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        // Defer until the view is in a window. Activating the (accessory) app is
        // required so keystrokes route to our panel's text field, not the app the
        // user was last in.
        DispatchQueue.main.async {
            Self.activateKeyboard(for: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // SwiftUI can create/update this bridge before the view is attached to its
        // panel. Retrying here makes the text field reliably typable after redraws.
        DispatchQueue.main.async {
            Self.activateKeyboard(for: nsView)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        if let panel = nsView.window as? (any KeyboardActivatablePanel) {
            panel.allowsKeyboardActivation = false
            panel.makeFirstResponder(nil)
        }
        // Hand activation back to whatever app the user was using before.
        NSApp.deactivate()
    }

    private static func activateKeyboard(for view: NSView) {
        guard let panel = view.window as? (any KeyboardActivatablePanel) else { return }
        panel.allowsKeyboardActivation = true
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
    }
}

/// Animated "typing" indicator (three pulsing dots) shown while the model is
/// preparing the first token of an answer.
private struct ThinkingBubble: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(phase == i ? 0.95 : 0.28))
                        .frame(width: 6, height: 6)
                        .scaleEffect(phase == i ? 1.0 : 0.7)
                }
            }
            .animation(.easeInOut(duration: 0.28), value: phase)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.07))
            )
            Spacer(minLength: 24)
        }
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 24) }
            Text(MarkdownText.render(message.text))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.95))
                .lineSpacing(2)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(message.role == .user
                              ? AnyShapeStyle(LinearGradient(colors: [Color.purple.opacity(0.75), Color.pink.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(Color.white.opacity(0.07)))
                )
            if message.role == .assistant { Spacer(minLength: 24) }
        }
    }
}

/// Renders the LLM's Markdown (bold, italic, inline code, lists, headings) into a
/// styled `AttributedString` so the chat doesn't show raw `**` markers. Line breaks
/// are preserved; list markers become bullets; heading hashes become bold lines.
enum MarkdownText {
    static func render(_ raw: String) -> AttributedString {
        let cleaned = preprocess(raw)
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        if let attr = try? AttributedString(markdown: cleaned, options: options) {
            return attr
        }
        return AttributedString(cleaned)
    }

    private static func preprocess(_ raw: String) -> String {
        raw.components(separatedBy: "\n").map { line -> String in
            // "### Title" -> bold line (inline parser handles the ** emphasis).
            if let r = line.range(of: #"^\s{0,3}#{1,6}\s+"#, options: .regularExpression) {
                let title = line[r.upperBound...].trimmingCharacters(in: .whitespaces)
                return title.isEmpty ? "" : "**\(title)**"
            }
            // "- item" / "* item" / "+ item" -> bullet, keeping indentation.
            if let r = line.range(of: #"^(\s*)[-*+]\s+"#, options: .regularExpression) {
                let indent = line[r].prefix { $0 == " " }
                return "\(indent)•  \(line[r.upperBound...])"
            }
            return line
        }
        .joined(separator: "\n")
    }
}
