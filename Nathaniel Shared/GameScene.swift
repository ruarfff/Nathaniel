//
//  GameScene.swift
//  Nathaniel Shared
//
//  Coordinates gameplay, scene input, and modal menus.
//

import os.log
import SpriteKit
#if os(iOS)
    import UIKit
#endif

private let logger = Logger(subsystem: "com.ruarfff.Nathaniel", category: "GameScene")

class GameScene: InputHandlingScene, LevelManagerDelegate, ResourceManagerDelegate, TowerPlacementControllerDelegate,
    StructureManagerDelegate
{
    // MARK: - Properties

    /// The level configuration to use
    var levelConfig: LevelConfig = .levelOne

    /// The camera node for viewport control
    private var cameraNode: SKCameraNode!

    /// Camera controller for following, zoom, and movement
    private var cameraController: CameraController!

    /// The map renderer
    private var mapRenderer: TMXRenderer?

    /// The map node containing all tile layers
    private var mapNode: SKNode?

    /// The player character - Nathaniel
    private var nathaniel: Nathaniel?

    /// The robot companion - Hermes
    private var hermes: Hermes?

    /// The currently selected/controlled character
    private var selectedCharacter: Character?

    /// Enemy manager
    private var enemyManager: EnemyManager!

    /// Structure manager for defensive towers
    private var structureManager: StructureManager!

    /// Level manager for game state
    private var levelManager: LevelManager!

    /// Wave spawner for survival-style levels
    private var waveSpawner: WaveSpawner?

    /// Game overlay for victory/game over screens
    private var gameOverlay: GameOverlay!

    private enum Modal {
        case none, pause, settings, save
    }

    private var modal: Modal = .none

    /// Pause menu overlay
    private var pauseMenu: PauseMenu!

    /// Settings menu overlay
    private var settingsMenu: SettingsMenu!

    /// Save slot selector overlay
    private var saveSlotSelector: SaveSlotSelector!

    /// HUD for displaying game status
    private var hud: HUD!

    /// Starting spawn position for respawn
    private var startPosition: CGPoint = .zero

    /// Last update time for delta time calculation
    private var lastUpdateTime: TimeInterval = 0

    /// Z-position for character sprites (above map tiles)
    private let characterZPosition: CGFloat = 100

    /// Visible viewport size in scene coordinates (accounts for aspectFill scaling)
    /// This is the portion of the scene that's actually visible on screen
    private var visibleViewportSize: CGSize = .zero

    // MARK: - Fog of War

    /// Fog of war manager for visibility system
    private var fogOfWar: FogOfWar?

    /// Target indicator for showing which enemy is targeted
    private var targetIndicator: TargetIndicator?

    /// Tower placement controller for Hermes build system
    private var towerPlacementController: TowerPlacementController?

    #if DEBUG
        /// Pathfinding debug visualization overlay
        private var pathfindingDebugOverlay: PathfindingDebugOverlay?
    #endif

    #if os(iOS)
        /// Haptic feedback generator for targeting
        private var hapticGenerator: UIImpactFeedbackGenerator?
    #endif

    // MARK: - Scene Setup

    class func newGameScene(levelConfig: LevelConfig = .levelOne) -> GameScene {
        // Load 'GameScene.sks' as an SKScene.
        guard let scene = SKScene(fileNamed: "GameScene") as? GameScene else {
            fatalError("Failed to load GameScene.sks - ensure the file exists in the bundle")
        }

        scene.size = CGSize(width: 800, height: 480)
        scene.scaleMode = .aspectFill
        scene.levelConfig = levelConfig

        return scene
    }

    override func didMove(to view: SKView) {
        // Remove default SpriteKit template content from GameScene.sks
        backgroundColor = SKColor.black
        childNode(withName: "helloLabel")?.removeFromParent()

        self.setupCamera()
        self.setupLevelManager()
        ResourceManager.shared.delegate = nil
        ResourceManager.shared.reset()
        ResourceManager.shared.restore(total: self.levelConfig.startingResources)
        self.setupEnemyManager()
        self.setupStructureManager()
        self.setupOverlay()
        self.setupHUD()
        self.loadMap()
        self.setupFogOfWar()
        self.spawnCharacters()
        self.setupBuildSystem()
        self.setupHaptics()
        #if DEBUG
            self.setupPathfindingDebugOverlay()
        #endif

        // Start gameplay music
        AudioManager.shared.playMusic(.gameplay)

        #if DEBUG
            // Set this scene as the command server delegate
            GameCommandServer.shared.delegate = self
        #endif

        // Restore from save if loading from saved game
        self.restoreFromSavedState()
        if let hermes {
            self.setHermesMode(hermes.mode)
        }
    }

    private func setupHaptics() {
        #if os(iOS)
            self.hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
            self.hapticGenerator?.prepare()
        #endif
    }

    #if DEBUG
        private func setupPathfindingDebugOverlay() {
            let overlay = PathfindingDebugOverlay()
            overlay.configure(player: self.nathaniel, companion: self.hermes)
            // Add to mapNode so paths render in world coordinates
            if let mapNode {
                mapNode.addChild(overlay)
            } else {
                addChild(overlay)
            }
            self.pathfindingDebugOverlay = overlay
        }

        private func updatePathfindingDebugOverlay() {
            guard DevSettings.shared.showPathfindingDebug else {
                self.pathfindingDebugOverlay?.isHidden = true
                return
            }
            self.pathfindingDebugOverlay?.isHidden = false
            self.pathfindingDebugOverlay?.updateEnemies(self.enemyManager.enemies)
            self.pathfindingDebugOverlay?.update()
        }
    #endif

    private func setupLevelManager() {
        self.levelManager = LevelManager(config: self.levelConfig)
        self.levelManager.delegate = self
    }

    private func setupEnemyManager() {
        self.enemyManager = EnemyManager(scene: self)
        self.enemyManager.enemyZPosition = self.characterZPosition
        self.enemyManager.enemyScale = 1.0
        self.enemyManager.delegate = self.levelManager
    }

    private func setupStructureManager() {
        self.structureManager = StructureManager(scene: self)
        self.structureManager.structureZPosition = self.characterZPosition
        self.structureManager.structureScale = 1.0
        self.structureManager.enemyManager = self.enemyManager
        self.structureManager.delegate = self

        // Wire up structure collision callback for enemy pathfinding
        self.enemyManager.structureCollisionCheck = { [weak self] position, radius in
            self?.structureManager.collidesWithStructure(at: position, entityRadius: radius) ?? false
        }

        // Include towers among the enemies' possible targets.
        self.enemyManager.structureManager = self.structureManager
    }

    private func setupBuildSystem() {
        // Create tower placement controller
        // Use visibleViewportSize (calculated in setupHUD) to account for aspectFill cropping on iOS
        let viewportSize = self.visibleViewportSize.width > 0 ? self.visibleViewportSize : size
        let controller = TowerPlacementController(viewportSize: viewportSize)
        controller.setup(
            scene: self,
            structureManager: self.structureManager,
            resourceManager: ResourceManager.shared,
            hermes: self.hermes
        )
        controller.delegate = self
        if let mapRenderer {
            controller.configureValidator(
                tmxRenderer: mapRenderer,
                enemyManager: self.enemyManager,
                playerCharacters: self.enemyManager.playerCharacters
            )
        }

        // Add build menu to camera (HUD layer)
        // zPosition 700: Above HUD (500) and HUD buttons (600), below PauseMenu (900)
        controller.buildMenu.zPosition = 700
        self.cameraNode.addChild(controller.buildMenu)

        // Add placement indicator to scene (world space)
        addChild(controller.placementIndicator)

        self.towerPlacementController = controller

        // Wire up HUD callbacks
        self.hud.onBuildTapped = { [weak self] in
            self?.towerPlacementController?.toggleMenu()
        }
    }

    private func setupOverlay() {
        self.gameOverlay = GameOverlay(size: size)
        self.gameOverlay.zPosition = 1_000
        self.cameraNode.addChild(self.gameOverlay)

        // Set up overlay callbacks
        self.gameOverlay.onNextLevel = { [weak self] in
            self?.transitionToNextLevel()
        }

        self.gameOverlay.onRetry = { [weak self] in
            self?.restartLevel()
        }

        self.gameOverlay.onMainMenu = { [weak self] in
            self?.returnToMainMenu()
        }

        // Set up pause menu
        self.pauseMenu = PauseMenu(size: size)
        self.pauseMenu.zPosition = 900 // Below game overlay but above HUD
        self.cameraNode.addChild(self.pauseMenu)

        // Wire up pause menu callbacks
        self.pauseMenu.onResume = { [weak self] in
            self?.resumeGame()
        }

        self.pauseMenu.onSettings = { [weak self] in
            self?.showSettings()
        }

        self.pauseMenu.onSaveGame = { [weak self] in
            self?.showSaveSlotSelector()
        }

        // Set up settings menu
        self.settingsMenu = SettingsMenu(size: size)
        self.settingsMenu.zPosition = 920 // Above pause menu, below save slot selector
        self.cameraNode.addChild(self.settingsMenu)

        self.settingsMenu.onBack = { [weak self] in
            self?.closeSettings()
        }

        self.settingsMenu.onSettingChanged = { setting, value in
            logger.debug("Setting changed: \(setting.rawValue) = \(value)")
        }

        // Set up save slot selector
        self.saveSlotSelector = SaveSlotSelector(size: size)
        self.saveSlotSelector.zPosition = 950 // Above pause menu
        self.cameraNode.addChild(self.saveSlotSelector)

        self.saveSlotSelector.onSlotSelected = { [weak self] slotId in
            guard let self, self.modal == .save else { return }
            self.saveGameToSlot(slotId)
            self.hideSaveSlotSelector()
        }

        self.saveSlotSelector.onCancel = { [weak self] in
            self?.hideSaveSlotSelector()
        }

        self.pauseMenu.onExitToMenu = { [weak self] in
            self?.returnToMainMenu()
        }
    }

    // MARK: - Load from Save

    /// Saved state to restore after scene setup (set by factory method)
    private var pendingSaveState: SavedGameState?

    /// Create a new game scene from a saved game state
    class func newGameScene(fromSave state: SavedGameState) -> GameScene {
        // Get the level config for the saved level
        let levelConfig = LevelConfig.level(state.levelNumber) ?? .levelOne

        // Create scene with that config
        let scene = self.newGameScene(levelConfig: levelConfig)

        // Store the save state to restore after setup
        scene.pendingSaveState = state

        return scene
    }

    /// Called after scene setup to restore saved state
    private func restoreFromSavedState() {
        guard let state = pendingSaveState else { return }
        self.pendingSaveState = nil

        logger.info("Restoring game from save: Level \(state.levelNumber)")

        // Restore level manager state
        self.levelManager.restore(
            elapsedTime: state.elapsedTime,
            score: state.score,
            lives: state.saveVersion < 2 ? max(0, state.lives - 1) : state.lives
        )

        // Restore resources
        ResourceManager.shared.restore(total: state.resources)

        // Restore obstacles before requesting routes for saved destinations.
        for towerState in state.towers {
            let position = towerState.position.cgPoint
            let tower: DefensiveStructure? = switch towerState.type {
            case .gunTower:
                self.structureManager.addGunTower(at: position)
            case .laserTower:
                self.structureManager.addLaserTower(at: position)
            case .healTower:
                self.structureManager.addHealTower(at: position)
            }

            // Restore tower HP
            if let tower {
                tower.currentHP = towerState.currentHP

                // Mark as Hermes-owned if applicable
                if towerState.isHermesOwned {
                    tower.constructionCost = max(0, towerState.constructionCost ?? towerState.type.towerType.cost)
                    self.structureManager.markAsHermesOwned(tower)
                }
            }
        }

        // Restore Nathaniel
        if let nathaniel {
            if state.nathaniel.currentHP <= 0 {
                // Older saves can contain a respawn whose spare life was already spent.
                nathaniel.respawn(at: self.startPosition)
            } else {
                nathaniel.restoreFromSavedState(state.nathaniel)
            }
        }

        // Restore Hermes
        if let hermes {
            hermes.restoreFromSavedState(state.hermes)
        }

        // Clear existing enemies and restore from save
        self.enemyManager.removeAllEnemies()
        for enemyState in state.enemies {
            let enemy = enemyState.type.createEnemy()
            self.enemyManager.addEnemy(enemy)
            enemy.restore(from: enemyState)

            // Restore target reference
            if let targetIndex = enemyState.targetIndex {
                if targetIndex == 0 {
                    enemy.target = nathaniel
                } else if targetIndex == 1 {
                    enemy.target = hermes
                }
            }
        }

        ResourceManager.shared.restoreBattlefield(state.battlefieldResources ?? [], carrier: self.nathaniel)
        self.waveSpawner?.restore(elapsedTime: state.elapsedTime, timeUntilNext: state.timeUntilNextWave ?? 0)
        if self.hermes?.isAlive == false {
            self.levelManager.triggerGameOver()
        }

        // Update camera to follow restored Nathaniel position (clamped to map bounds)
        if let nathaniel {
            self.cameraController.setPosition(nathaniel.position)
        }

        // Update HUD
        self.updateHUD()

        logger.info("Save state restored successfully")
    }

    // MARK: - Level Transitions

    /// Transition to the next level
    private func transitionToNextLevel() {
        guard let nextConfig = levelConfig.nextLevel else {
            self.returnToMainMenu()
            return
        }

        let nextScene = GameScene.newGameScene(levelConfig: nextConfig)
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentSceneWithNotification(nextScene, transition: transition)
    }

    /// Restart the current level
    private func restartLevel() {
        let restartScene = GameScene.newGameScene(levelConfig: self.levelConfig)
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentSceneWithNotification(restartScene, transition: transition)
    }

    /// Return to the main menu
    private func returnToMainMenu() {
        let menuScene = MainMenuScene.newMenuScene()
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentSceneWithNotification(menuScene, transition: transition)
    }

    // MARK: - Pause/Resume

    /// Pause gameplay and show its menu.
    func pauseGame() {
        guard self.levelManager.state == .playing else { return }
        self.setModal(.pause)
    }

    /// Resume gameplay and dismiss all blocking menus.
    func resumeGame() {
        self.setModal(.none)
    }

    func showSettings() {
        self.setModal(.settings)
    }

    func closeSettings() {
        guard self.modal == .settings else { return }
        self.setModal(.pause)
    }

    func showSaveSlotSelector() {
        self.setModal(.save)
    }

    func hideSaveSlotSelector() {
        guard self.modal == .save else { return }
        self.setModal(.pause)
    }

    private func closeTopModal() {
        switch self.modal {
        case .settings:
            #if DEBUG
                if self.settingsMenu.dismissDevSettings() {
                    return
                }
            #endif
            self.closeSettings()
        case .save:
            self.hideSaveSlotSelector()
        case .pause:
            if self.pauseMenu.isShowingConfirmation {
                self.pauseMenu.hideConfirmation()
            } else {
                self.resumeGame()
            }
        case .none:
            self.pauseGame()
        }
    }

    /// The scene owns pause state; menu animations only change presentation.
    private func setModal(_ next: Modal) {
        guard next == .none || self.levelManager.state == .playing || self.levelManager.state == .paused else {
            return
        }
        self.modal = next
        self.towerPlacementController?.handleTouchCancelled()
        self.towerPlacementController?.hideMenu()

        if next == .none {
            self.pauseMenu.hide()
            self.levelManager.resume()
        } else {
            self.levelManager.pause()
            self.pauseMenu.show()
        }
        if next == .settings {
            self.settingsMenu.show()
        } else {
            self.settingsMenu.hide()
        }
        if next == .save {
            self.saveSlotSelector.show(mode: .save)
        } else {
            self.saveSlotSelector.hide()
        }
    }

    /// Save the game to a specific slot
    private func saveGameToSlot(_ slotId: Int) {
        // Create save state from current game
        let displayName = "Level \(levelConfig.levelNumber)"
        guard let saveState = createSaveState(displayName: displayName) else {
            logger.error("Failed to create save state")
            self.showSaveNotification(success: false)
            return
        }

        // Save to the selected slot
        let success = SaveManager.shared.saveToSlot(saveState, slotId: slotId)

        // Show notification
        self.showSaveNotification(success: success)

        logger.info("Saved to slot \(slotId): \(success ? "success" : "failed")")
    }

    /// Show a toast notification for save result
    private func showSaveNotification(success: Bool) {
        let message = success ? "Game Saved!" : "Save Failed"
        let color: SKColor = success ? .green : .red

        let notification = SKLabelNode(fontNamed: "Helvetica-Bold")
        notification.text = message
        notification.fontSize = 24
        notification.fontColor = color
        notification.position = CGPoint(x: 0, y: -100)
        notification.zPosition = 1_000
        notification.alpha = 0

        self.cameraNode.addChild(notification)

        // Fade in, hold, fade out
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let wait = SKAction.wait(forDuration: 1.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()

        notification.run(SKAction.sequence([fadeIn, wait, fadeOut, remove]))
    }

    /// Calculate the visible viewport size in scene coordinates.
    /// With .aspectFill, the scene is scaled to fill the view completely.
    /// - Returns: Tuple of (viewportSize, scaleFactor) for use in HUD positioning
    private func calculateVisibleViewport() -> (size: CGSize, scale: CGFloat) {
        guard let view else {
            return (size, 1.0)
        }

        // Get view dimensions, ensuring landscape orientation (width > height)
        // The view.bounds may not be reliable during didMove(to:) as the layout
        // may not have completed yet. We use max/min to ensure correct orientation.
        let viewWidth = max(view.bounds.width, view.bounds.height)
        let viewHeight = min(view.bounds.width, view.bounds.height)

        // aspectFill uses the larger scale (to fill the view completely)
        let scaleX = viewWidth / size.width
        let scaleY = viewHeight / size.height
        let scale = max(scaleX, scaleY)

        // Calculate visible area in scene coordinates
        let visibleWidth = viewWidth / scale
        let visibleHeight = viewHeight / scale

        logger.debug(
            "HUD: view=\(viewWidth)x\(viewHeight) scene=\(self.size.width)x\(self.size.height) viewport=\(visibleWidth)x\(visibleHeight)"
        )

        return (CGSize(width: visibleWidth, height: visibleHeight), scale)
    }

    #if os(iOS)
        /// Calculate safe area insets in scene coordinates (iOS only).
        /// Handles rotation from portrait view bounds to landscape scene coordinates.
        /// - Parameter scale: The scale factor from view to scene coordinates
        /// - Returns: Safe area insets converted to scene coordinates
        private func calculateSafeAreaInsets(scale: CGFloat) -> HUDSafeAreaInsets {
            guard let view else {
                return .zero
            }

            let viewSafeInsets = view.safeAreaInsets
            let viewIsPortrait = view.bounds.height > view.bounds.width

            // If view is portrait, rotate insets to match landscape orientation
            let landscapeSafeInsets: UIEdgeInsets
            if viewIsPortrait {
                // Rotate CCW: portrait top->landscape left, portrait right->landscape top, etc.
                landscapeSafeInsets = UIEdgeInsets(
                    top: viewSafeInsets.right,
                    left: viewSafeInsets.top,
                    bottom: viewSafeInsets.left,
                    right: viewSafeInsets.bottom
                )
                logger.debug("View in portrait, rotating safe insets for landscape")
            } else {
                landscapeSafeInsets = viewSafeInsets
            }

            // Convert from view points to scene coordinates
            let safeInsets = HUDSafeAreaInsets(
                top: landscapeSafeInsets.top / scale,
                bottom: landscapeSafeInsets.bottom / scale,
                left: landscapeSafeInsets.left / scale,
                right: landscapeSafeInsets.right / scale
            )
            logger.debug(
                "Safe insets: t=\(safeInsets.top) b=\(safeInsets.bottom) l=\(safeInsets.left) r=\(safeInsets.right)"
            )

            return safeInsets
        }
    #endif

    private func setupHUD() {
        let (hudSize, scale) = self.calculateVisibleViewport()
        self.visibleViewportSize = hudSize

        #if os(iOS)
            let safeInsets = self.calculateSafeAreaInsets(scale: scale)
        #else
            let safeInsets = HUDSafeAreaInsets.zero
            _ = scale // Silence unused warning on macOS
        #endif

        self.hud = HUD(size: hudSize, safeAreaInsets: safeInsets)
        self.hud.zPosition = 500
        self.cameraNode.addChild(self.hud)

        // Wire up HUD button callbacks
        self.hud.onCharacterToggle = { [weak self] in self?.toggleSelectedCharacter() }
        self.hud.onFollowModeToggle = { [weak self] in self?.toggleHermesFollowMode() }
        self.hud.onPauseTapped = { [weak self] in self?.pauseGame() }

        // Initialize with starting values
        self.hud.update(
            lives: self.levelManager.lives,
            score: self.levelManager.score,
            resources: ResourceManager.shared.totalCollected,
            elapsedTime: self.levelManager.elapsedTime
        )
    }

    private func setupCamera() {
        self.cameraNode = SKCameraNode()
        self.cameraNode.name = "camera"
        addChild(self.cameraNode)
        camera = self.cameraNode

        // Start camera at a reasonable position
        self.cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)

        // Create camera controller
        self.cameraController = CameraController(camera: self.cameraNode)
        self.cameraController.onZoomChanged = { [weak self] _ in
            self?.updateUIScaleForZoom()
        }
    }

    private func loadMap() {
        let mapName = self.levelConfig.mapName
        let levelNum = self.levelConfig.levelNumber
        logger.info("loadMap() called for level \(levelNum): \(mapName)")
        let parser = TMXParser()

        // Try to load the map from the bundle using level config
        guard let mapURL = Bundle.main.url(forResource: mapName, withExtension: "tmx") else {
            logger.error("Could not find \(mapName).tmx in bundle")
            self.showLoadError("Could not find \(mapName).tmx")
            return
        }

        logger.info("Found map at: \(mapURL.path)")

        guard let map = parser.parse(url: mapURL) else {
            logger.error("Failed to parse map")
            self.showLoadError("Failed to parse map")
            return
        }

        logger.info("Loaded map \(map.width)x\(map.height) tiles, \(map.pixelWidth)x\(map.pixelHeight) pixels")
        logger
            .info("\(map.tilesets.count) tilesets, \(map.layers.count) layers, \(map.objectGroups.count) object groups")

        // Log tileset info
        for tileset in map.tilesets {
            logger
                .info(
                    "Tileset: \(tileset.name), gid: \(tileset.firstGid), \(tileset.imageWidth)x\(tileset.imageHeight)"
                )
        }

        // Log layer info
        for layer in map.layers {
            logger.info("Layer: \(layer.name), size: \(layer.width)x\(layer.height), tiles: \(layer.tiles.count)")
        }

        // Create renderer and load tilesets
        self.mapRenderer = TMXRenderer(map: map)
        self.mapRenderer?.loadTilesets()

        // Create and add map node
        mapNode = self.mapRenderer?.createMapNode()
        if let mapNode {
            addChild(mapNode)
            print("GameScene: Map node added with \(mapNode.children.count) layer nodes")
        }

        // Log spawn points for debugging
        if let objects = mapRenderer?.getSpawnObjects() {
            print("GameScene: Found \(objects.count) spawn objects:")
            for obj in objects {
                let pos = self.mapRenderer?.convertToSpriteKit(point: obj.center) ?? CGPoint.zero
                print("  - \(obj.name) (\(obj.type)) at \(pos)")
            }
        }

        // Configure camera controller with map bounds
        self.cameraController.configure(
            mapSize: CGSize(width: map.pixelWidth, height: map.pixelHeight),
            viewportSize: self.visibleViewportSize.width > 0 ? self.visibleViewportSize : size
        )
    }

    /// Set up fog of war system
    private func setupFogOfWar() {
        guard let renderer = mapRenderer else {
            print("GameScene: Cannot setup fog of war - map not loaded")
            return
        }

        let map = renderer.map
        self.fogOfWar = FogOfWar(
            mapWidth: map.width,
            mapHeight: map.height,
            tileSize: CGFloat(map.tileWidth)
        )

        if let fogNode = fogOfWar?.fogNode {
            // Position fog above map tiles but below characters
            fogNode.zPosition = 50
            addChild(fogNode)
            print("GameScene: Fog of war initialized for \(map.width)x\(map.height) map")
        }
    }

    /// Configure common character properties (position, health bar, pathfinding, collision, targeting)
    private func configureCharacterCommon(_ character: Character, at position: CGPoint, with renderer: TMXRenderer) {
        character.position = position
        character.sprite.zPosition = self.characterZPosition
        character.sprite.setScale(1.0)

        // Set up health bars in the original map coordinate scale
        character.setupHealthBar(width: 40, yOffset: 8)
        character.healthBar?.hideWhenFull = false // Always show player health

        // Configure pathfinding for A* navigation around obstacles
        character.configurePathfinding(with: renderer)

        // Add structure collision check so characters path around towers
        character.pathfinding?.structureCollisionCheck = { [weak self] position, radius in
            self?.structureManager.collidesWithStructure(at: position, entityRadius: radius) ?? false
        }

        // Wire up targeting component callbacks (if present)
        if let nathaniel = character as? Nathaniel {
            nathaniel.targeting.findEnemies = { [weak self] in
                self?.enemyManager.aliveEnemies ?? []
            }
            nathaniel.targeting.getAllies = { [weak self] in
                var allies: [Character] = []
                if let n = self?.nathaniel {
                    allies.append(n)
                }
                if let h = self?.hermes {
                    allies.append(h)
                }
                return allies
            }
        } else if let hermes = character as? Hermes {
            hermes.targeting.findEnemies = { [weak self] in
                self?.enemyManager.aliveEnemies ?? []
            }
            hermes.targeting.getAllies = { [weak self] in
                var allies: [Character] = []
                if let n = self?.nathaniel {
                    allies.append(n)
                }
                if let h = self?.hermes {
                    allies.append(h)
                }
                return allies
            }
        }
    }

    /// Spawn all player characters at their designated spawn points
    private func spawnCharacters() {
        guard let renderer = mapRenderer else {
            print("GameScene: Cannot spawn characters - map not loaded")
            return
        }

        // Get all spawn objects
        let allObjects = renderer.getSpawnObjects()
        print("GameScene: Found \(allObjects.count) spawn objects")
        for obj in allObjects {
            print("GameScene: Object '\(obj.name)' type='\(obj.type)' at (\(obj.x), \(obj.y))")
        }

        // Spawn Nathaniel
        if let spawnObject = allObjects.first(where: { $0.name == "Nathaniel" }) {
            print("GameScene: Found Nathaniel spawn at TMX coords: (\(spawnObject.center.x), \(spawnObject.center.y))")
            let spawnPos = renderer.convertToSpriteKit(point: CGPoint(x: spawnObject.x, y: spawnObject.y))

            // Store start position for respawning
            self.startPosition = spawnPos

            nathaniel = Nathaniel()
            if let nathaniel {
                self.configureCharacterCommon(nathaniel, at: spawnPos, with: renderer)
                addChild(nathaniel.sprite)

                // Wire up weapon callbacks
                nathaniel.weapon.onFire = { [weak self] projectile in
                    guard let self else { return }
                    projectile.sprite.setScale(2.0)
                    addChild(projectile.sprite)
                }

                // Wire up death callback for game over handling
                nathaniel.onDeathCallback = { [weak self] in
                    self?.handleNathanielDeath()
                }

                print("GameScene: Spawned Nathaniel at \(spawnPos.x), \(spawnPos.y)")
            }
        } else {
            print("GameScene: No spawn point named 'Nathaniel' found in map")
        }

        // Spawn Hermes
        if let spawnObject = allObjects.first(where: { $0.name == "Hermes" }) {
            print("GameScene: Found Hermes spawn at TMX coords: (\(spawnObject.center.x), \(spawnObject.center.y))")
            let spawnPos = renderer.convertToSpriteKit(point: CGPoint(x: spawnObject.x, y: spawnObject.y))

            hermes = Hermes()
            if let hermes {
                self.configureCharacterCommon(hermes, at: spawnPos, with: renderer)

                // Set Hermes to follow Nathaniel
                hermes.followTarget = nathaniel
                hermes.isInBuildMode = true // Start stationary, ready to build

                // Losing Hermes ends the level.
                hermes.onDeathCallback = { [weak self] in
                    self?.handleHermesDeath()
                }

                addChild(hermes.sprite)

                // Set up Hermes laser node
                hermes.setupLaserNode(in: self)

                print("GameScene: Spawned Hermes at \(spawnPos.x), \(spawnPos.y)")
            }
        } else {
            print("GameScene: No spawn point named 'Hermes' found in map")
        }

        // Select Nathaniel by default
        self.selectedCharacter = nathaniel

        // Position camera at Nathaniel (clamped to map bounds)
        if let nathaniel {
            self.cameraController.setPosition(nathaniel.position)
        }

        // Spawn test enemies
        self.spawnEnemies()
    }

    /// Spawn enemies based on level config (map-based or wave-based)
    private func spawnEnemies() {
        guard let nathaniel else { return }

        // Register player characters with enemy manager
        var players: [Character] = []
        if let nathanielChar = self.nathaniel {
            players.append(nathanielChar)
        }
        if let hermesChar = hermes {
            players.append(hermesChar)
        }
        self.enemyManager.playerCharacters = players

        // Set up weapon collision callback for Nathaniel's bullets to hit enemies
        nathaniel.weapon.onCheckCollision = self.enemyManager.createCollisionCallback()

        // Set up structure manager with player characters for heal tower
        self.structureManager.playerCharacters = players

        // Set up resource manager for resource drops
        ResourceManager.shared.scene = self
        ResourceManager.shared.collectors = players
        ResourceManager.shared.delegate = self

        self.enemyManager.renderer = self.mapRenderer

        // Spawn enemies based on spawn mode
        switch self.levelConfig.spawnMode {
        case .mapBased:
            // Spawn from map object layer
            self.spawnEnemiesFromMap()

        case .waveBased:
            // Set up wave spawner for survival-style levels
            self.setupWaveSpawner()
        }
    }

    /// Spawn enemies from map spawn points
    private func spawnEnemiesFromMap() {
        guard let renderer = mapRenderer else { return }

        // Get spawn objects from map
        let allObjects = renderer.getSpawnObjects()

        // Filter to enemy spawns and spawn them
        self.enemyManager.spawnFromMapObjects(allObjects, renderer: renderer)

        logger.info("Spawned enemies from map objects")
    }

    /// Set up wave spawner for survival-style levels
    private func setupWaveSpawner() {
        guard let renderer = mapRenderer else { return }

        self.waveSpawner = WaveSpawner()
        self.waveSpawner?.enemyManager = self.enemyManager
        self.waveSpawner?.mapWidth = CGFloat(renderer.map.pixelWidth)
        self.waveSpawner?.mapHeight = CGFloat(renderer.map.pixelHeight)

        logger.info("Wave spawner set up for survival-style level")
    }

    private func showLoadError(_ message: String) {
        let errorLabel = SKLabelNode(fontNamed: "Helvetica")
        errorLabel.text = message
        errorLabel.fontSize = 24
        errorLabel.fontColor = .red
        errorLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(errorLabel)
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        // Calculate delta time
        let deltaTime: TimeInterval = if self.lastUpdateTime == 0 {
            0
        } else {
            currentTime - self.lastUpdateTime
        }
        self.lastUpdateTime = currentTime

        // Don't update game logic if not playing
        guard self.levelManager.state == .playing else {
            return
        }

        // Update level manager
        self.levelManager.update(deltaTime: deltaTime)

        // Update player characters
        self.nathaniel?.update(deltaTime: deltaTime)
        self.hermes?.update(deltaTime: deltaTime)

        // Update wave spawner for survival-style levels
        self.waveSpawner?.update(deltaTime: deltaTime)

        // Update enemies via manager
        self.enemyManager.update(deltaTime: deltaTime)

        // Update resources (collection, expiration)
        ResourceManager.shared.update(deltaTime: deltaTime)

        // Update defensive structures
        self.structureManager.update(deltaTime: deltaTime)

        // Update target indicator and check if target died
        self.updateTargetIndicator()

        // Update fog of war
        self.updateFogOfWar(currentTime: currentTime)

        // Camera follows selected character
        self.updateCameraFollow()

        // Update HUD
        self.updateHUD()

        #if DEBUG
            // Update pathfinding visualization
            self.updatePathfindingDebugOverlay()
        #endif
    }

    // MARK: - HUD Update

    private func updateHUD() {
        // Update all HUD values from level manager and resource manager
        self.hud.update(
            lives: self.levelManager.lives,
            score: self.levelManager.score,
            resources: ResourceManager.shared.totalCollected,
            elapsedTime: self.levelManager.elapsedTime
        )

        // Update selected character info
        if let selected = selectedCharacter {
            self.hud.updateSelectedCharacter(
                name: selected.name,
                health: selected.currentHP,
                maxHealth: selected.maxHP
            )
        }

        // Update player health bars
        self.hud.updatePlayerHealth(
            nathanielHP: self.nathaniel?.currentHP ?? 0,
            nathanielMaxHP: self.nathaniel?.maxHP ?? 1,
            hermesHP: self.hermes?.currentHP ?? 0,
            hermesMaxHP: self.hermes?.maxHP ?? 1
        )
    }

    // MARK: - Target Indicator Update

    /// Update target indicator position and check if target died
    private func updateTargetIndicator() {
        guard let indicator = targetIndicator else { return }

        // Check if target is still valid
        if let target = nathaniel?.target as? Enemy {
            if target.isAlive {
                // Update indicator position to follow target
                indicator.updatePosition()
            } else {
                // Target died - clear it
                clearTarget()
            }
        } else {
            // No target - remove indicator
            clearTarget()
        }
    }

    // MARK: - Fog of War Update

    /// Update fog of war based on player character positions
    private func updateFogOfWar(currentTime: TimeInterval) {
        guard let fog = fogOfWar else { return }

        // Collect character positions and vision ranges
        var visiblePositions: [(CGPoint, CGFloat)] = []

        if let nathaniel, nathaniel.isAlive {
            visiblePositions.append((nathaniel.position, nathaniel.visionRange))
        }

        if let hermes, hermes.isAlive {
            visiblePositions.append((hermes.position, hermes.visionRange))
        }

        // Update fog with throttling for performance
        fog.updateThrottled(visibleFrom: visiblePositions, currentTime: currentTime)

        // Update enemy visibility based on fog
        self.updateEnemyVisibility()
    }

    /// Update enemy sprite visibility based on fog of war
    private func updateEnemyVisibility() {
        guard let fog = fogOfWar else { return }

        for enemy in self.enemyManager.enemies {
            let isVisible = fog.isVisible(at: enemy.position)
            // Smoothly fade enemies in/out
            let targetAlpha: CGFloat = isVisible ? 1.0 : 0.0
            if abs(enemy.sprite.alpha - targetAlpha) > 0.01 {
                enemy.sprite.run(SKAction.fadeAlpha(to: targetAlpha, duration: 0.2))
            }
        }
    }

    // MARK: - Player Death Handling

    /// Handle Nathaniel's death
    private func handleNathanielDeath() {
        ResourceManager.shared.dropCarriedResources()
        let shouldRespawn = self.levelManager.handlePlayerDeath()

        if shouldRespawn {
            self.respawnNathaniel()
        }
    }

    /// Losing Hermes ends the game, as in the original.
    private func handleHermesDeath() {
        self.levelManager.triggerGameOver()
    }

    /// Respawn Nathaniel at start position
    private func respawnNathaniel() {
        guard let nathaniel else { return }

        // Re-add sprite to scene if removed
        if nathaniel.sprite.parent == nil {
            addChild(nathaniel.sprite)
        }

        // Reset sprite state
        nathaniel.sprite.alpha = 1.0
        nathaniel.sprite.removeAllActions()

        // Respawn at start position
        nathaniel.respawn(at: self.startPosition)

        // Update health bar
        nathaniel.updateHealthBar()

        // Set as selected character
        self.selectedCharacter = nathaniel

        // Re-register with enemy manager
        self.enemyManager.playerCharacters = [nathaniel]
        if let hermes, hermes.isAlive {
            self.enemyManager.playerCharacters.append(hermes)
        }

        // Update resource collectors
        ResourceManager.shared.collectors = self.enemyManager.playerCharacters

        logger.info("Nathaniel respawned at start position")
    }

    // MARK: - LevelManagerDelegate

    func levelManagerDidGameOver(_ manager: LevelManager) {
        self.setModal(.none)
        logger.info("Game Over!")
        self.gameOverlay.showGameOver(score: manager.score, time: manager.elapsedTime)
    }

    func levelManagerDidWin(_ manager: LevelManager) {
        self.setModal(.none)
        logger.info("Victory!")

        // Save progress for campaign levels (not survival mode)
        if self.levelConfig.levelNumber > 0 {
            GameSettings.shared.recordLevelCompletion(
                levelNumber: self.levelConfig.levelNumber,
                score: manager.score,
                time: manager.elapsedTime
            )
        }

        // Check if there's a next level
        let hasNextLevel = self.levelConfig.nextLevel != nil

        self.gameOverlay.showVictory(score: manager.score, time: manager.elapsedTime, hasNextLevel: hasNextLevel)
    }

    func levelManager(_ manager: LevelManager, didLoseLife remainingLives: Int) {
        logger.info("Life lost! Remaining: \(remainingLives)")
        self.gameOverlay.showLifeLost(remainingLives: remainingLives)
        self.hud.flashLifeLost()
    }

    func levelManager(_ manager: LevelManager, didUpdateScore newScore: Int) {
        self.hud.updateScore(newScore)
    }

    // MARK: - ResourceManagerDelegate

    func resourceManager(_ manager: ResourceManager, didUpdateTotal total: Int) {
        self.hud.updateResources(total)
    }

    func resourceManager(_ manager: ResourceManager, didCollectResource amount: Int) {
        self.hud.highlightResourceCollected(amount: amount)
    }

    // MARK: - TowerPlacementControllerDelegate

    func placementController(
        _ controller: TowerPlacementController,
        didPlaceTower type: TowerType,
        at position: CGPoint
    ) {
        self.hud.updateTowerCount(self.structureManager.hermesTowerCount)

        // Update affordability
        self.towerPlacementController?.updateAffordability()

        logger.debug("Placed \(type.displayName) at (\(position.x), \(position.y))")
    }

    func placementController(
        _ controller: TowerPlacementController,
        didFailPlacement type: TowerType,
        reason: PlacementResult
    ) {
        // Log failure reason
        switch reason {
        case .valid:
            logger.debug("Placement failed: insufficient resources")
        case .blockedByTerrain:
            logger.debug("Placement failed: blocked by terrain")
        case .overlapsStructure:
            logger.debug("Placement failed: overlaps structure")
        case .overlapsCharacter:
            logger.debug("Placement failed: overlaps character")
        case .overlapsEnemy:
            logger.debug("Placement failed: overlaps enemy")
        case .overlapsResource:
            logger.debug("Placement failed: overlaps corpse")
        }
    }

    // MARK: - StructureManagerDelegate

    func structureManager(_ manager: StructureManager, hermesTowerDestroyed remainingCount: Int) {
        self.hud.updateTowerCount(remainingCount)
    }

    func placementController(_ controller: TowerPlacementController, didCancelPlacement type: TowerType) {
        logger.debug("Placement cancelled for \(type.displayName)")
    }

    // MARK: - Camera Following

    /// Make the camera smoothly follow the selected character
    private func updateCameraFollow() {
        #if DEBUG
            // Skip camera following in free mode
            if DevSettings.shared.cameraFreeMode {
                return
            }

            // Apply zoom from dev settings if changed
            let targetZoom = DevSettings.shared.cameraZoom
            if abs(self.cameraController.currentZoom - targetZoom) > 0.01 {
                self.cameraController.setZoom(targetZoom)
            }
        #endif

        guard let selected = selectedCharacter else { return }

        #if DEBUG
            let smoothFactor = DevSettings.shared.cameraFollowSmoothing
        #else
            let smoothFactor: CGFloat = 0.1
        #endif

        self.cameraController.updateFollow(target: selected.position, smoothing: smoothFactor)
    }

    // MARK: - Camera Zoom

    /// Update camera zoom by a scale factor
    /// - Parameter scale: Multiplier for current zoom (>1 zooms in, <1 zooms out)
    func updateZoom(by scale: CGFloat) {
        self.cameraController.updateZoom(by: scale)
    }

    /// Set camera zoom to an absolute value
    /// - Parameter zoom: Target zoom level (clamped to min/max)
    func setZoom(_ zoom: CGFloat) {
        self.cameraController.setZoom(zoom)
    }

    /// Handle pinch gesture zoom (called from iOS GameViewController)
    /// - Parameter scale: Gesture scale factor
    func handlePinchZoom(scale: CGFloat) {
        self.cameraController.handlePinchZoom(scale: scale)
    }

    /// Keep HUD and overlay at consistent screen size when zooming
    private func updateUIScaleForZoom() {
        let inverseScale = 1.0 / self.cameraController.currentZoom
        self.hud?.setScale(inverseScale)
        self.gameOverlay?.setScale(inverseScale)
    }
}

