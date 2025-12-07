import Foundation
import SpriteKit

enum SmokeTestRunner {
    private static let argument = "--smoke-test"
    private static let envVar = "NATHANIEL_SMOKE_TEST"

    static var isEnabled: Bool {
        if ProcessInfo.processInfo.arguments.contains(argument) { return true }
        return ProcessInfo.processInfo.environment[envVar] == "1"
    }

    static func run() throws {
        try requireBundleResource(name: "levelone", extension: "tmx")
        try requireBundleResource(name: "menuMusic", extension: "mp3")
        try requireBundleResource(name: "gameMusic", extension: "mp3")

        try requireTexture(name: "nathanielspritesheet")
        try requireTexture(name: "hermesidlespritesheet")
        try requireTexture(name: "tileset1")

        let parser = TMXParser()
        guard let map = parser.parse(filename: "levelone") else {
            throw SmokeTestError("TMXParser failed to parse levelone.tmx")
        }

        guard map.width > 0, map.height > 0, map.tileWidth > 0, map.tileHeight > 0 else {
            throw SmokeTestError("Parsed map has invalid dimensions: \(map.width)x\(map.height) tiles, tileSize \(map.tileWidth)x\(map.tileHeight)")
        }

        guard !map.layers.isEmpty else {
            throw SmokeTestError("Parsed map has no layers")
        }

        guard !map.tilesets.isEmpty else {
            throw SmokeTestError("Parsed map has no tilesets")
        }

        let renderer = TMXRenderer(map: map)
        renderer.loadTilesets()

        for tileset in map.tilesets {
            guard let texture = tileset.texture else {
                throw SmokeTestError("Tileset texture missing for '\(tileset.name)' (\(tileset.imageSource))")
            }

            let size = texture.size()
            guard size.width > 0, size.height > 0 else {
                throw SmokeTestError("Tileset texture is empty for '\(tileset.name)' (\(tileset.imageSource))")
            }
        }

        let mapNode = renderer.createMapNode()
        guard !mapNode.children.isEmpty else {
            throw SmokeTestError("Renderer produced an empty map node")
        }
    }

    static func runForProcessExit() -> Int32 {
        do {
            try run()
            print("SMOKE_TEST_PASS")
            return 0
        } catch {
            print("SMOKE_TEST_FAIL: \(error.localizedDescription)")
            return 1
        }
    }

    private static func requireBundleResource(name: String, extension ext: String) throws {
        guard Bundle.main.url(forResource: name, withExtension: ext) != nil else {
            throw SmokeTestError("Missing bundle resource: \(name).\(ext)")
        }
    }

    private static func requireTexture(name: String) throws {
        let texture = SKTexture(imageNamed: name)
        let size = texture.size()
        guard size.width > 0, size.height > 0 else {
            throw SmokeTestError("Missing or empty texture: \(name)")
        }
    }
}

struct SmokeTestError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
