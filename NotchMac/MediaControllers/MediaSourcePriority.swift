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
    /// 2. If no priority bundle qualifies, fall back to the most recent
    ///    incoming update (`latestBundleID`).
    static func resolve(
        from sourceStates: [String: PlaybackState],
        latestBundleID: String,
        currentDisplayed: PlaybackState
    ) -> PlaybackState {
        let runningBundles = Set(
            NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier }
        )

        for bundle in order {
            guard let state = sourceStates[bundle],
                  state.isPlaying,
                  runningBundles.contains(bundle)
            else { continue }
            return state
        }

        if let latest = sourceStates[latestBundleID] {
            return latest
        }
        return currentDisplayed
    }
}