// MARK: - Platform Input (via InputHandlingScene)

extension GameScene {
    override func handlePointerDown(at location: CGPoint) -> Bool {
        // Dispatch to overlay menus first
        if dispatchInputToOverlayMenus(at: location) {
            return true
        }

        handleTap(at: location)
        return true
    }

    override func handlePointerMoved(to location: CGPoint) -> Bool {
        let hudLocation = self.cameraNode.convert(location, from: self)

        // Forward to build menu if dragging
        if let controller = towerPlacementController, controller.isDragging {
            // Pass both coordinate spaces - HUD for ghost tower, world for placement
            _ = controller.handleTouchMoved(to: location, hudLocation: hudLocation, in: self)
            return true
        }
        return false
    }

    override func handlePointerUp(at location: CGPoint) -> Bool {
        let hudLocation = self.cameraNode.convert(location, from: self)

        // Forward to build menu if dragging
        if let controller = towerPlacementController, controller.isDragging {
            _ = controller.handleTouchEnded(at: location, hudLocation: hudLocation)
            return true
        }
        return false
    }

    override func handlePointerCancelled() {
        // Cancel any active build menu drag
        self.towerPlacementController?.handleTouchCancelled()
    }

    override func handleSecondaryClick(at location: CGPoint) -> Bool {
        guard self.levelManager.state == .playing, self.modal == .none else { return false }
        // Right-click to fire weapon at location (macOS only)
        if let nathaniel {
            if nathaniel.fireAt(location) {
                logger.debug("Fired at \(location.x), \(location.y)")
            }
            return true
        }
        return false
    }

