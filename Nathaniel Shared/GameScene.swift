import os.log
import SpriteKit
#if os(iOS)
    import UIKit
#endif

private let logger = Logger(subsystem: "com.ruarfff.Nathaniel", category: "GameScene")

class GameScene: SKScene, LevelManagerDelegate, ResourceManagerDelegate, TowerPlacementControllerDelegate,
    StructureManagerDelegate
{
    // MARK: - Properties

    /// The level configuration to use
    var levelConfig: LevelConfig = .levelOne

    /// The camera node for viewport control
    private var cameraNode: SKCameraNode!

    /// The map renderer
    private var mapRenderer: TMXRenderer?

    /// The map node containing all tile layers
    private var mapNode: SKNode?

    /// Debug label for showing info
    private var debugLabel: SKLabelNode?

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

    /// Pause menu overlay
    private var pauseMenu: PauseMenu!

    /// Settings menu overlay
    private var settingsMenu: SettingsMenu!

    /// Save slot selector overlay
    private var saveSlotSelector: SaveSlotSelector!

    /// HUD for displaying game status
    private var hud: HUD!

    /// Whether to show debug info (can be toggled)
    private var showDebugInfo: Bool = false

    /// Starting spawn position for respawn
    private var startPosition: CGPoint = .zero

    /// Last update time for delta time calculation
    private var lastUpdateTime: TimeInterval = 0

    /// Z-position for character sprites (above map tiles)
    private let characterZPosition: CGFloat = 100

    // MARK: - Camera Zoom Properties

    /// Current camera zoom level (1.0 = default, higher = zoomed in)
    private var cameraZoom: CGFloat = 1.0

    /// Minimum zoom level (zoomed out)
    private let minZoom: CGFloat = 0.5

    /// Maximum zoom level (zoomed in)
    private let maxZoom: CGFloat = 2.0

    /// Whether camera is currently animating to a new position
    private var isCameraAnimating: Bool = false

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

        scene.scaleMode = .aspectFill
        scene.levelConfig = levelConfig

        return scene
    }

    override func didMove(to view: SKView) {
        // Remove default SpriteKit template content from GameScene.sks
        backgroundColor = SKColor.black
        childNode(withName: "helloLabel")?.removeFromParent()

        setupCamera()
        setupLevelManager()
        setupEnemyManager()
        setupStructureManager()
        setupOverlay()
        setupHUD()
        loadMap()
        setupFogOfWar()
        spawnCharacters()
        setupBuildSystem()
        setupHaptics()
        if showDebugInfo {
            setupDebugLabel()
        }
        #if DEBUG
            setupPathfindingDebugOverlay()
        #endif

        // Start gameplay music
        AudioManager.shared.playMusic(.gameplay)

        #if DEBUG
            // Set this scene as the command server delegate
            GameCommandServer.shared.delegate = self
        #endif

        // Restore from save if loading from saved game
        restoreFromSavedState()
    }

    private func setupHaptics() {
        #if os(iOS)
            hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
            hapticGenerator?.prepare()
        #endif
    }

    #if DEBUG
        private func setupPathfindingDebugOverlay() {
            let overlay = PathfindingDebugOverlay()
            overlay.configure(player: nathaniel, companion: hermes)
            // Add to mapNode so paths render in world coordinates
            if let mapNode {
                mapNode.addChild(overlay)
            } else {
                addChild(overlay)
            }
            pathfindingDebugOverlay = overlay
        }

        private func updatePathfindingDebugOverlay() {
            guard DevSettings.shared.showPathfindingDebug else {
                pathfindingDebugOverlay?.isHidden = true
                return
            }
            pathfindingDebugOverlay?.isHidden = false
            pathfindingDebugOverlay?.updateEnemies(enemyManager.enemies)
            pathfindingDebugOverlay?.update()
        }
    #endif

    private func setupLevelManager() {
        levelManager = LevelManager(config: levelConfig)
        levelManager.delegate = self
    }

    private func setupEnemyManager() {
        enemyManager = EnemyManager(scene: self)
        enemyManager.enemyZPosition = characterZPosition
        enemyManager.enemyScale = 3.0
        enemyManager.delegate = levelManager
        levelManager.enemyManager = enemyManager
    }

    private func setupStructureManager() {
        structureManager = StructureManager(scene: self)
        structureManager.structureZPosition = characterZPosition
        structureManager.structureScale = 2.5
        structureManager.enemyManager = enemyManager
        structureManager.delegate = self
    }

    private func setupBuildSystem() {
        // Create tower placement controller
        let controller = TowerPlacementController(viewportSize: size)
        controller.setup(
            scene: self,
            structureManager: structureManager,
            resourceManager: ResourceManager.shared,
            hermes: hermes
        )
        controller.delegate = self

        // Add build menu to camera (HUD layer)
        controller.buildMenu.zPosition = 400
        cameraNode.addChild(controller.buildMenu)

        // Add placement indicator to scene (world space)
        addChild(controller.placementIndicator)

        towerPlacementController = controller

        // Wire up HUD callbacks
        hud.onBuildTapped = { [weak self] in
            self?.towerPlacementController?.toggleMenu()
        }

        hud.onReleaseHermes = { [weak self] in
            self?.releaseHermes()
        }
    }

    private func setupOverlay() {
        gameOverlay = GameOverlay(size: size)
        gameOverlay.zPosition = 1_000
        cameraNode.addChild(gameOverlay)

        // Set up overlay callbacks
        gameOverlay.onNextLevel = { [weak self] in
            self?.transitionToNextLevel()
        }

        gameOverlay.onRetry = { [weak self] in
            self?.restartLevel()
        }

        gameOverlay.onMainMenu = { [weak self] in
            self?.returnToMainMenu()
        }

        // Set up pause menu
        pauseMenu = PauseMenu(size: size)
        pauseMenu.zPosition = 900 // Below game overlay but above HUD
        cameraNode.addChild(pauseMenu)

        // Wire up pause menu callbacks
        pauseMenu.onResume = { [weak self] in
            self?.resumeGame()
        }

        pauseMenu.onSettings = { [weak self] in
            self?.showSettings()
        }

        pauseMenu.onSaveGame = { [weak self] in
            self?.showSaveSlotSelector()
        }

        // Set up settings menu
        settingsMenu = SettingsMenu(size: size)
        settingsMenu.zPosition = 920 // Above pause menu, below save slot selector
        cameraNode.addChild(settingsMenu)

        settingsMenu.onBack = { [weak self] in
            // Return focus to pause menu (which is still visible underneath)
            logger.debug("Settings menu closed")
        }

        settingsMenu.onSettingChanged = { setting, value in
            logger.debug("Setting changed: \(setting.rawValue) = \(value)")
        }

        // Set up save slot selector
        saveSlotSelector = SaveSlotSelector(size: size)
        saveSlotSelector.zPosition = 950 // Above pause menu
        cameraNode.addChild(saveSlotSelector)

        saveSlotSelector.onSlotSelected = { [weak self] slotId in
            self?.saveGameToSlot(slotId)
        }

        saveSlotSelector.onCancel = { [weak self] in
            // Return focus to pause menu
            logger.debug("Save slot selection cancelled")
        }

        pauseMenu.onExitToMenu = { [weak self] in
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
        let scene = newGameScene(levelConfig: levelConfig)

        // Store the save state to restore after setup
        scene.pendingSaveState = state

        return scene
    }

    /// Called after scene setup to restore saved state
    private func restoreFromSavedState() {
        guard let state = pendingSaveState else { return }
        pendingSaveState = nil

        logger.info("Restoring game from save: Level \(state.levelNumber)")

        // Restore level manager state
        levelManager.restore(
            elapsedTime: state.elapsedTime,
            score: state.score,
            lives: state.lives
        )

        // Restore resources
        ResourceManager.shared.restore(total: state.resources)

        // Restore Nathaniel
        if let nathaniel {
            nathaniel.restoreFromSavedState(state.nathaniel)
            startPosition = nathaniel.position // Update respawn point
        }

        // Restore Hermes
        if let hermes {
            hermes.restoreFromSavedState(state.hermes)
        }

        // Clear existing enemies and restore from save
        enemyManager.removeAllEnemies()
        for enemyState in state.enemies {
            let enemy = enemyState.type.createEnemy()
            enemy.restore(from: enemyState)

            // Restore target reference
            if let targetIndex = enemyState.targetIndex {
                if targetIndex == 0 {
                    enemy.target = nathaniel
                } else if targetIndex == 1 {
                    enemy.target = hermes
                }
            }

            enemyManager.addEnemy(enemy)
        }

        // Restore towers
        for towerState in state.towers {
            let position = towerState.position.cgPoint
            var tower: DefensiveStructure? = switch towerState.type {
            case .gunTower:
                structureManager.addGunTower(at: position)
            case .laserTower:
                structureManager.addLaserTower(at: position)
            case .healTower:
                structureManager.addHealTower(at: position)
            }

            // Restore tower HP
            if let tower {
                tower.currentHP = towerState.currentHP

                // Mark as Hermes-owned if applicable
                if towerState.isHermesOwned {
                    structureManager.markAsHermesOwned(tower)
                }
            }
        }

        // Restore wave state if applicable
        if let currentWave = state.currentWave {
            waveSpawner?.restore(wave: currentWave, timeUntilNext: state.timeUntilNextWave ?? 0)
        }

        // Update camera to follow restored Nathaniel position (clamped to map bounds)
        if let nathaniel {
            clampCameraToMapBounds(targetPosition: nathaniel.position)
        }

        // Update HUD
        updateHUD()

        logger.info("Save state restored successfully")
    }

    // MARK: - Level Transitions

    /// Transition to the next level
    private func transitionToNextLevel() {
        guard let nextConfig = levelConfig.nextLevel else {
            returnToMainMenu()
            return
        }

        let nextScene = GameScene.newGameScene(levelConfig: nextConfig)
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentSceneWithNotification(nextScene, transition: transition)
    }

    /// Restart the current level
    private func restartLevel() {
        let restartScene = GameScene.newGameScene(levelConfig: levelConfig)
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

    /// Pause the game
    func pauseGame() {
        guard levelManager.state == .playing else { return }
        levelManager.pause()
        pauseMenu.show()
        logger.info("Game paused")
    }

    /// Resume the game from pause
    func resumeGame() {
        guard levelManager.state == .paused else { return }
        pauseMenu.hide { [weak self] in
            self?.levelManager.resume()
            logger.info("Game resumed")
        }
    }

    /// Show the settings menu
    private func showSettings() {
        settingsMenu.show()
        logger.debug("Showing settings menu")
    }

    /// Show the save slot selector
    private func showSaveSlotSelector() {
        saveSlotSelector.show(mode: .save)
        logger.debug("Showing save slot selector")
    }

    /// Save the game to a specific slot
    private func saveGameToSlot(_ slotId: Int) {
        // Create save state from current game
        let displayName = "Level \(levelConfig.levelNumber)"
        guard let saveState = createSaveState(displayName: displayName) else {
            logger.error("Failed to create save state")
            showSaveNotification(success: false)
            return
        }

        // Save to the selected slot
        let success = SaveManager.shared.saveToSlot(saveState, slotId: slotId)

        // Show notification
        showSaveNotification(success: success)

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

        cameraNode.addChild(notification)

        // Fade in, hold, fade out
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let wait = SKAction.wait(forDuration: 1.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()

        notification.run(SKAction.sequence([fadeIn, wait, fadeOut, remove]))
    }

    private func setupHUD() {
        // Calculate visible area for HUD positioning
        // The HUD is attached to the camera, which uses centered coordinates
        // With .aspectFill, the scene is scaled to FILL the view (no black bars)
        // The scale factor is: max(viewWidth/sceneWidth, viewHeight/sceneHeight)
        // This means part of the scene extends beyond the visible area and gets cropped
        //
        // IMPORTANT: We assume landscape orientation where width > height
        // The view.bounds may not be reliable during didMove(to:) as the layout
        // may not have completed yet. We use max/min to ensure correct orientation.
        let hudSize: CGSize
        var safeInsets = HUDSafeAreaInsets.zero

        if let view {
            // Get view dimensions, ensuring landscape orientation (width > height)
            let viewWidth = max(view.bounds.width, view.bounds.height)
            let viewHeight = min(view.bounds.width, view.bounds.height)

            // Calculate scale factors for each dimension
            let scaleX = viewWidth / size.width
            let scaleY = viewHeight / size.height

            // aspectFill uses the larger scale (to fill the view completely)
            let scale = max(scaleX, scaleY)

            // Calculate visible area in scene coordinates
            // This is the portion of the scene that's actually visible on screen
            let visibleWidth = viewWidth / scale
            let visibleHeight = viewHeight / scale

            hudSize = CGSize(width: visibleWidth, height: visibleHeight)

            // Get safe area insets and convert to scene coordinates
            #if os(iOS)
                let viewSafeInsets = view.safeAreaInsets

                // Check if the view bounds are in portrait orientation (height > width)
                // If so, we need to rotate the safe area insets to match landscape
                let viewIsPortrait = view.bounds.height > view.bounds.width

                let landscapeSafeInsets: UIEdgeInsets
                if viewIsPortrait {
                    // View is in portrait but we want landscape coordinates
                    // Rotate CCW: portrait top->landscape left, portrait bottom->landscape right
                    // portrait left->landscape bottom, portrait right->landscape top
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

                // Convert from view points to scene coordinates by dividing by scale
                safeInsets = HUDSafeAreaInsets(
                    top: landscapeSafeInsets.top / scale,
                    bottom: landscapeSafeInsets.bottom / scale,
                    left: landscapeSafeInsets.left / scale,
                    right: landscapeSafeInsets.right / scale
                )
                logger.debug(
                    "Safe area insets (scene coords): " +
                        "top=\(safeInsets.top), bottom=\(safeInsets.bottom), " +
                        "left=\(safeInsets.left), right=\(safeInsets.right)"
                )
            #endif

            logger.debug(
                "HUD setup: view=\(viewWidth)x\(viewHeight), " +
                    "scene=\(size.width)x\(size.height), " +
                    "scale=\(scale), hudSize=\(hudSize.width)x\(hudSize.height)"
            )
        } else {
            hudSize = size
        }

        // Store the visible viewport size for camera clamping
        visibleViewportSize = hudSize

        hud = HUD(size: hudSize, safeAreaInsets: safeInsets)
        hud.zPosition = 500
        cameraNode.addChild(hud)

        // Set up Release Hermes button callback
        hud.onReleaseHermes = { [weak self] in
            self?.releaseHermes()
        }

        // Set up character toggle button callback
        hud.onCharacterToggle = { [weak self] in
            self?.toggleSelectedCharacter()
        }

        // Set up follow mode toggle button callback
        hud.onFollowModeToggle = { [weak self] in
            self?.toggleHermesFollowMode()
        }

        // Set up pause button callback
        hud.onPauseTapped = { [weak self] in
            self?.pauseGame()
        }

        // Initialize with starting values
        hud.update(
            lives: levelManager.lives,
            score: levelManager.score,
            resources: ResourceManager.shared.totalCollected,
            elapsedTime: levelManager.elapsedTime
        )
    }

    private func setupCamera() {
        cameraNode = SKCameraNode()
        cameraNode.name = "camera"
        addChild(cameraNode)
        camera = cameraNode

        // Start camera at a reasonable position
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private func loadMap() {
        let mapName = levelConfig.mapName
        let levelNum = levelConfig.levelNumber
        logger.info("loadMap() called for level \(levelNum): \(mapName)")
        let parser = TMXParser()

        // Try to load the map from the bundle using level config
        guard let mapURL = Bundle.main.url(forResource: mapName, withExtension: "tmx") else {
            logger.error("Could not find \(mapName).tmx in bundle")
            showLoadError("Could not find \(mapName).tmx")
            return
        }

        logger.info("Found map at: \(mapURL.path)")

        guard let map = parser.parse(url: mapURL) else {
            logger.error("Failed to parse map")
            showLoadError("Failed to parse map")
            return
        }

        logger.info("Loaded map \(map.width)x\(map.height) tiles, \(map.pixelWidth)x\(map.pixelHeight) pixels")
        logger
            .info("\(map.tilesets.count) tilesets, \(map.layers.count) layers, \(map.objectGroups.count) object groups")

        // Log tileset info
        for tileset in map.tilesets {
            logger.info(
                "Tileset: \(tileset.name), firstGid: \(tileset.firstGid), " +
                    "image: \(tileset.imageSource), " +
                    "size: \(tileset.imageWidth)x\(tileset.imageHeight)"
            )
        }

        // Log layer info
        for layer in map.layers {
            logger.info("Layer: \(layer.name), size: \(layer.width)x\(layer.height), tiles: \(layer.tiles.count)")
        }

        // Create renderer and load tilesets
        mapRenderer = TMXRenderer(map: map)
        mapRenderer?.loadTilesets()

        // Create and add map node
        mapNode = mapRenderer?.createMapNode()
        if let mapNode {
            addChild(mapNode)
            print("GameScene: Map node added with \(mapNode.children.count) layer nodes")
        }

        // Log spawn points for debugging
        if let objects = mapRenderer?.getSpawnObjects() {
            print("GameScene: Found \(objects.count) spawn objects:")
            for obj in objects {
                let pos = mapRenderer?.convertToSpriteKit(point: obj.center) ?? CGPoint.zero
                print("  - \(obj.name) (\(obj.type)) at \(pos)")
            }
        }
    }

    /// Set up fog of war system
    private func setupFogOfWar() {
        guard let renderer = mapRenderer else {
            print("GameScene: Cannot setup fog of war - map not loaded")
            return
        }

        let map = renderer.map
        fogOfWar = FogOfWar(
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
            let spawnPos = renderer.convertToSpriteKit(point: spawnObject.center)

            // Store start position for respawning
            startPosition = spawnPos
            levelManager.startPosition = spawnPos

            nathaniel = Nathaniel()
            if let nathaniel {
                nathaniel.position = spawnPos
                nathaniel.sprite.zPosition = characterZPosition
                nathaniel.sprite.setScale(3.0)
                addChild(nathaniel.sprite)

                // Set up health bar (scaled for the 3x sprite size)
                nathaniel.setupHealthBar(width: 40, yOffset: 8)
                nathaniel.healthBar?.hideWhenFull = false // Always show player health

                // Configure pathfinding for A* navigation around obstacles
                nathaniel.configurePathfinding(with: renderer)

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
            let spawnPos = renderer.convertToSpriteKit(point: spawnObject.center)

            hermes = Hermes()
            if let hermes {
                hermes.position = spawnPos
                hermes.sprite.zPosition = characterZPosition
                hermes.sprite.setScale(3.0)

                // Set Hermes to follow Nathaniel
                hermes.followTarget = nathaniel
                hermes.isInBuildMode = false // Start following

                // Set up health bar
                hermes.setupHealthBar(width: 40, yOffset: 8)
                hermes.healthBar?.hideWhenFull = false // Always show player health

                // Configure pathfinding for A* navigation around obstacles
                hermes.configurePathfinding(with: renderer)

                // Wire up death callback for tower destruction
                hermes.onDeathCallback = { [weak self] in
                    self?.handleHermesDeath()
                }

                addChild(hermes.sprite)
                print("GameScene: Spawned Hermes at \(spawnPos.x), \(spawnPos.y)")
            }
        } else {
            print("GameScene: No spawn point named 'Hermes' found in map")
        }

        // Select Nathaniel by default
        selectedCharacter = nathaniel

        // Position camera at Nathaniel (clamped to map bounds)
        if let nathaniel {
            clampCameraToMapBounds(targetPosition: nathaniel.position)
        }

        // Spawn test enemies
        spawnEnemies()
    }

    /// Spawn enemies based on level config (map-based or wave-based)
    private func spawnEnemies() {
        guard let nathaniel else { return }

        // Register player characters with enemy manager
        var players: [Character] = []
        if let nathanielChar = self.nathaniel { players.append(nathanielChar) }
        if let hermesChar = hermes { players.append(hermesChar) }
        enemyManager.playerCharacters = players

        // Set up weapon collision callback for Nathaniel's bullets to hit enemies
        nathaniel.weapon.onCheckCollision = enemyManager.createCollisionCallback()

        // Set up structure manager with player characters for heal tower
        structureManager.playerCharacters = players

        // Set up resource manager for resource drops
        ResourceManager.shared.scene = self
        ResourceManager.shared.collectors = players
        ResourceManager.shared.delegate = self

        // Spawn enemies based on spawn mode
        switch levelConfig.spawnMode {
        case .mapBased:
            // Spawn from map object layer
            spawnEnemiesFromMap()

        case .waveBased:
            // Set up wave spawner for survival-style levels
            setupWaveSpawner()
        }
    }

    /// Spawn enemies from map spawn points
    private func spawnEnemiesFromMap() {
        guard let renderer = mapRenderer else { return }

        // Get spawn objects from map
        let allObjects = renderer.getSpawnObjects()

        // Filter to enemy spawns and spawn them
        enemyManager.spawnFromMapObjects(allObjects, renderer: renderer)

        logger.info("Spawned enemies from map objects")
    }

    /// Set up wave spawner for survival-style levels
    private func setupWaveSpawner() {
        guard let renderer = mapRenderer else { return }

        waveSpawner = WaveSpawner()
        waveSpawner?.enemyManager = enemyManager
        waveSpawner?.mapWidth = CGFloat(renderer.map.pixelWidth)
        waveSpawner?.mapHeight = CGFloat(renderer.map.pixelHeight)

        // Set difficulty based on level
        if levelConfig.levelNumber == 5 { // Final level
            waveSpawner?.difficulty = .hard
        } else {
            waveSpawner?.difficulty = .normal
        }

        logger.info("Wave spawner set up for survival-style level")
    }

    /// Spawn test defensive structures for testing
    private func spawnTestStructures() {
        guard let nathaniel else { return }

        // Spawn a gun tower near Nathaniel
        structureManager.addGunTower(at: CGPoint(
            x: nathaniel.position.x + 150,
            y: nathaniel.position.y - 50
        ))

        // Spawn a heal tower nearby
        structureManager.addHealTower(at: CGPoint(
            x: nathaniel.position.x - 100,
            y: nathaniel.position.y + 50
        ))

        // Spawn a laser tower
        structureManager.addLaserTower(at: CGPoint(
            x: nathaniel.position.x + 100,
            y: nathaniel.position.y + 150
        ))

        print("GameScene: Spawned 3 test defensive structures")
    }

    private func setupDebugLabel() {
        debugLabel = SKLabelNode(fontNamed: "Menlo")
        debugLabel?.fontSize = 14
        debugLabel?.fontColor = .white
        debugLabel?.horizontalAlignmentMode = .left
        debugLabel?.verticalAlignmentMode = .top
        debugLabel?.position = CGPoint(x: -size.width / 2 + 10, y: size.height / 2 - 10)
        debugLabel?.zPosition = 1_000
        if let label = debugLabel {
            cameraNode.addChild(label)
        }
        updateDebugLabel()
    }

    private func showLoadError(_ message: String) {
        let errorLabel = SKLabelNode(fontNamed: "Helvetica")
        errorLabel.text = message
        errorLabel.fontSize = 24
        errorLabel.fontColor = .red
        errorLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(errorLabel)
    }

    private func updateDebugLabel() {
        guard let renderer = mapRenderer else {
            debugLabel?.text = "Map not loaded"
            return
        }

        var debugText = ""

        // Show game state
        debugText += "Lives: \(levelManager.lives) | Score: \(levelManager.score)\n"

        // Show selected character info
        if let selected = selectedCharacter {
            let pos = selected.position
            let tilePos = renderer.worldToTile(point: pos)
            let selectedMark = "[*]"
            debugText += "\(selectedMark) \(selected.name)\n"
            debugText += "Pos: (\(Int(pos.x)), \(Int(pos.y)))\n"
            debugText += "Tile: (\(tilePos.x), \(tilePos.y))\n"
            debugText += "HP: \(selected.currentHP)/\(selected.maxHP)\n"

            // Show Hermes-specific info
            if let hermes, selected === hermes {
                debugText += "Follow: \(!hermes.isInBuildMode)\n"
            }
        }

        // Show other character summary
        if let nathaniel, selectedCharacter !== nathaniel {
            debugText += "\nNathaniel: HP \(nathaniel.currentHP)/\(nathaniel.maxHP)"
        }
        if let hermes, selectedCharacter !== hermes {
            debugText += "\nHermes: HP \(hermes.currentHP)/\(hermes.maxHP)"
        }

        // Show enemy count
        let aliveEnemies = enemyManager.aliveCount
        if aliveEnemies > 0 {
            debugText += "\n\nEnemies: \(aliveEnemies)"
        }

        debugLabel?.text = debugText
        debugLabel?.numberOfLines = 0
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        // Calculate delta time
        let deltaTime: TimeInterval = if lastUpdateTime == 0 {
            0
        } else {
            currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime

        // Don't update game logic if not playing
        guard levelManager.state == .playing else {
            return
        }

        // Update level manager
        levelManager.update(deltaTime: deltaTime)

        // Update player characters
        nathaniel?.update(deltaTime: deltaTime)
        hermes?.update(deltaTime: deltaTime)

        // Update wave spawner for survival-style levels
        waveSpawner?.update(deltaTime: deltaTime)

        // Update enemies via manager
        enemyManager.update(deltaTime: deltaTime)

        // Update resources (collection, expiration)
        ResourceManager.shared.update(deltaTime: deltaTime)

        // Update defensive structures
        structureManager.update(deltaTime: deltaTime)

        // Update target indicator and check if target died
        updateTargetIndicator()

        // Update fog of war
        updateFogOfWar(currentTime: currentTime)

        // Camera follows selected character
        updateCameraFollow()

        // Update HUD
        updateHUD()

        // Update debug display (if enabled)
        if showDebugInfo {
            updateDebugLabel()
        }

        #if DEBUG
            // Update pathfinding visualization
            updatePathfindingDebugOverlay()
        #endif
    }

    // MARK: - HUD Update

    private func updateHUD() {
        // Update all HUD values from level manager and resource manager
        hud.update(
            lives: levelManager.lives,
            score: levelManager.score,
            resources: ResourceManager.shared.totalCollected,
            elapsedTime: levelManager.elapsedTime
        )

        // Update selected character info
        if let selected = selectedCharacter {
            hud.updateSelectedCharacter(
                name: selected.name,
                health: selected.currentHP,
                maxHealth: selected.maxHP
            )
        }

        // Update player health bars
        hud.updatePlayerHealth(
            nathanielHP: nathaniel?.currentHP ?? 0,
            nathanielMaxHP: nathaniel?.maxHP ?? 1,
            hermesHP: hermes?.currentHP ?? 0,
            hermesMaxHP: hermes?.maxHP ?? 1
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
        updateEnemyVisibility()
    }

    /// Update enemy sprite visibility based on fog of war
    private func updateEnemyVisibility() {
        guard let fog = fogOfWar else { return }

        for enemy in enemyManager.enemies {
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
        let shouldRespawn = levelManager.handlePlayerDeath()

        if shouldRespawn {
            // Schedule respawn after a brief delay
            let wait = SKAction.wait(forDuration: 2.0)
            let respawn = SKAction.run { [weak self] in
                self?.respawnNathaniel()
            }
            run(SKAction.sequence([wait, respawn]))
        }
    }

    /// Handle Hermes death - destroy towers without recoup
    private func handleHermesDeath() {
        // Destroy all Hermes towers immediately without recoup (penalty for death)
        if structureManager.hasHermesTowers {
            print("GameScene: Hermes died - destroying \(structureManager.hermesTowerCount) towers without recoup")
            structureManager.destroyAllHermesTowersImmediate()
        }

        // Unlock Hermes state (will be needed for respawn)
        hermes?.unlock()
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
        nathaniel.respawn(at: startPosition)

        // Update health bar
        nathaniel.updateHealthBar()

        // Set as selected character
        selectedCharacter = nathaniel

        // Re-register with enemy manager
        enemyManager.playerCharacters = [nathaniel]
        if let hermes, hermes.isAlive {
            enemyManager.playerCharacters.append(hermes)
        }

        // Update resource collectors
        ResourceManager.shared.collectors = enemyManager.playerCharacters

        logger.info("Nathaniel respawned at start position")
    }

    // MARK: - LevelManagerDelegate

    func levelManagerDidGameOver(_ manager: LevelManager) {
        logger.info("Game Over!")
        gameOverlay.showGameOver(score: manager.score, time: manager.elapsedTime)
    }

    func levelManagerDidWin(_ manager: LevelManager) {
        logger.info("Victory!")

        // Save progress for campaign levels (not survival mode)
        if levelConfig.levelNumber > 0 {
            GameSettings.shared.recordLevelCompletion(
                levelNumber: levelConfig.levelNumber,
                score: manager.score,
                time: manager.elapsedTime
            )
        }

        // Check if there's a next level
        let hasNextLevel = levelConfig.nextLevel != nil

        gameOverlay.showVictory(score: manager.score, time: manager.elapsedTime, hasNextLevel: hasNextLevel)
    }

    func levelManager(_ manager: LevelManager, didLoseLife remainingLives: Int) {
        logger.info("Life lost! Remaining: \(remainingLives)")
        gameOverlay.showLifeLost(remainingLives: remainingLives)
        hud.flashLifeLost()
    }

    func levelManager(_ manager: LevelManager, didUpdateScore newScore: Int) {
        hud.updateScore(newScore)
    }

    // MARK: - ResourceManagerDelegate

    func resourceManager(_ manager: ResourceManager, didUpdateTotal total: Int) {
        hud.updateResources(total)
    }

    func resourceManager(_ manager: ResourceManager, didCollectResource amount: Int) {
        hud.highlightResourceCollected(amount: amount)
    }

    // MARK: - TowerPlacementControllerDelegate

    func placementController(
        _ controller: TowerPlacementController,
        didPlaceTower type: TowerType,
        at position: CGPoint
    ) {
        // Lock Hermes in build mode
        hermes?.isInBuildMode = true

        // Update HUD with recoup preview
        hud.showReleaseHermesButton(recoupAmount: structureManager.potentialRecoupAmount)
        hud.updateTowerCount(structureManager.hermesTowerCount)

        // Update affordability
        towerPlacementController?.updateAffordability()

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
        case .outOfBuildRadius:
            logger.debug("Placement failed: out of build radius")
        case .blockedByTerrain:
            logger.debug("Placement failed: blocked by terrain")
        case .overlapsStructure:
            logger.debug("Placement failed: overlaps structure")
        case .overlapsCharacter:
            logger.debug("Placement failed: overlaps character")
        case .overlapsEnemy:
            logger.debug("Placement failed: overlaps enemy")
        }
    }

    // MARK: - StructureManagerDelegate

    func structureManager(
        _ manager: StructureManager,
        hermesTowerDestroyed remainingCount: Int,
        potentialRecoup: Int
    ) {
        // Update HUD when a Hermes tower is destroyed by enemies
        hud.updateTowerCount(remainingCount)
        hud.updateReleaseButtonRecoup(potentialRecoup)

        // Hide release button if all towers are destroyed
        if remainingCount == 0 {
            hud.hideReleaseHermesButton()
            hermes?.unlock()
        }
    }

    func placementController(_ controller: TowerPlacementController, didCancelPlacement type: TowerType) {
        logger.debug("Placement cancelled for \(type.displayName)")
    }

    /// Make the camera smoothly follow the selected character
    private func updateCameraFollow() {
        #if DEBUG
            // Skip camera following in free mode
            if DevSettings.shared.cameraFreeMode {
                return
            }

            // Apply zoom from dev settings if changed
            let targetZoom = DevSettings.shared.cameraZoom
            if abs(cameraZoom - targetZoom) > 0.01 {
                setZoom(targetZoom)
            }
        #endif

        // Skip if camera is animating (e.g., during character switch)
        guard !isCameraAnimating else { return }
        guard let selected = selectedCharacter, let renderer = mapRenderer else { return }

        // Target position is the selected character's position
        let targetPos = selected.position

        // Clamp to map bounds - use visible viewport size (not scene size) for correct clamping
        // This accounts for aspectFill scaling where visible area differs from scene size
        // When zoomed in (cameraZoom > 1), visible area is smaller so half dimensions decrease
        // When zoomed out (cameraZoom < 1), visible area is larger so half dimensions increase
        let effectiveViewport = visibleViewportSize.width > 0 ? visibleViewportSize : size
        let halfWidth = (effectiveViewport.width / 2) * cameraZoom
        let halfHeight = (effectiveViewport.height / 2) * cameraZoom

        let mapWidth = CGFloat(renderer.map.pixelWidth)
        let mapHeight = CGFloat(renderer.map.pixelHeight)

        var clampedPos = targetPos

        // Handle X clamping: if map is narrower than viewport, center on map
        if mapWidth <= halfWidth * 2 {
            clampedPos.x = mapWidth / 2
        } else {
            clampedPos.x = max(halfWidth, min(mapWidth - halfWidth, clampedPos.x))
        }

        // Handle Y clamping: if map is shorter than viewport, center on map
        if mapHeight <= halfHeight * 2 {
            clampedPos.y = mapHeight / 2
        } else {
            clampedPos.y = max(halfHeight, min(mapHeight - halfHeight, clampedPos.y))
        }

        // Smooth camera movement (lerp)
        #if DEBUG
            let smoothFactor = DevSettings.shared.cameraFollowSmoothing
        #else
            let smoothFactor: CGFloat = 0.1
        #endif
        let currentPos = cameraNode.position
        cameraNode.position = CGPoint(
            x: currentPos.x + (clampedPos.x - currentPos.x) * smoothFactor,
            y: currentPos.y + (clampedPos.y - currentPos.y) * smoothFactor
        )
    }

    /// Immediately clamp camera to map bounds (no smoothing)
    /// Use this for initial positioning or teleporting the camera
    private func clampCameraToMapBounds(targetPosition: CGPoint) {
        guard let renderer = mapRenderer else {
            cameraNode.position = targetPosition
            return
        }

        let effectiveViewport = visibleViewportSize.width > 0 ? visibleViewportSize : size
        let halfWidth = (effectiveViewport.width / 2) * cameraZoom
        let halfHeight = (effectiveViewport.height / 2) * cameraZoom

        let mapWidth = CGFloat(renderer.map.pixelWidth)
        let mapHeight = CGFloat(renderer.map.pixelHeight)

        var clampedPos = targetPosition

        // Handle X clamping: if map is narrower than viewport, center on map
        if mapWidth <= halfWidth * 2 {
            clampedPos.x = mapWidth / 2
        } else {
            clampedPos.x = max(halfWidth, min(mapWidth - halfWidth, clampedPos.x))
        }

        // Handle Y clamping: if map is shorter than viewport, center on map
        if mapHeight <= halfHeight * 2 {
            clampedPos.y = mapHeight / 2
        } else {
            clampedPos.y = max(halfHeight, min(mapHeight - halfHeight, clampedPos.y))
        }

        cameraNode.position = clampedPos
    }

    // MARK: - Camera Movement

    private func moveCamera(by delta: CGPoint) {
        guard let renderer = mapRenderer else { return }

        var newPos = cameraNode.position
        newPos.x += delta.x
        newPos.y += delta.y

        // Clamp to map bounds - use visible viewport size for correct clamping
        let effectiveViewport = visibleViewportSize.width > 0 ? visibleViewportSize : size
        let halfWidth = (effectiveViewport.width / 2) * cameraZoom
        let halfHeight = (effectiveViewport.height / 2) * cameraZoom

        let mapWidth = CGFloat(renderer.map.pixelWidth)
        let mapHeight = CGFloat(renderer.map.pixelHeight)

        // Handle X clamping: if map is narrower than viewport, center on map
        if mapWidth <= halfWidth * 2 {
            newPos.x = mapWidth / 2
        } else {
            newPos.x = max(halfWidth, min(mapWidth - halfWidth, newPos.x))
        }

        // Handle Y clamping: if map is shorter than viewport, center on map
        if mapHeight <= halfHeight * 2 {
            newPos.y = mapHeight / 2
        } else {
            newPos.y = max(halfHeight, min(mapHeight - halfHeight, newPos.y))
        }

        cameraNode.position = newPos
    }

    // MARK: - Camera Zoom

    /// Get effective min zoom (from DevSettings in DEBUG)
    private var effectiveMinZoom: CGFloat {
        #if DEBUG
            return DevSettings.shared.cameraMinZoom
        #else
            return minZoom
        #endif
    }

    /// Get effective max zoom (from DevSettings in DEBUG)
    private var effectiveMaxZoom: CGFloat {
        #if DEBUG
            return DevSettings.shared.cameraMaxZoom
        #else
            return maxZoom
        #endif
    }

    /// Update camera zoom by a scale factor
    /// - Parameter scale: Multiplier for current zoom (>1 zooms in, <1 zooms out)
    func updateZoom(by scale: CGFloat) {
        let newZoom = cameraZoom * scale
        cameraZoom = max(effectiveMinZoom, min(effectiveMaxZoom, newZoom))
        cameraNode.setScale(cameraZoom)
        updateUIScaleForZoom()
    }

    /// Set camera zoom to an absolute value
    /// - Parameter zoom: Target zoom level (clamped to min/max)
    func setZoom(_ zoom: CGFloat) {
        cameraZoom = max(effectiveMinZoom, min(effectiveMaxZoom, zoom))
        cameraNode.setScale(cameraZoom)
        updateUIScaleForZoom()
    }

    /// Handle pinch gesture zoom (called from iOS GameViewController)
    /// - Parameter scale: Gesture scale factor
    func handlePinchZoom(scale: CGFloat) {
        updateZoom(by: scale)
    }

    /// Keep HUD and overlay at consistent screen size when zooming
    private func updateUIScaleForZoom() {
        let inverseScale = 1.0 / cameraZoom
        hud?.setScale(inverseScale)
        gameOverlay?.setScale(inverseScale)
    }
}

// MARK: - iOS Touch Handling

#if os(iOS) || os(tvOS)
    extension GameScene {
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            let location = touch.location(in: self)

            // Check if save slot selector handles the touch (in HUD/camera space)
            let hudLocation = cameraNode.convert(location, from: self)
            if saveSlotSelector.isVisible {
                _ = saveSlotSelector.handleTouch(at: hudLocation)
                return
            }

            // Check if settings menu handles the touch (in HUD/camera space)
            if settingsMenu.isVisible {
                _ = settingsMenu.handleTouch(at: hudLocation)
                return
            }

            // Check if pause menu handles the touch (in HUD/camera space)
            if pauseMenu.isVisible {
                _ = pauseMenu.handleTouch(at: hudLocation)
                return
            }

            // Check if build menu handles the touch (in HUD/camera space)
            if let controller = towerPlacementController,
               controller.handleTouchBegan(at: hudLocation)
            {
                return
            }

            handleTap(at: location)
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            let location = touch.location(in: self)

            // Forward to build menu if dragging
            if let controller = towerPlacementController, controller.isDragging {
                // Placement indicator works in world space
                _ = controller.handleTouchMoved(to: location, in: self)
            }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            let location = touch.location(in: self)

            // Forward to build menu if dragging
            if let controller = towerPlacementController, controller.isDragging {
                _ = controller.handleTouchEnded(at: location)
            }
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            // Cancel any active build menu drag
            towerPlacementController?.handleTouchCancelled()
        }
    }
#endif

// MARK: - macOS Mouse/Keyboard Handling

#if os(OSX)
    extension GameScene {
        override func mouseDown(with event: NSEvent) {
            let location = event.location(in: self)

            // Check if save slot selector handles the click (in HUD/camera space)
            let hudLocation = cameraNode.convert(location, from: self)
            if saveSlotSelector.isVisible {
                _ = saveSlotSelector.handleTouch(at: hudLocation)
                return
            }

            // Check if settings menu handles the click (in HUD/camera space)
            if settingsMenu.isVisible {
                _ = settingsMenu.handleTouch(at: hudLocation)
                return
            }

            // Check if pause menu handles the click (in HUD/camera space)
            if pauseMenu.isVisible {
                _ = pauseMenu.handleTouch(at: hudLocation)
                return
            }

            handleTap(at: location)
        }

        override func mouseDragged(with event: NSEvent) {
            // Right-click drag to pan camera manually (optional)
        }

        override func mouseUp(with event: NSEvent) {}

        override func scrollWheel(with event: NSEvent) {
            // Use scroll delta for zoom - positive deltaY = scroll up = zoom in
            let zoomSensitivity: CGFloat = 0.02
            let zoomDelta = event.scrollingDeltaY * zoomSensitivity
            updateZoom(by: 1.0 + zoomDelta)
        }

        override func rightMouseDown(with event: NSEvent) {
            // Right-click to fire weapon at location
            let location = event.location(in: self)
            if let nathaniel {
                if nathaniel.fireAt(location) {
                    logger.debug("Fired at \(location.x), \(location.y)")
                }
            }
        }

        override func keyDown(with event: NSEvent) {
            // Escape key toggles pause (works in both playing and paused states)
            if event.keyCode == 53 { // Escape key
                if levelManager.state == .paused {
                    resumeGame()
                } else if levelManager.state == .playing {
                    pauseGame()
                }
                return
            }

            // Check if the overlay is showing (victory/game over)
            if gameOverlay.state == .victory || gameOverlay.state == .gameOver {
                gameOverlay.handleInteraction()
                return
            }

            // Don't handle other keys if game is not in playing state
            guard levelManager.state == .playing else { return }

            switch event.keyCode {
            case 1: // S key - stop movement
                selectedCharacter?.stop()
            case 3: // F key - fire weapon at mouse position
                fireAtMousePosition()
            case 15: // R key - toggle Hermes follow mode
                if let hermes {
                    hermes.isInBuildMode.toggle()
                    logger.debug("Hermes follow mode: \(!hermes.isInBuildMode)")
                }
            case 49: // Space key - switch selected character
                toggleSelectedCharacter()
            default:
                break
            }
        }

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
    }
#endif

// MARK: - Input Handling

extension GameScene {
    /// Handle tap/click - either select a character, target an enemy, or move the selected character
    func handleTap(at location: CGPoint) {
        // Check if the overlay is showing (victory/game over)
        if gameOverlay.state == .victory || gameOverlay.state == .gameOver {
            gameOverlay.handleInteraction()
            return
        }

        // Don't handle taps if game is not in playing state
        guard levelManager.state == .playing else { return }

        // Check if tap is on HUD elements (in camera/HUD coordinate space)
        let hudLocation = cameraNode.convert(location, from: self)
        if hud.handleTouch(at: hudLocation) {
            return
        }

        // Check if tapping on a character to select them
        if let nathaniel, nathaniel.contains(point: location) {
            selectCharacter(nathaniel)
            logger.debug("Selected Nathaniel")
            return
        }

        if let hermes, hermes.contains(point: location) {
            selectCharacter(hermes)
            logger.debug("Selected Hermes")
            return
        }

        // Check if tapping on an enemy to target them
        if let enemy = enemyAtPoint(location) {
            targetEnemy(enemy, tapLocation: location)
            return
        }

        // Otherwise, move the selected character to the location
        handleMoveCommand(to: location)
    }

    /// Select a character for control
    private func selectCharacter(_ character: Character) {
        // Hide previous selection visuals
        hermes?.hideSelectionHighlight()

        selectedCharacter = character

        // If selecting Hermes, show build button and put in independent control
        if let hermes, character === hermes {
            hermes.isInBuildMode = true // Stops following, allows independent control
            hermes.showSelectionHighlight() // Show build radius indicator
            hud.showBuildButton()
            hud.hideFollowModeButton() // Hide follow button when Hermes is selected

            // Update placement controller with Hermes reference
            towerPlacementController?.validator.hermes = hermes
            towerPlacementController?.updateAffordability()

            // Configure validator with current game state
            if let mapRenderer {
                var players: [Character] = []
                if let nathanielChar = nathaniel { players.append(nathanielChar) }
                players.append(hermes) // hermes is known non-nil here
                towerPlacementController?.configureValidator(
                    tmxRenderer: mapRenderer,
                    enemyManager: enemyManager,
                    playerCharacters: players
                )
            }
        } else {
            // Selecting Nathaniel - hide build button, menu, and Hermes visuals
            hud.hideBuildButton()
            towerPlacementController?.hideMenu()
            hermes?.hideSelectionHighlight()

            // Show follow mode button when Nathaniel is selected (to control Hermes)
            if let hermes {
                let isFollowing = hermes.mode == .following
                hud.showFollowModeButton(isFollowing: isFollowing)
            }
        }

        // Animate camera to new character position
        animateCameraTo(character.position)
    }

    /// Toggle between Nathaniel and Hermes
    func toggleSelectedCharacter() {
        if selectedCharacter === nathaniel {
            if let hermes {
                selectCharacter(hermes)
                logger.debug("Switched to Hermes")
            }
        } else {
            if let nathaniel {
                selectCharacter(nathaniel)
                logger.debug("Switched to Nathaniel")
            }
        }
    }

    /// Toggle Hermes between follow mode and independent mode
    func toggleHermesFollowMode() {
        guard let hermes else { return }

        // Can't toggle mode while locked (towers deployed)
        guard hermes.mode != .locked else {
            logger.debug("Cannot toggle follow mode while Hermes is locked")
            return
        }

        hermes.toggleMode()
        let isFollowing = hermes.mode == .following
        hud.updateFollowMode(isFollowing: isFollowing)
        logger.debug("Hermes follow mode: \(isFollowing)")
    }

    /// Animate camera to a target position with smooth easing
    private func animateCameraTo(_ position: CGPoint) {
        guard let renderer = mapRenderer else { return }

        // Mark as animating to prevent updateCameraFollow from interfering
        isCameraAnimating = true

        // Clamp target position to map bounds - use visible viewport size for correct clamping
        let effectiveViewport = visibleViewportSize.width > 0 ? visibleViewportSize : size
        let halfWidth = (effectiveViewport.width / 2) * cameraZoom
        let halfHeight = (effectiveViewport.height / 2) * cameraZoom

        let mapWidth = CGFloat(renderer.map.pixelWidth)
        let mapHeight = CGFloat(renderer.map.pixelHeight)

        var clampedPos = position

        // Handle X clamping: if map is narrower than viewport, center on map
        if mapWidth <= halfWidth * 2 {
            clampedPos.x = mapWidth / 2
        } else {
            clampedPos.x = max(halfWidth, min(mapWidth - halfWidth, clampedPos.x))
        }

        // Handle Y clamping: if map is shorter than viewport, center on map
        if mapHeight <= halfHeight * 2 {
            clampedPos.y = mapHeight / 2
        } else {
            clampedPos.y = max(halfHeight, min(mapHeight - halfHeight, clampedPos.y))
        }

        // Animate to the clamped position
        let moveAction = SKAction.move(to: clampedPos, duration: 0.3)
        moveAction.timingMode = .easeInEaseOut

        cameraNode.run(moveAction) { [weak self] in
            self?.isCameraAnimating = false
        }
    }

    /// Release Hermes from build mode - destroy all towers and allow movement
    private func releaseHermes() {
        guard let hermes else { return }

        logger.info("Releasing Hermes - destroying all towers with visual effects")

        // Hide UI elements immediately
        hud.hideReleaseHermesButton()
        hud.updateTowerCount(0)
        towerPlacementController?.hideMenu()

        // Destroy all Hermes-owned towers with staggered visual effects
        structureManager?.destroyAllHermesTowers(camera: cameraNode) { [weak self, weak hermes] in
            guard let hermes else { return }

            // Unlock Hermes to allow movement after destruction completes
            hermes.unlock()

            // Exit build mode (allow following again)
            hermes.exitBuildMode()

            print("Tower destruction complete - Hermes unlocked")
        }
    }

    /// Handle a move command to a world position
    func handleMoveCommand(to location: CGPoint) {
        guard let selected = selectedCharacter else { return }

        // Check if the destination is walkable
        if let renderer = mapRenderer {
            let tile = renderer.worldToTile(point: location)
            if !renderer.isWalkable(tileX: tile.x, tileY: tile.y) {
                logger.debug("Destination not walkable: tile (\(tile.x), \(tile.y))")
                // Still allow movement toward the location - pathfinding will handle obstacles
            }
        }

        selected.moveTo(location)
        logger.debug("Moving \(selected.name) to \(location.x), \(location.y)")
    }

    // MARK: - Enemy Targeting

    /// Find an enemy at the given point (with expanded hit area for easier targeting)
    private func enemyAtPoint(_ point: CGPoint) -> Enemy? {
        // Use 1.5x sprite size for easier touch targeting
        let hitAreaMultiplier: CGFloat = 1.5

        for enemy in enemyManager.enemies {
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

    /// Target an enemy - sets Nathaniel's target and shows indicator
    private func targetEnemy(_ enemy: Enemy, tapLocation: CGPoint) {
        guard let nathaniel else { return }

        // Only allow targeting enemies that are currently visible (not in fog of war)
        if let fog = fogOfWar, !fog.isVisible(at: enemy.position) {
            logger.debug("Cannot target enemy - not visible in fog of war")
            return
        }

        // Set as Nathaniel's target for auto-attack
        nathaniel.target = enemy

        // Remove existing indicator
        targetIndicator?.remove()

        // Create new indicator
        targetIndicator = TargetIndicator.create(for: enemy.sprite, in: self)

        // Play feedback
        playTargetFeedback(at: tapLocation)

        logger.debug("Targeted enemy at (\(enemy.position.x), \(enemy.position.y))")
    }

    /// Clear the current target (called when enemy dies)
    private func clearTarget() {
        nathaniel?.target = nil
        targetIndicator?.remove()
        targetIndicator = nil
    }

    /// Play haptic and visual feedback when targeting
    private func playTargetFeedback(at location: CGPoint) {
        // Haptic feedback (iOS only)
        #if os(iOS)
            hapticGenerator?.impactOccurred()
        #endif

        // Visual ripple effect
        showTapRipple(at: location)
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
