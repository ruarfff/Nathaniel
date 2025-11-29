import Foundation
import SpriteKit
import Compression

/// Represents a parsed Tiled map
class TMXMap {
    let width: Int
    let height: Int
    let tileWidth: Int
    let tileHeight: Int
    var tilesets: [TMXTileset] = []
    var layers: [TMXLayer] = []
    var objectGroups: [TMXObjectGroup] = []

    /// Map size in pixels
    var pixelWidth: Int { width * tileWidth }
    var pixelHeight: Int { height * tileHeight }

    init(width: Int, height: Int, tileWidth: Int, tileHeight: Int) {
        self.width = width
        self.height = height
        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
    }
}

/// Represents a tileset (image containing tiles)
class TMXTileset {
    let firstGid: Int
    let name: String
    let tileWidth: Int
    let tileHeight: Int
    let imageSource: String
    let imageWidth: Int
    let imageHeight: Int
    var texture: SKTexture?

    /// Number of columns in the tileset image
    var columns: Int { imageWidth / tileWidth }
    var rows: Int { imageHeight / tileHeight }

    init(firstGid: Int, name: String, tileWidth: Int, tileHeight: Int,
         imageSource: String, imageWidth: Int, imageHeight: Int) {
        self.firstGid = firstGid
        self.name = name
        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
        self.imageSource = imageSource
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }

    /// Get texture rect for a global tile ID
    func textureRect(for gid: Int) -> CGRect? {
        let localId = gid - firstGid
        guard localId >= 0 && localId < columns * rows else { return nil }

        let col = localId % columns
        let row = localId / columns

        // SpriteKit textures have origin at bottom-left, Tiled at top-left
        let x = CGFloat(col * tileWidth) / CGFloat(imageWidth)
        let y = 1.0 - CGFloat((row + 1) * tileHeight) / CGFloat(imageHeight)
        let w = CGFloat(tileWidth) / CGFloat(imageWidth)
        let h = CGFloat(tileHeight) / CGFloat(imageHeight)

        return CGRect(x: x, y: y, width: w, height: h)
    }
}

/// Represents a tile layer
class TMXLayer {
    let name: String
    let width: Int
    let height: Int
    var tiles: [Int] = [] // Global tile IDs (0 = empty)

    init(name: String, width: Int, height: Int) {
        self.name = name
        self.width = width
        self.height = height
    }

    /// Get tile at grid position
    func tile(at x: Int, y: Int) -> Int {
        guard x >= 0 && x < width && y >= 0 && y < height else { return 0 }
        return tiles[y * width + x]
    }

    /// Check if tile at position is solid (non-empty)
    func isSolid(at x: Int, y: Int) -> Bool {
        return tile(at: x, y: y) != 0
    }
}

/// Represents a map object (spawn point, trigger, etc.)
class TMXObject {
    let name: String
    let type: String
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    /// Center position of the object
    var center: CGPoint {
        CGPoint(x: x + width / 2, y: y + height / 2)
    }

    init(name: String, type: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.name = name
        self.type = type
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Represents an object group/layer
class TMXObjectGroup {
    let name: String
    var objects: [TMXObject] = []

    init(name: String) {
        self.name = name
    }

    /// Find objects by type
    func objects(ofType type: String) -> [TMXObject] {
        objects.filter { $0.type == type }
    }

    /// Find object by name
    func object(named name: String) -> TMXObject? {
        objects.first { $0.name == name }
    }
}

/// Parser for Tiled TMX map files
class TMXParser: NSObject, XMLParserDelegate {
    private var map: TMXMap?
    private var currentTileset: TMXTileset?
    private var currentLayer: TMXLayer?
    private var currentObjectGroup: TMXObjectGroup?
    private var currentElement: String = ""
    private var currentData: String = ""

    /// Parse a TMX file from the app bundle
    func parse(filename: String) -> TMXMap? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "tmx") else {
            print("TMXParser: Could not find \(filename).tmx in bundle")
            return nil
        }
        return parse(url: url)
    }