    override func handleScroll(deltaY: CGFloat) -> Bool {
        // Use scroll delta for zoom - positive deltaY = scroll up = zoom in
        let zoomSensitivity: CGFloat = 0.02
        let zoomDelta = deltaY * zoomSensitivity
        self.updateZoom(by: 1.0 + zoomDelta)
        return true
    }

    override func handleKeyDown(keyCode: UInt16) -> Bool {
        if self.gameOverlay.state == .victory || self.gameOverlay.state == .gameOver {
            self.gameOverlay.handleInteraction()
            return true
        }

        if keyCode == 53 { // Escape closes the top menu before resuming.
            self.closeTopModal()
            return true
        }

        // Don't handle other keys if game is not in playing state
        guard self.levelManager.state == .playing else { return false }

        switch keyCode {
        case 1: // S key - stop movement
            self.nathaniel?.stop()
            return true
        #if os(OSX)
            case 3: // F key - fire weapon at mouse position
                self.fireAtMousePosition()
                return true
        #endif
        case 15: // R key - toggle Hermes follow mode
            self.toggleHermesFollowMode()
            return true
        case 49: // Space key - switch selected character
            toggleSelectedCharacter()
            return true
        default:
            return false
        }
    }

    #if os(OSX)
        /// Fire Nathaniel's weapon at the current mouse position
        private func fireAtMousePosition() {
            guard let view,
                  let nathaniel else { return }

            let mouseLocationInWindow = NSEvent.mouseLocation
            guard let window = view.window else { return }
            let windowLocation = window.convertPoint(fromScreen: mouseLocationInWindow)
            let viewLocation = view.convert(windowLocation, from: nil)
            let sceneLocation = convertPoint(fromView: viewLocation)

            if nathaniel.fireAt(sceneLocation) {
                logger.debug("Fired at \(sceneLocation.x), \(sceneLocation.y)")
            }
        }
    #endif
}

