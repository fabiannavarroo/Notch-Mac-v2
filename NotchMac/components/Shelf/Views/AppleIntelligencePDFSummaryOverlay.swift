//
//  AppleIntelligencePDFSummaryOverlay.swift
//  NotchMac
//
//  Expanded-notch overlay: PDF summary + on-device chat over the document.
//

import SwiftUI

@MainActor
struct AppleIntelligencePDFSummaryOverlay: View {
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
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(Color.black)
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
                Text(state.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.92))
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
        state.reset()
        coordinator.currentView = .home
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 24) }
            Text(message.text)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.95))
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
