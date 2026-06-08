//
//  AppleIntelligencePDFDropView.swift
//  NotchMac
//
//  Drop-target tile in the shelf. Accepts a PDF, extracts text on-device,
//  asks Apple Foundation Models for a summary, then opens the chat overlay.
//

import SwiftUI
import UniformTypeIdentifiers
import Defaults

@MainActor
final class AppleIntelligencePDFState: ObservableObject {
    enum Phase: Equatable {
        case idle
        case extracting
        case summarizing
        case done
        case error(String)
    }

    static let shared = AppleIntelligencePDFState()
    private init() {}

    @Published var phase: Phase = .idle
    @Published var fileName: String = ""
    @Published var summary: String = ""
    @Published var context: String = ""
    @Published var messages: [ChatMessage] = []

    var isProcessing: Bool {
        switch phase {
        case .extracting, .summarizing: return true
        default: return false
        }
    }

    func reset() {
        phase = .idle
        fileName = ""
        summary = ""
        context = ""
        messages = []
    }
}

@MainActor
struct AppleIntelligencePDFDropView: View {
    var size: CGFloat = 110
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var state = AppleIntelligencePDFState.shared
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @State private var isTargeted: Bool = false
    @State private var glowPulse: Bool = false

    private var manager: AppleIntelligenceManager { .shared }

    var body: some View {
        let available = manager.isAvailable
        ZStack {
            background
            content
                .padding(size * 0.09)
        }
        .frame(width: size, height: size)
        .opacity(available ? 1.0 : 0.55)
        .help(available ? "Drop a PDF to summarize" : "Requires Apple Intelligence")
        .onDrop(of: [UTType.pdf, UTType.fileURL], isTargeted: $isTargeted) { providers in
            guard available, !state.isProcessing else { return false }
            vm.dropEvent = true
            return handleDrop(providers)
        }
        .onChange(of: isTargeted) { _, targeted in
            vm.generalDropTargeting = targeted
        }
        .onTapGesture {
            guard available else { return }
            if case .done = state.phase {
                coordinator.currentView = .summary
            } else if case .error = state.phase {
                state.reset()
            }
        }
        .onAppear { glowPulse = true }
    }

    private var background: some View {
        let active = isTargeted || state.isProcessing
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LinearGradient(
                colors: [Color(red: 0.18, green: 0.12, blue: 0.32), Color(red: 0.08, green: 0.07, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        AngularGradient(
                            colors: [Color.pink, Color.purple, Color.blue, Color.cyan, Color.pink],
                            center: .center
                        ),
                        lineWidth: active ? 2.0 : 1.0
                    )
                    .opacity(active ? 1.0 : 0.55)
                    .blur(radius: active ? 1.5 : 0)
            )
            .shadow(color: Color.purple.opacity(active ? 0.55 : 0.0), radius: glowPulse && active ? 14 : 6)
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: glowPulse)
            .animation(.easeInOut(duration: 0.25), value: active)
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: max(2, size * 0.05)) {
            logo
            Text(label)
                .font(.system(size: max(8, size * 0.095), weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            if !state.fileName.isEmpty, case .done = state.phase {
                Text(state.fileName)
                    .font(.system(size: max(7, size * 0.08)))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var logo: some View {
        Group {
            if let img = NSImage(named: "AppleIntelligenceLogo") {
                Image(nsImage: img).resizable().scaledToFit()
            } else {
                Image(systemName: "sparkles")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.purple)
            }
        }
        .frame(width: size * 0.28, height: size * 0.28)
        .rotationEffect(.degrees(state.isProcessing ? 360 : 0))
        .animation(state.isProcessing ? .linear(duration: 2.5).repeatForever(autoreverses: false) : .default, value: state.isProcessing)
    }

    private var label: String {
        switch state.phase {
        case .idle: return "Drop a PDF\nfor a summary"
        case .extracting: return "Reading PDF…"
        case .summarizing: return "Summarizing…"
        case .done: return "Summary ready"
        case .error(let msg): return msg
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        let typesToTry: [UTType] = [.pdf, .fileURL]
        for type in typesToTry where provider.hasItemConformingToTypeIdentifier(type.identifier) {
            provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, _ in
                Task { @MainActor in
                    if let url = Self.resolveURL(from: item), url.pathExtension.lowercased() == "pdf" {
                        await runPipeline(url: url)
                    }
                }
            }
            return true
        }
        return false
    }

    private static func resolveURL(from item: Any?) -> URL? {
        if let url = item as? URL { return url }
        if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) { return url }
        if let s = item as? String, let url = URL(string: s) { return url }
        return nil
    }

    private func runPipeline(url: URL) async {
        state.reset()
        manager.endChat()  // drop any chat session tied to a previous document
        state.fileName = url.lastPathComponent
        state.phase = .extracting
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let text = try manager.extractText(from: url)
            state.context = text
            state.phase = .summarizing
            let summary = try await manager.summarize(text: text)
            state.summary = summary
            state.phase = .done
            // Open (or re-open, if it auto-closed during processing) the notch and
            // size it to the summary so the result is visible without clipping.
            coordinator.currentView = .summary
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                vm.open()
            }
        } catch {
            state.phase = .error(error.localizedDescription)
        }
    }
}
