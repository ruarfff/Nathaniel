//
//  SaveManager.swift
//  Nathaniel Shared
//
//  Manages save/load operations with multiple save slots.
//

import Foundation

// MARK: - Save Manager

/// Manages game save slots and persistence
class SaveManager {
    // MARK: - Singleton

    static let shared = SaveManager()

    // MARK: - Constants

    /// Number of available save slots
    static let slotCount = 3

    /// Key prefix for save slots
    private let slotKeyPrefix = "save_slot_"

    // MARK: - Properties

    private let defaults: UserDefaults

    /// Cached save slot metadata
    private var slotMetadata: [SaveSlot] = []

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.loadMetadata()
    }

    // MARK: - Public Methods

    /// Get all save slots with their metadata
    func getSaveSlots() -> [SaveSlot] {
        self.slotMetadata
    }

    /// Get a specific save slot
    func getSlot(_ slotId: Int) -> SaveSlot? {
        self.slotMetadata.first { $0.id == slotId }
    }

    /// Check if any save slots have data
    var hasSaves: Bool {
        self.slotMetadata.contains { $0.hasSave }
    }

    /// Save game state to a slot
    /// - Parameters:
    ///   - state: The game state to save
    ///   - slotId: The slot ID (1-3)
    /// - Returns: true if save was successful
    @discardableResult
    func saveToSlot(_ state: SavedGameState, slotId: Int) -> Bool {
        guard slotId >= 1, slotId <= SaveManager.slotCount else {
            print("[SaveManager] Invalid slot ID: \(slotId)")
            return false
        }

        // Encode and save the state
        guard let encoded = try? JSONEncoder().encode(state) else {
            print("[SaveManager] Failed to encode save state")
            return false
        }

        let key = self.slotKeyPrefix + String(slotId)
        self.defaults.set(encoded, forKey: key)

        // Update metadata
        if let index = slotMetadata.firstIndex(where: { $0.id == slotId }) {
            self.slotMetadata[index].update(from: state)
        }

        print("[SaveManager] Saved to slot \(slotId): Level \(state.levelNumber), Score \(state.score)")
        return true
    }

    /// Load game state from a slot
    /// - Parameter slotId: The slot ID (1-3)
    /// - Returns: The saved game state, or nil if slot is empty or corrupted
    func loadFromSlot(_ slotId: Int) -> SavedGameState? {
        guard slotId >= 1, slotId <= SaveManager.slotCount else {
            print("[SaveManager] Invalid slot ID: \(slotId)")
            return nil
        }

        let key = self.slotKeyPrefix + String(slotId)
        guard let data = defaults.data(forKey: key) else {
            print("[SaveManager] No data in slot \(slotId)")
            return nil
        }

        guard let state = try? JSONDecoder().decode(SavedGameState.self, from: data) else {
            print("[SaveManager] Failed to decode save state from slot \(slotId)")
            return nil
        }

        print("[SaveManager] Loaded from slot \(slotId): Level \(state.levelNumber), Score \(state.score)")
        return state
    }

    /// Delete a save slot
    /// - Parameter slotId: The slot ID (1-3)
    func deleteSlot(_ slotId: Int) {
        guard slotId >= 1, slotId <= SaveManager.slotCount else {
            print("[SaveManager] Invalid slot ID: \(slotId)")
            return
        }

        let key = self.slotKeyPrefix + String(slotId)
        self.defaults.removeObject(forKey: key)

        // Update metadata
        if let index = slotMetadata.firstIndex(where: { $0.id == slotId }) {
            self.slotMetadata[index].clear()
        }

        print("[SaveManager] Deleted slot \(slotId)")
    }

    /// Delete all save slots
    func deleteAllSlots() {
        for slotId in 1 ... SaveManager.slotCount {
            let key = self.slotKeyPrefix + String(slotId)
            self.defaults.removeObject(forKey: key)
        }

        // Reset metadata
        self.slotMetadata = (1 ... SaveManager.slotCount).map { SaveSlot(id: $0) }

        print("[SaveManager] Deleted all save slots")
    }

    // MARK: - Private Methods

    /// Derive slot metadata from the saved games so there is only one persisted source.
    private func loadMetadata() {
        self.slotMetadata = (1 ... SaveManager.slotCount).map { slotId in
            var slot = SaveSlot(id: slotId)
            if let state = loadFromSlot(slotId) {
                slot.update(from: state)
            }
            return slot
        }
    }
}

// MARK: - Save Slot Display Info

extension SaveSlot {
    /// Formatted timestamp string for display
    var formattedDate: String? {
        guard let date = savedAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Formatted elapsed time string for display
    var formattedTime: String? {
        guard let time = elapsedTime else { return nil }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Level name for display
    var levelName: String? {
        guard let level = levelNumber else { return nil }
        if level == 0 {
            return "Survival"
        }
        return "Level \(level)"
    }

    /// Summary string for save slot display
    var displaySummary: String {
        guard hasSave else { return "Empty" }

        var parts: [String] = []
        if let levelName {
            parts.append(levelName)
        }
        if let time = formattedTime {
            parts.append(time)
        }
        if let score {
            parts.append("Score: \(score)")
        }
        return parts.joined(separator: " - ")
    }
}