    /// Parse a TMX file from a URL
    func parse(url: URL) -> TMXMap? {
        guard let parser = XMLParser(contentsOf: url) else {
            print("TMXParser: Could not create parser for \(url)")
            return nil
        }

        parser.delegate = self
        map = nil

        if parser.parse() {
            return map
        } else {
            print("TMXParser: Parse error - \(parser.parserError?.localizedDescription ?? "unknown")")
            return nil
        }
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        currentElement = elementName

        switch elementName {
        case "map":
            let width = Int(attributes["width"] ?? "0") ?? 0
            let height = Int(attributes["height"] ?? "0") ?? 0
            let tileWidth = Int(attributes["tilewidth"] ?? "0") ?? 0
            let tileHeight = Int(attributes["tileheight"] ?? "0") ?? 0
            map = TMXMap(width: width, height: height, tileWidth: tileWidth, tileHeight: tileHeight)

        case "tileset":
            let firstGid = Int(attributes["firstgid"] ?? "1") ?? 1
            let name = attributes["name"] ?? ""
            let tileWidth = Int(attributes["tilewidth"] ?? "32") ?? 32
            let tileHeight = Int(attributes["tileheight"] ?? "32") ?? 32
            currentTileset = TMXTileset(firstGid: firstGid, name: name,
                                        tileWidth: tileWidth, tileHeight: tileHeight,
                                        imageSource: "", imageWidth: 0, imageHeight: 0)

        case "image":
            if let tileset = currentTileset {
                let source = attributes["source"] ?? ""
                let width = Int(attributes["width"] ?? "0") ?? 0
                let height = Int(attributes["height"] ?? "0") ?? 0
                // Recreate tileset with image info
                currentTileset = TMXTileset(firstGid: tileset.firstGid, name: tileset.name,
                                            tileWidth: tileset.tileWidth, tileHeight: tileset.tileHeight,
                                            imageSource: source, imageWidth: width, imageHeight: height)
            }

        case "layer":
            let name = attributes["name"] ?? ""
            let width = Int(attributes["width"] ?? "0") ?? 0
            let height = Int(attributes["height"] ?? "0") ?? 0
            currentLayer = TMXLayer(name: name, width: width, height: height)

        case "data":
            currentData = ""

        case "objectgroup":
            let name = attributes["name"] ?? ""
            currentObjectGroup = TMXObjectGroup(name: name)

        case "object":
            let name = attributes["name"] ?? ""
            let type = attributes["type"] ?? ""
            let x = CGFloat(Double(attributes["x"] ?? "0") ?? 0)
            let y = CGFloat(Double(attributes["y"] ?? "0") ?? 0)
            let width = CGFloat(Double(attributes["width"] ?? "0") ?? 0)
            let height = CGFloat(Double(attributes["height"] ?? "0") ?? 0)
            let obj = TMXObject(name: name, type: type, x: x, y: y, width: width, height: height)
            currentObjectGroup?.objects.append(obj)

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentElement == "data" {
            currentData += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "tileset":
            if let tileset = currentTileset {
                map?.tilesets.append(tileset)
            }
            currentTileset = nil

        case "layer":
            if let layer = currentLayer {
                map?.layers.append(layer)
            }
            currentLayer = nil

        case "data":
            if let layer = currentLayer {
                // Decode base64 + gzip compressed tile data
                let trimmed = currentData.trimmingCharacters(in: .whitespacesAndNewlines)
                if let decoded = decodeTileData(trimmed, width: layer.width, height: layer.height) {
                    layer.tiles = decoded
                }
            }
            currentData = ""

        case "objectgroup":
            if let group = currentObjectGroup {
                map?.objectGroups.append(group)
            }
            currentObjectGroup = nil

        default:
            break
        }

        currentElement = ""
    }

    // MARK: - Data Decoding

    /// Decode base64 + gzip compressed tile data
    private func decodeTileData(_ data: String, width: Int, height: Int) -> [Int]? {
        // Decode base64
        guard let base64Data = Data(base64Encoded: data, options: .ignoreUnknownCharacters) else {
            print("TMXParser: Failed to decode base64 data")
            return nil
        }

        // Decompress gzip
        guard let decompressed = decompress(data: base64Data) else {
            print("TMXParser: Failed to decompress gzip data")
            return nil
        }

        // Parse as array of 32-bit little-endian integers
        let expectedSize = width * height * 4
        guard decompressed.count >= expectedSize else {
            print("TMXParser: Decompressed data too small: \(decompressed.count) < \(expectedSize)")
            return nil
        }

        var tiles = [Int]()
        tiles.reserveCapacity(width * height)

        for i in 0..<(width * height) {
            let offset = i * 4
            let gid = Int(decompressed[offset]) |
                     (Int(decompressed[offset + 1]) << 8) |
                     (Int(decompressed[offset + 2]) << 16) |
                     (Int(decompressed[offset + 3]) << 24)
            tiles.append(gid)
        }

        return tiles
    }

    /// Decompress gzip data using Compression framework
    private func decompress(data: Data) -> Data? {
        // Try zlib decompression (gzip is a variant)
        let bufferSize = 1024 * 1024 // 1MB buffer should be enough for map data
        var destinationBuffer = [UInt8](repeating: 0, count: bufferSize)

        let decompressedSize = data.withUnsafeBytes { (sourcePtr: UnsafeRawBufferPointer) -> Int in
            guard let sourceBase = sourcePtr.baseAddress else { return 0 }
            return compression_decode_buffer(
                &destinationBuffer,
                bufferSize,
                sourceBase.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard decompressedSize > 0 else { return nil }
        return Data(destinationBuffer.prefix(decompressedSize))
    }
}