// MARK: - Input Handling

extension GameScene {
    /// Select a character, target an enemy, or move Nathaniel.
    func handleTap(at location: CGPoint) {
        // Check if the overlay is showing (victory/game over)
        if self.gameOverlay.state == .victory || self.gameOverlay.state == .gameOver {
            self.gameOverlay.handleInteraction()
            return
        }

        // Don't handle taps if game is not in playing state
        guard self.levelManager.state == .playing else { return }

        // HUD has its own scale, so convert directly into its local space.
        let hudLocation = self.hud.convert(location, from: self)
        if self.hud.handleTouch(at: hudLocation) {
            return
        }

        // Check if tapping on a character to select them
        if let nathaniel, nathaniel.contains(point: location) {
            self.selectCharacter(nathaniel)
            logger.debug("Selected Nathaniel")
            return
        }

        if let hermes, hermes.contains(point: location) {
            if self.selectedCharacter === self.nathaniel,
               self.nathaniel?.hasCorpse == true, hermes.isInBuildMode
            {
                self.handleMoveCommand(to: hermes.position)
                return
            }
            self.selectCharacter(hermes)
            logger.debug("Selected Hermes")
            return
        }

        // Check if tapping on an enemy to target them
        if let enemy = enemyAtPoint(location) {
            self.targetEnemy(enemy, tapLocation: location)
            return
        }

        // Ground commands always move Nathaniel.
        self.handleMoveCommand(to: location)
    }

