//
//  GameScene.swift
//  Nathaniel Shared
//
//  Created by Ruairi O'Brien on 11/29/25.
//

import SpriteKit
import os.log

private let logger = Logger(subsystem: "com.ruarfff.Nathaniel", category: "GameScene")

class GameScene: SKScene, LevelManagerDelegate {

    // MARK: - Properties

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

    /// Level manager for game state
    private var levelManager: LevelManager!

    /// Game overlay for victory/game over screens
    private var gameOverlay: GameOverlay!

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

    // MARK: - Scene Setup

    class func newGameScene() -> GameScene {
        // Load 'GameScene.sks' as an SKScene.
        guard let scene = SKScene(fileNamed: "GameScene") as? GameScene else {
            print("Failed to load GameScene.sks")
            abort()
        }

        // Set the scale mode to scale to fit the window
        scene.scaleMode = .aspectFill

        return scene
    }

    override func didMove(to view: SKView) {
        setupCamera()
        setupLevelManager()
        setupEnemyManager()
        setupOverlay()
        setupHUD()
        loadMap()
        spawnCharacters()
        if showDebugInfo {
            setupDebugLabel()
        }
    }

    private func setupLevelManager() {
        levelManager = LevelManager(config: .levelOne)
        levelManager.delegate = self
    }

    private func setupEnemyManager() {
        enemyManager = EnemyManager(scene: self)
        enemyManager.enemyZPosition = characterZPosition
        enemyManager.enemyScale = 3.0
        enemyManager.delegate = levelManager
        levelManager.enemyManager = enemyManager
    }

    private func setupOverlay() {
        gameOverlay = GameOverlay(size: size)
        gameOverlay.zPosition = 1000
        cameraNode.addChild(gameOverlay)
    }

