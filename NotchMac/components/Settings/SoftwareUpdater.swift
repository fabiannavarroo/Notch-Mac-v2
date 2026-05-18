//
//  SoftwareUpdater.swift
//  boringNotch
//
//  Created by Richard Kunkli on 09/08/2024.
//

import Combine
import SwiftUI
import Sparkle

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater

        // Create our view model for our CheckForUpdatesView
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

struct UpdaterSettingsView: View {
    private let updater: SPUUpdater

    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool

    init(updater: SPUUpdater) {
        self.updater = updater
        self.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        self.automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
    }

    var body: some View {
        Section {
            Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
                .onChange(of: automaticallyChecksForUpdates) { _, newValue in
                    updater.automaticallyChecksForUpdates = newValue
                }

            Toggle("Automatically download updates", isOn: $automaticallyDownloadsUpdates)
                .disabled(!automaticallyChecksForUpdates)
                .onChange(of: automaticallyDownloadsUpdates) { _, newValue in
                    updater.automaticallyDownloadsUpdates = newValue
                }
        } header: {
            HStack {
                Text("Software updates")
            }
        }
    }
}

// MARK: - Updates panel model

/// Observable bridge to `SPUUpdater` for the Settings → Updates pane.
///
/// Why a singleton: Sparkle binds its `updaterDelegate` at controller init time
/// and never lets it change. The panel mounts/unmounts as the user navigates,
/// so the delegate has to outlive the view — hence `shared`, wired from
/// `NotchMacApp.init`.
final class UpdatesStatusModel: NSObject, ObservableObject, SPUUpdaterDelegate {

    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(version: String, notes: String?, url: URL?)
        case failed(String)
    }

    static let shared = UpdatesStatusModel()

    @Published private(set) var status: Status = .idle
    @Published var automaticallyChecksForUpdates: Bool = true {
        didSet { updater?.automaticallyChecksForUpdates = automaticallyChecksForUpdates }
    }
    @Published var automaticallyDownloadsUpdates: Bool = false {
        didSet { updater?.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates }
    }
    @Published private(set) var canCheckForUpdates: Bool = false
    @Published private(set) var lastChecked: Date? = nil
    @Published private(set) var sessionInProgress: Bool = false

    private weak var updater: SPUUpdater?
    private var cancellables = Set<AnyCancellable>()

    func attach(_ updater: SPUUpdater) {
        guard self.updater !== updater else { return }
        self.updater = updater

        // Seed from Sparkle, then mirror back on user edits via didSet.
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        canCheckForUpdates = updater.canCheckForUpdates
        lastChecked = updater.lastUpdateCheckDate
        sessionInProgress = updater.sessionInProgress

        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.canCheckForUpdates = $0 }
            .store(in: &cancellables)

        updater.publisher(for: \.lastUpdateCheckDate)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.lastChecked = $0 }
            .store(in: &cancellables)

        updater.publisher(for: \.sessionInProgress)
            .receive(on: RunLoop.main)
            .sink { [weak self] inProgress in
                guard let self else { return }
                self.sessionInProgress = inProgress
                if inProgress {
                    self.status = .checking
                }
            }
            .store(in: &cancellables)
    }

    func checkForUpdates() {
        guard let updater else { return }
        status = .checking
        updater.checkForUpdates()
    }

    // MARK: SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        DispatchQueue.main.async {
            let url = item.fileURL ?? item.infoURL
            self.status = .updateAvailable(
                version: item.displayVersionString,
                notes: item.itemDescription,
                url: url
            )
        }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        DispatchQueue.main.async { self.status = .upToDate }
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let ns = error as NSError
        // Sparkle reports user-cancelled checks as errors — treat them as idle.
        let cancelled = ns.domain == "SUSparkleErrorDomain" && ns.code == 4001
        DispatchQueue.main.async {
            self.status = cancelled ? .idle : .failed(ns.localizedDescription)
        }
    }
}
