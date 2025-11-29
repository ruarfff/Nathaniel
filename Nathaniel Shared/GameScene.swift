//
//  GameScene.swift
//  Nathaniel Shared
//
//  Created by Ruairi O'Brien on 11/29/25.
//

import SpriteKit
import os.log

private let logger = Logger(subsystem: "com.ruarfff.Nathaniel", category: "GameScene")

class GameScene: SKScene {

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
        loadMap()
        spawnNathaniel()
        setupDebugLabel()
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

    /// Spawn Nathaniel at his designated spawn point
    private func spawnNathaniel() {
        guard let renderer = mapRenderer else {
            print("GameScene: Cannot spawn Nathaniel - map not loaded")
            return
        }

        // Find Nathaniel's spawn point in the map
        let allObjects = renderer.getSpawnObjects()
        print("GameScene: Found \(allObjects.count) spawn objects")
        for obj in allObjects {
            print("GameScene: Object '\(obj.name)' type='\(obj.type)' at (\(obj.x), \(obj.y))")
        }

        guard let spawnObject = allObjects.first(where: { $0.name == "Nathaniel" }) else {
            print("GameScene: No spawn point named 'Nathaniel' found in map")
            return
        }

        print("GameScene: Found Nathaniel spawn at TMX coords: (\(spawnObject.center.x), \(spawnObject.center.y))")

        let spawnPos = renderer.convertToSpriteKit(point: spawnObject.center)
        print("GameScene: Converted to SpriteKit coords: (\(spawnPos.x), \(spawnPos.y))")

        // Create and configure Nathaniel
        nathaniel = Nathaniel()
        guard let nathaniel = nathaniel else { return }

        nathaniel.position = spawnPos
        nathaniel.sprite.zPosition = characterZPosition

        // Scale up the sprite to make it more visible (original is tiny ~25x35)
        nathaniel.sprite.setScale(3.0)

        print("GameScene: Nathaniel sprite size: \(nathaniel.sprite.size)")
        print("GameScene: Nathaniel sprite xScale: \(nathaniel.sprite.xScale), yScale: \(nathaniel.sprite.yScale)")
        print("GameScene: Nathaniel sprite texture: \(String(describing: nathaniel.sprite.texture))")

        // Add to scene
        addChild(nathaniel.sprite)


        // Position camera at Nathaniel
        cameraNode.position = spawnPos

        print("GameScene: Spawned Nathaniel at \(spawnPos.x), \(spawnPos.y)")
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

        if let nathaniel = nathaniel {
            let pos = nathaniel.position
            let tilePos = renderer.worldToTile(point: pos)
            debugText += "Nathaniel: (\(Int(pos.x)), \(Int(pos.y)))\n"
            debugText += "Tile: (\(tilePos.x), \(tilePos.y))\n"
            debugText += "HP: \(nathaniel.currentHP)/\(nathaniel.maxHP)\n"
            debugText += "Moving: \(nathaniel.isMoving)\n"
            debugText += "Facing: \(nathaniel.facingDirection)"
        } else {
            let camPos = cameraNode.position
            let tilePos = renderer.worldToTile(point: camPos)
            debugText = "Camera: (\(Int(camPos.x)), \(Int(camPos.y)))\nTile: (\(tilePos.x), \(tilePos.y))"
        }

        debugLabel?.text = debugText
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

        // Update Nathaniel
        nathaniel?.update(deltaTime: deltaTime)

        // Camera follows Nathaniel
        updateCameraFollow()

        // Update debug display
        updateDebugLabel()
    }

    /// Make the camera smoothly follow Nathaniel
    private func updateCameraFollow() {
        guard let nathaniel = nathaniel, let renderer = mapRenderer else { return }

        // Target position is Nathaniel's position
        let targetPos = nathaniel.position

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
        handleMoveCommand(to: location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Two-finger drag to pan camera (optional, for when we want manual camera control)
        // For now, single finger just updates move destination
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
        handleMoveCommand(to: location)
    }

    override func mouseDragged(with event: NSEvent) {
        // Right-click drag to pan camera manually (optional)
    }

    override func mouseUp(with event: NSEvent) {
    }

    override func keyDown(with event: NSEvent) {
        // S key to stop movement
        if event.keyCode == 1 { // S key
            nathaniel?.stop()
        }
    }
}
#endif

// MARK: - Movement Commands

extension GameScene {

    /// Handle a move command to a world position
    func handleMoveCommand(to location: CGPoint) {
        guard let nathaniel = nathaniel else { return }

        // Check if the destination is walkable
        if let renderer = mapRenderer {
            let tile = renderer.worldToTile(point: location)
            if !renderer.isWalkable(tileX: tile.x, tileY: tile.y) {
                logger.debug("Destination not walkable: tile (\(tile.x), \(tile.y))")
                // Still allow movement toward the location - pathfinding will handle obstacles
                // For now, just move directly (pathfinding will be added later)
            }
        }

        nathaniel.moveTo(location)
        logger.debug("Moving Nathaniel to \(location.x), \(location.y)")
    }
}