    private func setupHUD() {
        // Calculate visible area based on view aspect ratio and scene scale mode
        // With .aspectFill, the scene is scaled to fill the view, potentially cropping edges
        let hudSize: CGSize
        if let view = self.view {
            let viewAspect = view.bounds.width / view.bounds.height
            let sceneAspect = size.width / size.height

            if viewAspect > sceneAspect {
                // View is wider than scene - scene height is cropped
                let visibleWidth = size.width
                let visibleHeight = size.width / viewAspect
                hudSize = CGSize(width: visibleWidth, height: visibleHeight)
            } else {
                // View is taller than scene - scene width is cropped
                let visibleHeight = size.height
                let visibleWidth = size.height * viewAspect
                hudSize = CGSize(width: visibleWidth, height: visibleHeight)
            }
            print("HUD: view=\(view.bounds.size), scene=\(size), visible=\(hudSize)")
        } else {
            hudSize = size
        }

        hud = HUD(size: hudSize)
        hud.zPosition = 500
        cameraNode.addChild(hud)

        // Initialize with starting values
        hud.update(
            lives: levelManager.lives,
            score: levelManager.score,
            resources: levelManager.resources,
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
        logger.info("loadMap() called")
        let parser = TMXParser()

        // Try to load the map from the bundle
        // The Assets folder should be added to the Xcode project
        guard let mapURL = Bundle.main.url(forResource: "levelone", withExtension: "tmx") else {
            logger.error("Could not find levelone.tmx in bundle")
            showLoadError("Could not find levelone.tmx")
            return
        }

        logger.info("Found map at: \(mapURL.path)")

        guard let map = parser.parse(url: mapURL) else {
            logger.error("Failed to parse map")
            showLoadError("Failed to parse map")
            return
        }

        logger.info("Loaded map \(map.width)x\(map.height) tiles, \(map.pixelWidth)x\(map.pixelHeight) pixels")
        logger.info("\(map.tilesets.count) tilesets, \(map.layers.count) layers, \(map.objectGroups.count) object groups")

        // Log tileset info
        for tileset in map.tilesets {
            logger.info("Tileset: \(tileset.name), firstGid: \(tileset.firstGid), image: \(tileset.imageSource), size: \(tileset.imageWidth)x\(tileset.imageHeight)")
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
        if let mapNode = mapNode {
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
            if let nathaniel = nathaniel {
                nathaniel.position = spawnPos
                nathaniel.sprite.zPosition = characterZPosition
                nathaniel.sprite.setScale(3.0)
                addChild(nathaniel.sprite)

                // Set up health bar (scaled for the 3x sprite size)
                nathaniel.setupHealthBar(width: 40, yOffset: 8)
                nathaniel.healthBar?.hideWhenFull = false  // Always show player health

                // Wire up weapon callbacks
                nathaniel.weapon.onFire = { [weak self] projectile in
                    guard let self = self else { return }
                    projectile.sprite.setScale(2.0)
                    self.addChild(projectile.sprite)
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
            if let hermes = hermes {
                hermes.position = spawnPos
                hermes.sprite.zPosition = characterZPosition
                hermes.sprite.setScale(3.0)

                // Set Hermes to follow Nathaniel
                hermes.followTarget = nathaniel
                hermes.isInBuildMode = false  // Start following

                // Set up health bar
                hermes.setupHealthBar(width: 40, yOffset: 8)
                hermes.healthBar?.hideWhenFull = false  // Always show player health

                addChild(hermes.sprite)
                print("GameScene: Spawned Hermes at \(spawnPos.x), \(spawnPos.y)")
            }
        } else {
            print("GameScene: No spawn point named 'Hermes' found in map")
        }

        // Select Nathaniel by default
        selectedCharacter = nathaniel

        // Position camera at Nathaniel
        if let nathaniel = nathaniel {
            cameraNode.position = nathaniel.position
        }

        // Spawn test enemies
        spawnEnemies()
    }

    /// Spawn enemies from map objects or for testing
    private func spawnEnemies() {
        guard let nathaniel = nathaniel else { return }

        // Register player characters with enemy manager
        var players: [Character] = []
        if let n = self.nathaniel { players.append(n) }
        if let h = self.hermes { players.append(h) }
        enemyManager.playerCharacters = players

        // For testing: Spawn a grunt near Nathaniel
        enemyManager.addEnemy(
            name: "Grunt1",
            at: CGPoint(x: nathaniel.position.x + 300, y: nathaniel.position.y + 100),
            target: nathaniel
        )

        // For testing: Spawn a soldier nearby (within visible range)
        enemyManager.addEnemy(
            name: "Soldier1",
            at: CGPoint(x: nathaniel.position.x + 200, y: nathaniel.position.y + 200),
            target: nathaniel
        )

        // For testing: Spawn a boss further away
        enemyManager.addEnemy(
            name: "Boss1",
            at: CGPoint(x: nathaniel.position.x + 400, y: nathaniel.position.y - 100),
            target: nathaniel
        )

        // Set up weapon collision callback for Nathaniel's bullets to hit enemies
        nathaniel.weapon.onCheckCollision = enemyManager.createCollisionCallback()
    }

    private func setupDebugLabel() {
        debugLabel = SKLabelNode(fontNamed: "Menlo")
        debugLabel?.fontSize = 14
        debugLabel?.fontColor = .white
        debugLabel?.horizontalAlignmentMode = .left
        debugLabel?.verticalAlignmentMode = .top
        debugLabel?.position = CGPoint(x: -size.width/2 + 10, y: size.height/2 - 10)
        debugLabel?.zPosition = 1000
        cameraNode.addChild(debugLabel!)
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
            if let hermes = hermes, selected === hermes {
                debugText += "Follow: \(!hermes.isInBuildMode)\n"
            }
        }

        // Show other character summary
        if let nathaniel = nathaniel, selectedCharacter !== nathaniel {
            debugText += "\nNathaniel: HP \(nathaniel.currentHP)/\(nathaniel.maxHP)"
        }
        if let hermes = hermes, selectedCharacter !== hermes {
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
        let deltaTime: TimeInterval
        if lastUpdateTime == 0 {
            deltaTime = 0
        } else {
            deltaTime = currentTime - lastUpdateTime
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

        // Update enemies via manager
        enemyManager.update(deltaTime: deltaTime)

        // Camera follows selected character
        updateCameraFollow()

        // Update HUD
        updateHUD()

        // Update debug display (if enabled)
        if showDebugInfo {
            updateDebugLabel()
        }
    }

    // MARK: - HUD Update

    private func updateHUD() {
        // Update all HUD values from level manager
        hud.update(
            lives: levelManager.lives,
            score: levelManager.score,
            resources: levelManager.resources,
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

    /// Respawn Nathaniel at start position
    private func respawnNathaniel() {
        guard let nathaniel = nathaniel else { return }

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
        if let hermes = hermes, hermes.isAlive {
            enemyManager.playerCharacters.append(hermes)
        }

        logger.info("Nathaniel respawned at start position")
    }

    // MARK: - LevelManagerDelegate

    func levelManagerDidGameOver(_ manager: LevelManager) {
        logger.info("Game Over!")
        gameOverlay.showGameOver(score: manager.score, time: manager.elapsedTime)
    }

    func levelManagerDidWin(_ manager: LevelManager) {
        logger.info("Victory!")
        gameOverlay.showVictory(score: manager.score, time: manager.elapsedTime)
    }

    func levelManager(_ manager: LevelManager, didLoseLife remainingLives: Int) {
        logger.info("Life lost! Remaining: \(remainingLives)")
        gameOverlay.showLifeLost(remainingLives: remainingLives)
        hud.flashLifeLost()
    }

    func levelManager(_ manager: LevelManager, didUpdateScore newScore: Int) {
        hud.updateScore(newScore)
    }

    /// Make the camera smoothly follow the selected character
    private func updateCameraFollow() {
        guard let selected = selectedCharacter, let renderer = mapRenderer else { return }

        // Target position is the selected character's position
        let targetPos = selected.position

        // Clamp to map bounds
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2

        var clampedPos = targetPos
        clampedPos.x = max(halfWidth, min(CGFloat(renderer.map.pixelWidth) - halfWidth, clampedPos.x))
        clampedPos.y = max(halfHeight, min(CGFloat(renderer.map.pixelHeight) - halfHeight, clampedPos.y))

        // Smooth camera movement (lerp)
        let smoothFactor: CGFloat = 0.1
        let currentPos = cameraNode.position
        cameraNode.position = CGPoint(
            x: currentPos.x + (clampedPos.x - currentPos.x) * smoothFactor,
            y: currentPos.y + (clampedPos.y - currentPos.y) * smoothFactor
        )
    }

    // MARK: - Camera Movement

    private func moveCamera(by delta: CGPoint) {
        guard let renderer = mapRenderer else { return }

        var newPos = cameraNode.position
        newPos.x += delta.x
        newPos.y += delta.y

        // Clamp to map bounds
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2

        newPos.x = max(halfWidth, min(CGFloat(renderer.map.pixelWidth) - halfWidth, newPos.x))
        newPos.y = max(halfHeight, min(CGFloat(renderer.map.pixelHeight) - halfHeight, newPos.y))

        cameraNode.position = newPos
    }
}

// MARK: - iOS Touch Handling

#if os(iOS) || os(tvOS)
extension GameScene {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        handleTap(at: location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Two-finger drag to pan camera (optional, for when we want manual camera control)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    }
}
#endif

// MARK: - macOS Mouse/Keyboard Handling

#if os(OSX)
extension GameScene {

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        handleTap(at: location)
    }

    override func mouseDragged(with event: NSEvent) {
        // Right-click drag to pan camera manually (optional)
    }

    override func mouseUp(with event: NSEvent) {
    }

    override func rightMouseDown(with event: NSEvent) {
        // Right-click to fire weapon at location
        let location = event.location(in: self)
        if let nathaniel = nathaniel {
            if nathaniel.fireAt(location) {
                logger.debug("Fired at \(location.x), \(location.y)")
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 1: // S key - stop movement
            selectedCharacter?.stop()
        case 3: // F key - fire weapon at mouse position
            fireAtMousePosition()
        case 15: // R key - toggle Hermes follow mode
            if let hermes = hermes {
                hermes.isInBuildMode = !hermes.isInBuildMode
                logger.debug("Hermes follow mode: \(!hermes.isInBuildMode)")
            }
        case 49: // Space key - switch selected character
            if selectedCharacter === nathaniel {
                if let hermes = hermes {
                    selectCharacter(hermes)
                    logger.debug("Switched to Hermes")
                }
            } else {
                if let nathaniel = nathaniel {
                    selectCharacter(nathaniel)
                    logger.debug("Switched to Nathaniel")
                }
            }
        default:
            break
        }
    }

    /// Fire Nathaniel's weapon at the current mouse position
    private func fireAtMousePosition() {
        guard let view = self.view,
              let nathaniel = nathaniel else { return }

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

    /// Handle tap/click - either select a character or move the selected character
    func handleTap(at location: CGPoint) {
        // Check if tapping on a character to select them
        if let nathaniel = nathaniel, nathaniel.contains(point: location) {
            selectCharacter(nathaniel)
            logger.debug("Selected Nathaniel")
            return
        }

        if let hermes = hermes, hermes.contains(point: location) {
            selectCharacter(hermes)
            logger.debug("Selected Hermes")
            return
        }

        // Otherwise, move the selected character to the location
        handleMoveCommand(to: location)
    }

    /// Select a character for control
    private func selectCharacter(_ character: Character) {
        selectedCharacter = character

        // If selecting Hermes, put them in independent control mode
        if let hermes = hermes, character === hermes {
            hermes.isInBuildMode = true  // Stops following, allows independent control
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
}
