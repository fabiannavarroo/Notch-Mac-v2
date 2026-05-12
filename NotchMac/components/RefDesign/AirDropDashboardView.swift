//
//  AirDropDashboardView.swift
//  NotchMac
//
//  Ref-design file tray (ref2): top row con AirDrop device card +
//  drop zone, abajo lista "Recent Files" y barra de acciones
//  (Copy / Move / Folder / Pin / Clear).
//

import AppKit
import SwiftUI

struct AirDropDashboardView: View {
    @EnvironmentObject var vm: BoringViewModel
    @StateObject private var tvm = ShelfStateViewModel.shared
    @StateObject private var selection = ShelfSelectionModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            topRow
            recentFilesSection
            toolbar
        }
        .padding(8)
    }

    // MARK: - Top row
    private var topRow: some View {
        HStack(spacing: 8) {
            airDropCard
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            dropZone
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 64)
    }

    private var airDropCard: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(Color.white.opacity(0.08))
                Image(systemName: "wave.3.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("AirDrop")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                Text(NSFullUserName().isEmpty ? "Tu Mac" : "\(NSFullUserName())'s Mac")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                shareViaAirDrop(urls: selectedURLs())
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(selectedURLs().isEmpty)
            .opacity(selectedURLs().isEmpty ? 0.4 : 1)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(
                vm.dragDetectorTargeting ? Color.accentColor.opacity(0.9) : Color.white.opacity(0.18),
                style: StrokeStyle(lineWidth: 1.5, dash: [6])
            )
            .overlay {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Drop files here")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                    Text("para copiar o mover")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
            .onDrop(
                of: [.fileURL, .url, .utf8PlainText, .plainText, .data],
                isTargeted: $vm.dragDetectorTargeting
            ) { providers in
                vm.dropEvent = true
                tvm.load(providers)
                return true
            }
    }

    // MARK: - Recent files
    private var recentFilesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Recent Files")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Button("Clear All") {
                    tvm.clear()
                    selection.clear()
                }
                .font(.system(size: 9, weight: .medium))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .opacity(tvm.items.isEmpty ? 0.4 : 1)
                .disabled(tvm.items.isEmpty)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(tvm.items.prefix(8))) { item in
                        recentFileCell(item)
                    }
                    if tvm.items.isEmpty {
                        Text("Sin archivos recientes")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
            }
            .frame(height: 48)
        }
    }

    private func recentFileCell(_ item: ShelfItem) -> some View {
        let isSelected = selection.selectedIDs.contains(item.id)
        return Button {
            selection.toggle(item)
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: item.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.displayName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let size = sizeString(for: item) {
                        Text(size)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 70, alignment: .leading)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Toolbar
    private var toolbar: some View {
        HStack(spacing: 6) {
            toolbarButton("doc.on.doc", "Copy", enabled: !selectedURLs().isEmpty) {
                copyToPasteboard(urls: selectedURLs())
            }
            toolbarButton("arrow.up.right.square", "Move", enabled: !selectedURLs().isEmpty) {
                shareViaAirDrop(urls: selectedURLs())
            }
            toolbarButton("folder", "Folder", enabled: !selectedURLs().isEmpty) {
                if let url = selectedURLs().first {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            toolbarButton("pin", "Pin", enabled: !selectedURLs().isEmpty) {
                if let url = selectedURLs().first {
                    NSWorkspace.shared.open(url)
                }
            }
            toolbarButton("xmark.circle", "Clear", enabled: !tvm.items.isEmpty, tint: .red) {
                tvm.clear()
                selection.clear()
            }
        }
        .frame(height: 28)
    }

    private func toolbarButton(
        _ icon: String, _ label: String, enabled: Bool, tint: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    // MARK: - Helpers
    private func selectedURLs() -> [URL] {
        selection.selectedItems(in: tvm.items).compactMap { $0.fileURL ?? $0.URL }
    }

    private func sizeString(for item: ShelfItem) -> String? {
        guard let url = item.fileURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber else { return nil }
        return ByteCountFormatter.string(fromByteCount: size.int64Value, countStyle: .file)
    }

    private func copyToPasteboard(urls: [URL]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(urls as [NSURL])
    }

    private func shareViaAirDrop(urls: [URL]) {
        guard !urls.isEmpty,
              let service = NSSharingService(named: .sendViaAirDrop) else { return }
        service.perform(withItems: urls)
    }
}

private extension ShelfStateViewModel {
    func clear() {
        for item in items { remove(item) }
    }
}
