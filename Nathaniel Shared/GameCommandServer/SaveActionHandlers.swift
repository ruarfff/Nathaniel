#if DEBUG

//
    //  SaveActionHandlers.swift
    //  Nathaniel Shared
//
    //  Action handlers for save/load game functionality.
//

    import SpriteKit

    /// Handles save/load game actions
    enum SaveActionHandlers: GameActionHandler {
        static let actionNames = [
            "saveGame",
            "getSaveSlots",
            "hasSaves",
            "showSaveSlotSelector",
            "hideSaveSlotSelector",
            "saveSlotSelectorIsVisible",
            "deleteSaveSlot",
            "deleteAllSaves",
        ]

        static func execute(
            name: String,
            params: [String: String]?,
            context: GameActionContext
        ) -> ActionResult {
            switch name {
            case "saveGame":
                return self.saveGame(params: params, context: context)

            case "getSaveSlots":
                return self.getSaveSlots()

            case "hasSaves":
                return .success("hasSaves: \(SaveManager.shared.hasSaves)")

            case "showSaveSlotSelector":
                guard let selector = context.saveSlotSelector else {
                    return .failure("Save slot selector not found")
                }
                selector.show(mode: .save)
                return .success("Save slot selector shown")

            case "hideSaveSlotSelector":
                guard let selector = context.saveSlotSelector else {
                    return .failure("Save slot selector not found")
                }
                selector.hide()
                return .success("Save slot selector hidden")

            case "saveSlotSelectorIsVisible":
                guard let selector = context.saveSlotSelector else {
                    return .failure("Save slot selector not found")
                }
                return .success("saveSlotSelectorIsVisible: \(selector.isVisible)")

            case "deleteSaveSlot":
                return self.deleteSaveSlot(params: params)

            case "deleteAllSaves":
                SaveManager.shared.deleteAllSlots()
                return .success("Deleted all save slots")

            default:
                return .failure("Unknown save action: \(name)")
            }
        }

        // MARK: - Save Game

        private static func saveGame(
            params: [String: String]?,
            context: GameActionContext
        ) -> ActionResult {
            guard let slotId = ActionParams.parseInt("slot", from: params) else {
                return .failure("Missing slot parameter (1-3)")
            }
            guard slotId >= 1, slotId <= SaveManager.slotCount else {
                return .failure("Invalid slot ID: \(slotId). Must be 1-\(SaveManager.slotCount)")
            }

            // Create save state
            let displayName = "Level \(context.levelManager?.config.levelNumber ?? 1)"
            guard let saveState = context.createSaveState(displayName: displayName) else {
                return .failure("Failed to create save state")
            }

            // Save to slot
            let success = SaveManager.shared.saveToSlot(saveState, slotId: slotId)
            if success {
                return .success("Game saved to slot \(slotId)")
            } else {
                return .failure("Failed to save to slot \(slotId)")
            }
        }

        // MARK: - Get Save Slots

        private static func getSaveSlots() -> ActionResult {
            let slots = SaveManager.shared.getSaveSlots()
            var slotInfo: [String] = []
            for slot in slots {
                if slot.hasSave {
                    slotInfo.append("Slot \(slot.id): \(slot.displaySummary)")
                } else {
                    slotInfo.append("Slot \(slot.id): Empty")
                }
            }
            return .success(slotInfo.joined(separator: "; "))
        }

        // MARK: - Delete Save Slot

        private static func deleteSaveSlot(params: [String: String]?) -> ActionResult {
            guard let slotId = ActionParams.parseInt("slot", from: params) else {
                return .failure("Missing slot parameter (1-3)")
            }
            guard slotId >= 1, slotId <= SaveManager.slotCount else {
                return .failure("Invalid slot ID: \(slotId). Must be 1-\(SaveManager.slotCount)")
            }
            SaveManager.shared.deleteSlot(slotId)
            return .success("Deleted save slot \(slotId)")
        }
    }

#endif
