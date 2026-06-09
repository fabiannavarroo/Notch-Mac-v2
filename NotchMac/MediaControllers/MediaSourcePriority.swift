//
//  MediaSourcePriority.swift
//  NotchMac
//
//  Centralized priority arbitration for the system Now Playing stream.
//  When multiple audio sources are active simultaneously (e.g. Spotify +
//  a YouTube tab in Chrome), the system "now playing" item often flips to
//  whichever app most recently updated MediaRemote. The notch UI should
//  instead keep showing the source with the highest configured priority
//  that is still actually playing.
//

import AppKit
import Foundation

enum MediaSourcePriority {
    /// Highest-priority bundle identifiers first. Anything not in the list
    /// is treated as lowest priority (browsers, generic apps, etc.).
    static let order: [String] = [
        "com.apple.Music",
        "com.spotify.client",
    ]

    /// Resolve which cached source should be displayed.
    ///
    /// Rules:
    /// 1. Iterate `order` and pick the first bundle whose cached state is
    ///    currently playing AND whose process is still running.
    /// 2. Otherwise pick whichever source is playing, most recently
    ///    updated first (browser video, etc.).
    /// 3. Nothing playing: prefer a paused priority app over the latest
    ///    update, so pausing Spotify keeps Spotify in the notch.
    /// 4. Fall back to the most recent incoming update (`latestBundleID`),
    ///    then to what is already displayed.
    static func resolve(
        from sourceStates: [String: PlaybackState],
        latestBundleID: String,
        currentDisplayed: PlaybackState,
        runningBundles: Set<String>? = nil
    ) -> PlaybackState {
        let running = runningBundles ?? Set(
            NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier }
        )

        for bundle in order {
            guard let state = sourceStates[bundle],
                  state.isPlaying,
                  running.contains(bundle)
            else { continue }
            return state
        }

        if let playing = sourceStates.values
            .filter({ $0.isPlaying && running.contains($0.bundleIdentifier) })
            .max(by: { $0.lastUpdated < $1.lastUpdated }) {
            return playing
        }

        for bundle in order {
            guard let state = sourceStates[bundle], running.contains(bundle) else { continue }
            return state
        }

        if let latest = sourceStates[latestBundleID] {
            return latest
        }
        return currentDisplayed
    }
}
