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
    @State private var isAsking: Bool = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            header
            Divider().background(Color.white.opacity(0.08))
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        summaryBlock
                        ForEach(state.messages) { msg in
                            ChatBubble(message: msg).id(msg.id)
                        }
                        if isAsking {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.55)
                                Text("Thinking…")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .id("thinking")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }
                .onChange(of: state.messages.count) {
                    if let last = state.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isAsking) {
                    if isAsking {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("thinking", anchor: .bottom)
                        }
                    }
                }
            }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                inputFocused = true
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
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
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
                .disabled(isAsking)
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(canSend ? AnyShapeStyle(LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(0.25)))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
    }

    private var canSend: Bool {
        !isAsking && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        let q = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !isAsking else { return }
        input = ""
        let history = state.messages
        state.messages.append(ChatMessage(role: .user, text: q))
        isAsking = true
        Task {
            do {
                let answer = try await AppleIntelligenceManager.shared.ask(
                    question: q,
                    context: state.context,
                    history: history
                )
                state.messages.append(ChatMessage(role: .assistant, text: answer))
            } catch {
                state.messages.append(ChatMessage(role: .assistant, text: "⚠️ \(error.localizedDescription)"))
            }
            isAsking = false
        }
    }

    private func close() {
        inputFocused = false
        AppleIntelligenceManager.shared.endChat()
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
            guard let panel = view.window as? (any KeyboardActivatablePanel) else { return }
            panel.allowsKeyboardActivation = true
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKey()
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Keep the panel key-eligible across SwiftUI updates without re-stealing
        // focus (don't re-activate here — the user may have clicked elsewhere).
        (nsView.window as? (any KeyboardActivatablePanel))?.allowsKeyboardActivation = true
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        if let panel = nsView.window as? (any KeyboardActivatablePanel) {
            panel.allowsKeyboardActivation = false
            panel.makeFirstResponder(nil)
        }
        // Hand activation back to whatever app the user was using before.
        NSApp.deactivate()
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
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
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