    /// Select a character for control
    private func selectCharacter(_ character: Character) {
        // Hide previous selection visuals
        hermes?.hideSelectionHighlight()

        self.selectedCharacter = character

        // Camera selection does not change Hermes's movement mode.
        if let hermes, character === hermes {
            hermes.showSelectionHighlight()

            // Update placement controller with Hermes reference
            self.towerPlacementController?.updateAffordability()

            // Configure validator with current game state
            if let mapRenderer {
                var players: [Character] = []
                if let nathanielChar = nathaniel {
                    players.append(nathanielChar)
                }
                players.append(hermes) // hermes is known non-nil here
                self.towerPlacementController?.configureValidator(
                    tmxRenderer: mapRenderer,
                    enemyManager: self.enemyManager,
                    playerCharacters: players
                )
            }
        } else {
            // Selecting Nathaniel - hide build button, menu, and Hermes visuals
            self.hud.hideBuildButton()
            self.towerPlacementController?.hideMenu()
            hermes?.hideSelectionHighlight()
        }
        self.updateHermesControls()

        // Animate camera to new character position
        self.cameraController.animateTo(character.position)
    }

    /// Toggle between Nathaniel and Hermes
    func toggleSelectedCharacter() {
        if self.selectedCharacter === self.nathaniel {
            if let hermes {
                self.selectCharacter(hermes)
                logger.debug("Switched to Hermes")
            }
        } else {
            if let nathaniel {
                self.selectCharacter(nathaniel)
                logger.debug("Switched to Nathaniel")
            }
        }
    }

