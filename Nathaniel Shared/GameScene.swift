//
//  GameScene.swift
//  Nathaniel Shared
//
//  Created by Ruairi O'Brien on 11/29/25.
//

import SpriteKit

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
        let parser = TMXParser()

        // Try to load the map from the bundle
        // The Assets folder should be added to the Xcode project
        guard let mapURL = Bundle.main.url(forResource: "levelone", withExtension: "tmx") else {
            print("GameScene: Could not find levelone.tmx in bundle")
            showLoadError("Could not find levelone.tmx")
            return
        }

        guard let map = parser.parse(url: mapURL) else {
            print("GameScene: Failed to parse map")
            showLoadError("Failed to parse map")
            return
        }

        print("GameScene: Loaded map \(map.width)x\(map.height) tiles, \(map.pixelWidth)x\(map.pixelHeight) pixels")
        print("GameScene: \(map.tilesets.count) tilesets, \(map.layers.count) layers, \(map.objectGroups.count) object groups")

        // Create renderer and load tilesets
        mapRenderer = TMXRenderer(map: map)
        mapRenderer?.loadTilesets()

        // Create and add map node
        mapNode = mapRenderer?.createMapNode()
        if let mapNode = mapNode {
            addChild(mapNode)
            print("GameScene: Map node added with \(mapNode.children.count) layer nodes")
        }

        // Position camera at Nathaniel's spawn point
        if let nathanielSpawn = mapRenderer?.getSpawnObjects().first(where: { $0.name == "Nathaniel" }) {
            let spawnPos = mapRenderer?.convertToSpriteKit(point: nathanielSpawn.center) ?? CGPoint.zero
            cameraNode.position = spawnPos
            print("GameScene: Camera positioned at Nathaniel spawn: \(spawnPos)")
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

        let camPos = cameraNode.position
        let tilePos = renderer.worldToTile(point: camPos)
        let walkable = renderer.isWalkable(tileX: tilePos.x, tileY: tilePos.y)

        debugLabel?.text = """
        Camera: (\(Int(camPos.x)), \(Int(camPos.y)))
        Tile: (\(tilePos.x), \(tilePos.y))
        Walkable: \(walkable)
        """
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        updateDebugLabel()
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
        // Future: Handle tap to move character
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Pan camera with touch drag
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let previousLocation = touch.previousLocation(in: self)
        let delta = CGPoint(x: previousLocation.x - location.x, y: previousLocation.y - location.y)
        moveCamera(by: delta)
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
        // Future: Handle click to move character
        let location = event.location(in: self)
        print("Click at: \(location)")

        if let renderer = mapRenderer {
            let tile = renderer.worldToTile(point: location)
            let walkable = renderer.isWalkable(tileX: tile.x, tileY: tile.y)
            print("  Tile: (\(tile.x), \(tile.y)), Walkable: \(walkable)")
        }
    }

    override func mouseDragged(with event: NSEvent) {
        // Pan camera with mouse drag
        let delta = CGPoint(x: -event.deltaX, y: event.deltaY)
        moveCamera(by: delta)
    }

    override func mouseUp(with event: NSEvent) {
    }

    override func keyDown(with event: NSEvent) {
        // Arrow keys for camera movement
        let moveSpeed: CGFloat = 32

        switch event.keyCode {
        case 123: // Left arrow
            moveCamera(by: CGPoint(x: -moveSpeed, y: 0))
        case 124: // Right arrow
            moveCamera(by: CGPoint(x: moveSpeed, y: 0))
        case 125: // Down arrow
            moveCamera(by: CGPoint(x: 0, y: -moveSpeed))
        case 126: // Up arrow
            moveCamera(by: CGPoint(x: 0, y: moveSpeed))
        default:
            break
        }
    }
}
#endif
