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
