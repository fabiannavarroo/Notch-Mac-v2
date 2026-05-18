//
//  LanguageManager.swift
//  NotchMac
//
//  Provides an app-wide language override independent of macOS system language.
//  Applied at launch via AppleLanguages UserDefault; changes require a relaunch.
//

import AppKit
import Defaults
import Foundation

enum LanguageManager {
    private static let appleLanguagesKey = "AppleLanguages"

    static func applySelectedLanguage() {
        let selected = Defaults[.appLanguage]
        if let codes = selected.appleLanguagesValue {
            UserDefaults.standard.set(codes, forKey: appleLanguagesKey)
        } else {
            UserDefaults.standard.removeObject(forKey: appleLanguagesKey)
        }
        UserDefaults.standard.synchronize()
    }

    static func relaunchApp() {
        let bundleURL = Bundle.main.bundleURL
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", bundleURL.path]
        try? task.run()
        NSApp.terminate(nil)
    }
}
