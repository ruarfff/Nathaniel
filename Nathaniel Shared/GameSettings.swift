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

    // MARK: - Keys

    private enum Keys {
        static let soundEffectsEnabled = "soundEffectsEnabled"
        static let musicEnabled = "musicEnabled"
        static let saveGameData = "saveGameData"
    }

    // MARK: - Audio Settings

    var soundEffectsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.soundEffectsEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.soundEffectsEnabled) }
    }

    var musicEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.musicEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.musicEnabled) }
    }

    // MARK: - Save Game Data

    /// The current save game data
    private(set) var saveData: SaveGameData = .empty

    /// Whether there is any saved progress
    var hasSavedProgress: Bool {
        saveData.highestLevelCompleted > 0
    }

    /// The next level to play (continues from last completed)
    var continueLevel: Int {
        min(saveData.highestLevelCompleted + 1, 5)
    }

    // MARK: - Init

    private init() {
        loadSaveData()
    }

    // MARK: - Save Game Methods

    /// Load save data from UserDefaults
    private func loadSaveData() {
        guard let data = UserDefaults.standard.data(forKey: Keys.saveGameData),
              let decoded = try? JSONDecoder().decode(SaveGameData.self, from: data) else {
            saveData = .empty
            return
        }
        saveData = decoded
    }

    /// Save current data to UserDefaults
    private func persistSaveData() {
        guard let encoded = try? JSONEncoder().encode(saveData) else { return }
        UserDefaults.standard.set(encoded, forKey: Keys.saveGameData)
    }

    /// Record completion of a level
    /// - Parameters:
    ///   - levelNumber: The level that was completed
    ///   - score: The score achieved
    ///   - time: The completion time
    func recordLevelCompletion(levelNumber: Int, score: Int, time: TimeInterval) {
        // Update highest level completed
        if levelNumber > saveData.highestLevelCompleted {
            saveData.highestLevelCompleted = levelNumber
        }

        // Update level high score
        if let currentHigh = saveData.levelHighScores[levelNumber] {
            if score > currentHigh {
                saveData.levelHighScores[levelNumber] = score
            }
        } else {
            saveData.levelHighScores[levelNumber] = score
        }

        // Update level best time
        if let currentBest = saveData.levelBestTimes[levelNumber] {
            if time < currentBest {
                saveData.levelBestTimes[levelNumber] = time
            }
        } else {
            saveData.levelBestTimes[levelNumber] = time
        }

        // Update overall high score
        let totalScore = saveData.levelHighScores.values.reduce(0, +)
        if totalScore > saveData.highestScore {
            saveData.highestScore = totalScore
        }

        // Update best completion time (only if all levels completed)
        if saveData.highestLevelCompleted >= 5 {
            let totalTime = saveData.levelBestTimes.values.reduce(0, +)
            if saveData.bestCompletionTime == nil || totalTime < saveData.bestCompletionTime! {
                saveData.bestCompletionTime = totalTime
            }
        }

        persistSaveData()
    }

    /// Get high score for a specific level
    func highScore(forLevel level: Int) -> Int? {
        saveData.levelHighScores[level]
    }

    /// Get best time for a specific level
    func bestTime(forLevel level: Int) -> TimeInterval? {
        saveData.levelBestTimes[level]
    }

    /// Check if a level has been completed
    func isLevelCompleted(_ level: Int) -> Bool {
        saveData.highestLevelCompleted >= level
    }

    /// Reset all save data (new game)
    func resetSaveData() {
        saveData = .empty
        persistSaveData()
    }
}
