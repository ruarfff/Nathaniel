//
//  GameSettings.swift
//  Nathaniel Shared
//
//  Manages persistent game settings and save game data using UserDefaults.
//

import Foundation

// MARK: - Save Game Data

/// Data saved when player completes a level or achieves high scores
struct SaveGameData: Codable {
    /// Highest level completed (0 = none, 1-5 for campaign)
    var highestLevelCompleted: Int

    /// Highest score achieved in campaign
    var highestScore: Int

    /// Best completion time in seconds (for completed run)
    var bestCompletionTime: TimeInterval?

    /// Per-level high scores
    var levelHighScores: [Int: Int]

    /// Per-level best times
    var levelBestTimes: [Int: TimeInterval]

    /// Create new save data with defaults
    static var empty: SaveGameData {
        SaveGameData(
            highestLevelCompleted: 0,
            highestScore: 0,
            bestCompletionTime: nil,
            levelHighScores: [:],
            levelBestTimes: [:]
        )
    }
}

class GameSettings {
    // MARK: - Singleton

    static let shared = GameSettings()

    private let defaults: UserDefaults

    // MARK: - Keys

    private enum Keys {
        static let soundEffectsEnabled = "soundEffectsEnabled"
        static let musicEnabled = "musicEnabled"
        static let saveGameData = "saveGameData"
    }

    // MARK: - Audio Settings

    var soundEffectsEnabled: Bool {
        get { self.defaults.object(forKey: Keys.soundEffectsEnabled) as? Bool ?? false }
        set { self.defaults.set(newValue, forKey: Keys.soundEffectsEnabled) }
    }

    var musicEnabled: Bool {
        get { self.defaults.object(forKey: Keys.musicEnabled) as? Bool ?? false }
        set { self.defaults.set(newValue, forKey: Keys.musicEnabled) }
    }

    // MARK: - Save Game Data

    /// The current save game data
    private(set) var saveData: SaveGameData = .empty

    /// Whether there is any saved progress
    var hasSavedProgress: Bool {
        self.saveData.highestLevelCompleted > 0
    }

    /// The next level to play (continues from last completed)
    var continueLevel: Int {
        min(self.saveData.highestLevelCompleted + 1, 5)
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.loadSaveData()
    }

    // MARK: - Save Game Methods

    /// Load save data from UserDefaults
    private func loadSaveData() {
        guard let data = self.defaults.data(forKey: Keys.saveGameData),
              let decoded = try? JSONDecoder().decode(SaveGameData.self, from: data)
        else {
            self.saveData = .empty
            return
        }
        self.saveData = decoded
    }

    /// Save current data to UserDefaults
    private func persistSaveData() {
        guard let encoded = try? JSONEncoder().encode(saveData) else { return }
        self.defaults.set(encoded, forKey: Keys.saveGameData)
    }

    /// Record completion of a level
    /// - Parameters:
    ///   - levelNumber: The level that was completed
    ///   - score: The score achieved
    ///   - time: The completion time
    func recordLevelCompletion(levelNumber: Int, score: Int, time: TimeInterval) {
        // Update highest level completed
        self.saveData.highestLevelCompleted = max(self.saveData.highestLevelCompleted, levelNumber)

        // Update level high score
        self.saveData.levelHighScores[levelNumber] = max(self.saveData.levelHighScores[levelNumber] ?? score, score)

        // Update level best time
        self.saveData.levelBestTimes[levelNumber] = min(self.saveData.levelBestTimes[levelNumber] ?? time, time)

        // Update overall high score
        let totalScore = self.saveData.levelHighScores.values.reduce(0, +)
        self.saveData.highestScore = max(self.saveData.highestScore, totalScore)

        // Update best completion time (only if all levels completed)
        if self.saveData.highestLevelCompleted >= 5 {
            let totalTime = self.saveData.levelBestTimes.values.reduce(0, +)
            self.saveData.bestCompletionTime = min(self.saveData.bestCompletionTime ?? totalTime, totalTime)
        }

        self.persistSaveData()
    }

    /// Get high score for a specific level
    func highScore(forLevel level: Int) -> Int? {
        self.saveData.levelHighScores[level]
    }

    /// Check if a level has been completed
    func isLevelCompleted(_ level: Int) -> Bool {
        self.saveData.highestLevelCompleted >= level
    }
}