    /// Toggle Hermes between follow mode and independent mode
    func toggleHermesFollowMode() {
        guard let hermes else { return }
        self.setHermesMode(hermes.mode == .following ? .independent : .following)
    }

    /// Apply Hermes commands from the HUD, keyboard, and game command server.
    func setHermesMode(_ mode: HermesMode) {
        guard self.levelManager.state == .playing, let hermes, hermes.isAlive else { return }
        hermes.mode = mode
        if mode == .following {
            let refund = self.structureManager.dismantleHermesTowers()
            if refund > 0 {
                ResourceManager.shared.addResources(refund)
            }
        }
        self.updateHermesControls()
    }

    private func updateHermesControls() {
        guard let hermes else { return }
        self.hud.updateFollowMode(isFollowing: hermes.mode == .following)
        if self.selectedCharacter === hermes, hermes.isInBuildMode {
            self.hud.showBuildButton()
        } else {
            self.hud.hideBuildButton()
            self.towerPlacementController?.hideMenu()
        }
    }

    /// Toggle the build menu visibility
    func toggleBuildMenu() {
        self.towerPlacementController?.toggleMenu()
    }

    /// Check if build menu is currently visible
    var isBuildMenuVisible: Bool {
        self.towerPlacementController?.buildMenu.isVisible ?? false
    }

