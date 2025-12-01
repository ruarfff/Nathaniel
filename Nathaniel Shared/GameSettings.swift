//
//  GameSettings.swift
//  Nathaniel Shared
//
//  Manages persistent game settings using UserDefaults.
//

import Foundation

class GameSettings {

    // MARK: - Singleton

    static let shared = GameSettings()

    // MARK: - Keys

    private enum Keys {
        static let soundEffectsEnabled = "soundEffectsEnabled"
        static let musicEnabled = "musicEnabled"
    }

    // MARK: - Properties

    var soundEffectsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.soundEffectsEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.soundEffectsEnabled) }
    }

    var musicEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.musicEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.musicEnabled) }
    }

    // MARK: - Init

    private init() {}
}
