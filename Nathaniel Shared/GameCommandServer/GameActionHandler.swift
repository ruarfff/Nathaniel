#if DEBUG

//
    //  GameActionHandler.swift
    //  Nathaniel Shared
//
    //  Protocol and registry for game actions using the Command pattern.
//

    import SpriteKit

    // MARK: - Action Handler Protocol

    /// Protocol for handling game actions. Each handler processes one or more related actions.
    protocol GameActionHandler {
        /// The action names this handler responds to
        static var actionNames: [String] { get }

        /// Execute the action with given parameters
        /// - Parameters:
        ///   - name: The action name
        ///   - params: Optional parameters dictionary
        ///   - context: The game scene context for accessing game objects
        /// - Returns: ActionResult indicating success or failure
        static func execute(
            name: String,
            params: [String: String]?,
            context: GameActionContext
        ) -> ActionResult
    }

    // MARK: - Action Context

    /// Provides access to game objects needed by action handlers.
    /// This decouples handlers from direct scene access.
    struct GameActionContext {
        weak var scene: GameScene?

        // MARK: - Character Access

        var nathaniel: Nathaniel? {
            self.scene?.findNathanielPublic()
        }

        var hermes: Hermes? {
            self.scene?.findHermesPublic()
        }

        // MARK: - Manager Access

        var enemyManager: EnemyManager? {
            self.scene?.findEnemyManagerPublic()
        }

        var levelManager: LevelManager? {
            self.scene?.findLevelManagerPublic()
        }

        var structureManager: StructureManager? {
            self.scene?.findStructureManagerPublic()
        }

        // MARK: - UI Access

        var pauseMenu: PauseMenu? {
            self.scene?.findPauseMenuPublic()
        }

        var settingsMenu: SettingsMenu? {
            self.scene?.findSettingsMenuPublic()
        }

        var saveSlotSelector: SaveSlotSelector? {
            self.scene?.findSaveSlotSelectorPublic()
        }

        var hud: HUD? {
            self.scene?.findHUDPublic()
        }

        var cameraNode: SKCameraNode? {
            self.scene?.findCameraNodePublic()
        }

        // MARK: - Scene Actions

        func handleTap(at point: CGPoint) {
            self.scene?.handleTap(at: point)
        }

        func handleMoveCommand(to point: CGPoint) {
            self.scene?.handleMoveCommand(to: point)
        }

        func pauseGame() {
            self.scene?.pauseGame()
        }

        func resumeGame() {
            self.scene?.resumeGame()
        }

        func toggleBuildMenu() {
            self.scene?.toggleBuildMenu()
        }

        var isBuildMenuVisible: Bool {
            self.scene?.isBuildMenuVisible ?? false
        }

        func toggleSelectedCharacter() {
            self.scene?.toggleSelectedCharacter()
        }

        func createSaveState(displayName: String) -> SavedGameState? {
            self.scene?.createSaveState(displayName: displayName)
        }
    }

    // MARK: - Action Registry

    /// Registry that maps action names to their handlers.
    /// Eliminates the giant switch statement by using dictionary lookup.
    final class GameActionRegistry {
        static let shared = GameActionRegistry()

        private var handlers: [String: GameActionHandler.Type] = [:]

        private init() {
            self.registerAllHandlers()
        }

        private func registerAllHandlers() {
            self.register(CharacterActionHandlers.self)
            self.register(BuildingActionHandlers.self)
            self.register(GameplayActionHandlers.self)
            self.register(PauseActionHandlers.self)
            self.register(SettingsActionHandlers.self)
            self.register(SaveActionHandlers.self)
            self.register(DebugActionHandlers.self)
        }

        private func register(_ handler: GameActionHandler.Type) {
            for name in handler.actionNames {
                self.handlers[name] = handler
            }
        }

        /// Execute an action by name
        /// - Parameters:
        ///   - name: The action name
        ///   - params: Optional parameters
        ///   - context: The game context
        /// - Returns: ActionResult or nil if action not found
        func execute(
            name: String,
            params: [String: String]?,
            context: GameActionContext
        ) -> ActionResult? {
            guard let handler = handlers[name] else {
                return nil
            }
            return handler.execute(name: name, params: params, context: context)
        }

        /// Check if an action is registered
        func hasAction(_ name: String) -> Bool {
            self.handlers[name] != nil
        }

        /// Get all registered action names
        var allActionNames: [String] {
            Array(self.handlers.keys).sorted()
        }

        /// Get action info grouped by category for discoverability
        func getActionInfo() -> [String: [[String: String]]] {
            [
                "character": [
                    ["name": "selectNathaniel", "description": "Select Nathaniel as active character"],
                    ["name": "selectHermes", "description": "Select Hermes as active character"],
                    ["name": "toggleCharacter", "description": "Toggle between Nathaniel and Hermes"],
                    ["name": "moveNathaniel", "description": "Move Nathaniel to position", "params": "x, y"],
                    ["name": "targetEnemy", "description": "Target specific enemy by index", "params": "index"],
                ],
                "hermes": [
                    [
                        "name": "setHermesMode",
                        "description": "Set Hermes behavior mode",
                        "params": "mode (following|independent)",
                    ],
                    ["name": "toggleHermesFollow", "description": "Toggle Hermes follow mode"],
                    ["name": "getHermesMode", "description": "Get current Hermes mode"],
                ],
                "pause": [
                    ["name": "pause", "description": "Pause the game"],
                    ["name": "resume", "description": "Resume the game"],
                    ["name": "isPaused", "description": "Check if game is paused"],
                    ["name": "showPauseMenu", "description": "Show pause menu"],
                    ["name": "hidePauseMenu", "description": "Hide pause menu"],
                    ["name": "pauseMenuIsVisible", "description": "Check if pause menu is visible"],
                    ["name": "pauseMenuTapResume", "description": "Tap resume in pause menu"],
                    ["name": "pauseMenuTapSettings", "description": "Tap settings in pause menu"],
                    ["name": "pauseMenuTapSaveGame", "description": "Tap save game in pause menu"],
                    ["name": "pauseMenuTapExitToMenu", "description": "Tap exit to menu"],
                    ["name": "pauseMenuConfirmExit", "description": "Confirm exit to menu"],
                    ["name": "pauseMenuCancelExit", "description": "Cancel exit dialog"],
                    ["name": "exitToMenu", "description": "Exit to main menu", "params": "skipConfirm (optional)"],
                ],
                "settings": [
                    ["name": "openSettings", "description": "Open settings menu"],
                    ["name": "closeSettings", "description": "Close settings menu"],
                    ["name": "settingsMenuIsVisible", "description": "Check if settings visible"],
                    ["name": "toggleSoundEffects", "description": "Toggle sound effects"],
                    ["name": "toggleMusic", "description": "Toggle music"],
                    ["name": "getSoundEffectsEnabled", "description": "Check if sound enabled"],
                    ["name": "getMusicEnabled", "description": "Check if music enabled"],
                    ["name": "getCurrentSettings", "description": "Get all settings"],
                    ["name": "setSoundEffects", "description": "Set sound effects", "params": "enabled"],
                    ["name": "setMusic", "description": "Set music", "params": "enabled"],
                ],
                "save": [
                    ["name": "saveGame", "description": "Save game to slot", "params": "slot (1-3)"],
                    ["name": "getSaveSlots", "description": "Get save slot info"],
                    ["name": "hasSaves", "description": "Check if saves exist"],
                    ["name": "showSaveSlotSelector", "description": "Show save slot UI"],
                    ["name": "hideSaveSlotSelector", "description": "Hide save slot UI"],
                    ["name": "saveSlotSelectorIsVisible", "description": "Check if selector visible"],
                    ["name": "deleteSaveSlot", "description": "Delete a save slot", "params": "slot"],
                    ["name": "deleteAllSaves", "description": "Delete all saves"],
                ],
                "gameplay": [
                    [
                        "name": "spawnEnemy",
                        "description": "Spawn enemy for testing",
                        "params": "type (grunt|soldier|boss), x, y",
                    ],
                    ["name": "killAllEnemies", "description": "Kill all enemies"],
                    ["name": "healPlayer", "description": "Heal all players to full"],
                    ["name": "addResources", "description": "Add resources", "params": "amount"],
                ],
                "debug": [
                    ["name": "getCombatState", "description": "Get targeting state"],
                    ["name": "getNathanielTarget", "description": "Get Nathaniel's target"],
                    ["name": "getHermesTarget", "description": "Get Hermes's target"],
                    ["name": "getHermesCombatState", "description": "Get Hermes combat info"],
                    ["name": "getTowerTargets", "description": "Get all tower targets"],
                    ["name": "waitForCombat", "description": "Check combat state"],
                ],
                "building": [
                    ["name": "toggleBuildMenu", "description": "Toggle build menu"],
                    ["name": "buildMenuIsVisible", "description": "Check if build menu open"],
                    ["name": "buildTower", "description": "Build tower", "params": "type (gun|laser|heal), x, y"],
                    ["name": "sellTower", "description": "Sell tower", "params": "index"],
                    ["name": "getTowerCount", "description": "Get number of towers"],
                ],
            ]
        }
    }

    // MARK: - Parameter Parsing Utilities

    /// Utilities for parsing action parameters
    enum ActionParams {
        /// Parse x, y coordinates from params
        static func parsePoint(from params: [String: String]?) -> CGPoint? {
            guard let xStr = params?["x"], let yStr = params?["y"],
                  let x = Double(xStr), let y = Double(yStr)
            else {
                return nil
            }
            return CGPoint(x: x, y: y)
        }

        /// Parse an integer parameter
        static func parseInt(_ key: String, from params: [String: String]?) -> Int? {
            guard let str = params?[key], let value = Int(str) else {
                return nil
            }
            return value
        }

        /// Parse a boolean parameter
        static func parseBool(_ key: String, from params: [String: String]?) -> Bool? {
            guard let str = params?[key] else {
                return nil
            }
            return Bool(str)
        }

        /// Parse a string parameter
        static func parseString(_ key: String, from params: [String: String]?) -> String? {
            params?[key]
        }
    }

#endif