    /// Dispatch input to all overlay menus (save slots, settings, pause, build menu)
    /// - Parameter scenePoint: Touch/click location in scene coordinates
    /// - Returns: true if input was handled by an overlay menu, false otherwise
    private func dispatchInputToOverlayMenus(at scenePoint: CGPoint) -> Bool {
        let hudLocation = self.cameraNode.convert(scenePoint, from: self)

        if self.gameOverlay.state == .victory || self.gameOverlay.state == .gameOver {
            self.gameOverlay.handleInteraction()
            return true
        }
        switch self.modal {
        case .save:
            _ = self.saveSlotSelector.handleTouch(at: hudLocation)
            return true
        case .settings:
            _ = self.settingsMenu.handleTouch(at: hudLocation)
            return true
        case .pause:
            _ = self.pauseMenu.handleTouch(at: hudLocation)
            return true
        case .none:
            break
        }

        if let controller = towerPlacementController {
            if controller.handleTouchBegan(at: hudLocation) {
                return true
            } else if controller.buildMenu.isVisible {
                controller.hideMenu()
                return true
            }
        }

        return false
    }

    /// Build through the same placement validation used by touch and mouse input.
    @discardableResult
    func buildTower(type: TowerType, at position: CGPoint) -> Bool {
        self.towerPlacementController?.attemptPlacement(type: type, at: position) ?? false
    }

