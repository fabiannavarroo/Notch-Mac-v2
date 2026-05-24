//
//  SoftwareUpdater.swift
//  boringNotch
//
//  Created by Richard Kunkli on 09/08/2024.
//

import Combine
import SwiftUI
import Sparkle
import UserNotifications
import AppKit

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
/// `NSObject` + `SPUStandardUserDriverDelegate` together implement Sparkle's
/// "gentle reminders" contract — required for LSUIElement apps so scheduled
/// update alerts don't appear behind everything and get missed.
/// https://sparkle-project.org/documentation/gentle-reminders/
final class UpdatesStatusModel: NSObject, ObservableObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate, UNUserNotificationCenterDelegate {

    private let notificationIdentifier = "com.fabiannavarrofonte.notchmac.sparkle.update"

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
        didSet {
            guard !isSyncingFromUpdater, let updater else { return }
            if updater.automaticallyChecksForUpdates != automaticallyChecksForUpdates {
                updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
                NSLog("[NotchMac][Updater] automaticallyChecksForUpdates -> \(automaticallyChecksForUpdates)")
            }
        }
    }
    @Published var automaticallyDownloadsUpdates: Bool = false {
        didSet {
            guard !isSyncingFromUpdater, let updater else { return }
            if updater.automaticallyDownloadsUpdates != automaticallyDownloadsUpdates {
                updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
                NSLog("[NotchMac][Updater] automaticallyDownloadsUpdates -> \(automaticallyDownloadsUpdates)")
            }
        }
    }
    @Published private(set) var canCheckForUpdates: Bool = false
    @Published private(set) var lastChecked: Date? = nil
    @Published private(set) var sessionInProgress: Bool = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var scheduledCheckInterval: TimeInterval = 3600

    /// Computed at read time so the UI stays accurate without a timer.
    var nextCheckDate: Date? {
        guard automaticallyChecksForUpdates, let last = lastChecked else { return nil }
        return last.addingTimeInterval(scheduledCheckInterval)
    }

    var feedURLString: String? {
        updater?.feedURL?.absoluteString
            ?? Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
    }

    private weak var updater: SPUUpdater?
    private var cancellables = Set<AnyCancellable>()
    private var isSyncingFromUpdater = false

    func attach(_ updater: SPUUpdater) {
        guard self.updater !== updater else { return }
        self.updater = updater

        // Seed published state from Sparkle without firing the didSet relay.
        syncFromUpdater()

        scheduledCheckInterval = updater.updateCheckInterval
        if scheduledCheckInterval <= 0 {
            scheduledCheckInterval =
                (Bundle.main.object(forInfoDictionaryKey: "SUScheduledCheckInterval") as? NSNumber)?
                .doubleValue ?? 3600
        }

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

        // Mirror Sparkle KVO back into our @Published toggles so external
        // changes (e.g. the original `UpdaterSettingsView` form, defaults
        // domain edits, scheduled scope updates) stay in sync with the UI.
        updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                guard let self else { return }
                guard self.automaticallyChecksForUpdates != value else { return }
                self.isSyncingFromUpdater = true
                self.automaticallyChecksForUpdates = value
                self.isSyncingFromUpdater = false
            }
            .store(in: &cancellables)

        updater.publisher(for: \.automaticallyDownloadsUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                guard let self else { return }
                guard self.automaticallyDownloadsUpdates != value else { return }
                self.isSyncingFromUpdater = true
                self.automaticallyDownloadsUpdates = value
                self.isSyncingFromUpdater = false
            }
            .store(in: &cancellables)

        updater.publisher(for: \.updateCheckInterval)
            .receive(on: RunLoop.main)
            .sink { [weak self] interval in
                guard let self else { return }
                self.scheduledCheckInterval = interval > 0 ? interval : 3600
            }
            .store(in: &cancellables)

        NSLog("[NotchMac][Updater] attached automatic=\(updater.automaticallyChecksForUpdates) downloads=\(updater.automaticallyDownloadsUpdates) lastCheck=\(String(describing: updater.lastUpdateCheckDate)) interval=\(scheduledCheckInterval) feed=\(updater.feedURL?.absoluteString ?? "nil")")
    }

    /// Re-reads Sparkle state. Called when the Updates panel appears so the
    /// switches reflect any drift that happened while the panel was unmounted.
    func syncFromUpdater() {
        guard let updater else { return }
        isSyncingFromUpdater = true
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        canCheckForUpdates = updater.canCheckForUpdates
        lastChecked = updater.lastUpdateCheckDate
        sessionInProgress = updater.sessionInProgress
        isSyncingFromUpdater = false
    }

    func checkForUpdates() {
        guard let updater else { return }
        status = .checking
        updater.checkForUpdates()
    }

    /// Silent background check — Sparkle decide gentle-reminder vs alert based
    /// on `supportsGentleScheduledUpdateReminders`. Use on app launch so users
    /// always see fresh updates without waiting for the scheduled timer.
    func checkForUpdatesInBackground() {
        guard let updater else { return }
        updater.checkForUpdatesInBackground()
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
            self.lastErrorMessage = nil
        }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        DispatchQueue.main.async {
            self.status = .upToDate
            self.lastErrorMessage = nil
        }
    }

    // MARK: SPUStandardUserDriverDelegate (gentle reminders for LSUIElement)

    var supportsGentleScheduledUpdateReminders: Bool { true }

    /// Sparkle is about to surface an update sheet. For background apps the
    /// sheet alone is easy to miss, so we also fire a UNUserNotification and
    /// activate the app so any window comes forward.
    ///
    /// `handleShowingUpdate=false` is the gentle-reminder path: Sparkle will
    /// NOT show alert this session — only post notification. Activating dock
    /// in that case cause flash + immediate revert by WillFinishUpdateSession
    /// (the visible "pantallazo que se esconde"). Only activate when Sparkle
    /// actually about to show alert.
    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        if handleShowingUpdate {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        if !state.userInitiated {
            requestNotificationAuthorizationIfNeeded()
            postUpdateNotification(for: update)
        }
        NSLog("[NotchMac][Updater] will show update version=\(update.displayVersionString) userInitiated=\(state.userInitiated) handleShowingUpdate=\(handleShowingUpdate)")
    }

    /// Sparkle is telling us the user engaged with its UI — clear any pending
    /// notification so the user does not get nagged twice.
    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
    }

    func standardUserDriverWillFinishUpdateSession() {
        // Return to background-only after the session finishes so we keep
        // hiding the Dock icon when no update UI is on screen.
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.identifier == notificationIdentifier {
            // Re-trigger Sparkle so it brings the alert sheet to front.
            DispatchQueue.main.async { [weak self] in
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                self?.updater?.checkForUpdates()
            }
        }
        completionHandler()
    }

    // MARK: Notification helpers

    private var notificationAuthorizationRequested = false

    private func requestNotificationAuthorizationIfNeeded() {
        guard !notificationAuthorizationRequested else { return }
        notificationAuthorizationRequested = true
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                NSLog("[NotchMac][Updater] UN auth error: \(error)")
            }
            NSLog("[NotchMac][Updater] UN auth granted=\(granted)")
        }
    }

    private func postUpdateNotification(for update: SUAppcastItem) {
        let content = UNMutableNotificationContent()
        content.title = "NotchMac update available"
        content.body = "Version \(update.displayVersionString) is ready. Click to review."
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: notificationIdentifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { error in
            if let error = error {
                NSLog("[NotchMac][Updater] UN post error: \(error)")
            }
        }
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let ns = error as NSError
        // Sparkle reports user-cancelled checks as errors — treat them as idle.
        let cancelled = ns.domain == "SUSparkleErrorDomain" && ns.code == 4001
        let msg = "\(ns.domain) \(ns.code): \(ns.localizedDescription)"
        NSLog("[NotchMac][Updater] error: \(msg)")
        DispatchQueue.main.async {
            if cancelled {
                self.status = .idle
            } else {
                self.status = .failed(ns.localizedDescription)
                self.lastErrorMessage = msg
            }
        }
    }
}