    /// Ground commands always move Nathaniel, even when the camera follows Hermes.
    func handleMoveCommand(to location: CGPoint) {
        guard self.levelManager.state == .playing, let nathaniel, nathaniel.isAlive else { return }
        nathaniel.clearManualTarget()
        nathaniel.moveTo(location)
    }

    // MARK: - Enemy Targeting

    /// Find an enemy at the given point (with expanded hit area for easier targeting)
    private func enemyAtPoint(_ point: CGPoint) -> Enemy? {
        // Use 1.5x sprite size for easier touch targeting
        let hitAreaMultiplier: CGFloat = 1.5

        for enemy in self.enemyManager.enemies {
            guard enemy.isAlive else { continue }

            // Get the sprite's frame and expand it
            let spriteFrame = enemy.sprite.frame
            let expandedFrame = spriteFrame.insetBy(
                dx: -spriteFrame.width * (hitAreaMultiplier - 1) / 2,
                dy: -spriteFrame.height * (hitAreaMultiplier - 1) / 2
            )

            if expandedFrame.contains(point) {
                return enemy
            }
        }
        return nil
    }

    /// Target an enemy - sets the selected character's target and shows indicator
    private func targetEnemy(_ enemy: Enemy, tapLocation: CGPoint) {
        // Only allow targeting enemies that are currently visible (not in fog of war)
        if let fog = fogOfWar, !fog.isVisible(at: enemy.position) {
            logger.debug("Cannot target enemy - not visible in fog of war")
            return
        }

        self.nathaniel?.setManualTarget(enemy)

        // Remove existing indicator
        self.targetIndicator?.remove()

        // Create new indicator
        self.targetIndicator = TargetIndicator.create(for: enemy.sprite, in: self)

        // Play feedback
        self.playTargetFeedback(at: tapLocation)
    }

    /// Clear the current target (called when enemy dies)
    private func clearTarget() {
        self.nathaniel?.clearManualTarget()
        self.hermes?.clearManualTarget()
        self.targetIndicator?.remove()
        self.targetIndicator = nil
    }

    /// Play haptic and visual feedback when targeting
    private func playTargetFeedback(at location: CGPoint) {
        // Haptic feedback (iOS only)
        #if os(iOS)
            self.hapticGenerator?.impactOccurred()
        #endif

        // Visual ripple effect
        self.showTapRipple(at: location)
    }

    /// Show an expanding ripple effect at the tap location
    private func showTapRipple(at point: CGPoint) {
        let ripple = SKShapeNode(circleOfRadius: 15)
        ripple.strokeColor = SKColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.8)
        ripple.fillColor = .clear
        ripple.lineWidth = 2.0
        ripple.position = point
        ripple.zPosition = 200 // Above enemies

        addChild(ripple)

        // Expand and fade out
        let expand = SKAction.scale(to: 3.0, duration: 0.3)
        expand.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.3)
        let group = SKAction.group([expand, fade])
        let remove = SKAction.removeFromParent()

        ripple.run(SKAction.sequence([group, remove]))
    }
}

// MARK: - DEBUG Internal Accessors

#if DEBUG
    extension GameScene {
        // Internal accessors for GameCommandDelegate to avoid Mirror reflection.
        // These expose private properties only in DEBUG builds for testing.

        /// Expose only the controls that currently receive pointer input.
        func activeOverlayControls() -> [GameCommandServer.NodeInfo]? {
            if self.gameOverlay.state == .victory || self.gameOverlay.state == .gameOver {
                return [self.gameOverlay.toNodeInfo(interactive: true)]
            }
            switch self.modal {
            case .pause:
                let names = self.pauseMenu.isShowingConfirmation
                    ? ["cancelExit", "confirmExit"]
                    : ["resumeButton", "settingsButton", "saveGameButton", "exitToMenuButton"]
                return self.pauseMenu.namedControls(names)
            case .settings:
                return self.settingsMenu.commandControls()
            case .save:
                return self.saveSlotSelector.namedControls(["slot_1", "slot_2", "slot_3", "cancelButton"])
            case .none:
                if let menu = self.towerPlacementController?.buildMenu, menu.isVisible {
                    return menu.namedControls(TowerType.allCases.map { "buildMenuItem_\($0.rawValue)" })
                }
                return nil
            }
        }

        var internalNathaniel: Nathaniel? {
            self.nathaniel
        }

        var internalHermes: Hermes? {
            self.hermes
        }

        var internalEnemyManager: EnemyManager? {
            self.enemyManager
        }

        var internalStructureManager: StructureManager? {
            self.structureManager
        }

        var internalLevelManager: LevelManager? {
            self.levelManager
        }

        var internalPauseMenu: PauseMenu? {
            self.pauseMenu
        }

        var internalSettingsMenu: SettingsMenu? {
            self.settingsMenu
        }

        var internalSaveSlotSelector: SaveSlotSelector? {
            self.saveSlotSelector
        }

        var internalHUD: HUD? {
            self.hud
        }
    }
#endif

// MARK: - Saved Game State

extension GameScene {
    /// Capture the scene using its fields directly, including tower ownership and carried resources.
    func createSaveState(displayName: String) -> SavedGameState? {
        guard let nathaniel, let hermes, let levelManager else { return nil }

        let enemyStates = (enemyManager?.enemies ?? []).filter(\.isAlive).compactMap { enemy in
            let targetIndex: Int? = if enemy.target === nathaniel {
                0
            } else if enemy.target === hermes {
                1
            } else {
                nil
            }
            return enemy.toSavedEnemyState(targetIndex: targetIndex)
        }

        return SavedGameState(
            savedAt: Date(),
            displayName: displayName,
            levelNumber: levelManager.config.levelNumber,
            elapsedTime: levelManager.elapsedTime,
            score: levelManager.score,
            lives: levelManager.lives,
            resources: ResourceManager.shared.totalCollected,
            nathaniel: nathaniel.toSavedCharacterState(),
            hermes: hermes.toSavedHermesState(),
            enemies: enemyStates,
            towers: self.structureManager?.savedTowerStates() ?? [],
            currentWave: self.waveSpawner?.currentWave,
            timeUntilNextWave: self.waveSpawner?.timeUntilNextWave,
            battlefieldResources: ResourceManager.shared.resources.map { $0.toSavedResourceState() }
        )
    }
}
