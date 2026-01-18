//
//  ResourceSprite.swift
//  Nathaniel Shared
//
//  Factory for creating programmatic resource sprites (scrap metal chunks).
//

import SpriteKit

// MARK: - ResourceSprite Factory

/// Factory class for creating resource sprites programmatically
class ResourceSprite {

    // MARK: - Cached Textures

    /// Cached textures for different sizes to avoid regenerating
    private static var textureCache: [String: SKTexture] = [:]

    // MARK: - Colors

    /// Base metallic gray
    private static let metalDark = SKColor(red: 0.29, green: 0.29, blue: 0.31, alpha: 1.0)

    /// Lighter metallic highlight
    private static let metalLight = SKColor(red: 0.52, green: 0.52, blue: 0.56, alpha: 1.0)

    /// Edge highlight (brightest)
    private static let metalShine = SKColor(red: 0.72, green: 0.72, blue: 0.76, alpha: 1.0)

    /// Green glow color (matches HUD)
    private static let glowColor = SKColor(red: 0.3, green: 0.85, blue: 0.5, alpha: 0.6)

    // MARK: - Public Factory Methods

    /// Create a scrap metal resource sprite
    /// - Parameter size: Base size of the sprite (default 14)
    /// - Returns: SKSpriteNode containing the rendered scrap metal
    static func createScrapMetal(size: CGFloat = 14) -> SKSpriteNode {
        let cacheKey = "scrap_\(Int(size))"

        // Check cache first
        if let cachedTexture = textureCache[cacheKey] {
            let sprite = SKSpriteNode(texture: cachedTexture)
            sprite.name = "resourceSprite"
            return sprite
        }

        // Create the sprite node hierarchy
        let container = SKNode()

        // Add glow layer (behind everything)
        let glow = createGlowLayer(size: size)
        container.addChild(glow)

        // Add the main metal chunk
        let metalChunk = createMetalChunk(size: size)
        container.addChild(metalChunk)

        // Add highlight/shine
        let shine = createShineHighlight(size: size)
        container.addChild(shine)

        // Render to texture for performance
        let textureSize = CGSize(width: size * 3, height: size * 3)
        let texture = SKView().texture(from: container, crop: CGRect(
            x: -textureSize.width / 2,
            y: -textureSize.height / 2,
            width: textureSize.width,
            height: textureSize.height
        ))

        // Cache the texture
        if let texture = texture {
            texture.filteringMode = .nearest  // Pixel art style
            textureCache[cacheKey] = texture
        }

        let sprite = SKSpriteNode(texture: texture, size: textureSize)
        sprite.name = "resourceSprite"
        return sprite
    }

    // MARK: - Private Layer Creation

    /// Create the outer glow effect
    private static func createGlowLayer(size: CGFloat) -> SKNode {
        let glowNode = SKShapeNode(circleOfRadius: size * 1.2)
        glowNode.fillColor = glowColor
        glowNode.strokeColor = .clear
        glowNode.alpha = 0.5
        glowNode.zPosition = -1

        // Add a second, larger, fainter glow
        let outerGlow = SKShapeNode(circleOfRadius: size * 1.6)
        outerGlow.fillColor = glowColor
        outerGlow.strokeColor = .clear
        outerGlow.alpha = 0.2
        outerGlow.zPosition = -2
        glowNode.addChild(outerGlow)

        return glowNode
    }

    /// Create the main irregular metal polygon
    private static func createMetalChunk(size: CGFloat) -> SKShapeNode {
        // Create an irregular 6-sided polygon
        let path = CGMutablePath()

        // Define irregular vertices (not symmetrical)
        let vertices: [CGPoint] = [
            CGPoint(x: size * 0.1, y: size * 0.5),    // Top-left-ish
            CGPoint(x: size * 0.55, y: size * 0.45),  // Top-right
            CGPoint(x: size * 0.5, y: size * 0.1),    // Right
            CGPoint(x: size * 0.2, y: -size * 0.45),  // Bottom-right
            CGPoint(x: -size * 0.4, y: -size * 0.35), // Bottom-left
            CGPoint(x: -size * 0.5, y: size * 0.15),  // Left
        ]

        path.move(to: vertices[0])
        for i in 1..<vertices.count {
            path.addLine(to: vertices[i])
        }
        path.closeSubpath()

        let chunk = SKShapeNode(path: path)
        chunk.fillColor = metalDark
        chunk.strokeColor = metalLight
        chunk.lineWidth = 1.5
        chunk.zPosition = 0

        return chunk
    }

    /// Create the highlight/shine effect
    private static func createShineHighlight(size: CGFloat) -> SKNode {
        // Small bright spot in upper area to simulate light reflection
        let shinePath = CGMutablePath()

        let shineVertices: [CGPoint] = [
            CGPoint(x: size * 0.0, y: size * 0.35),
            CGPoint(x: size * 0.25, y: size * 0.3),
            CGPoint(x: size * 0.15, y: size * 0.1),
            CGPoint(x: -size * 0.1, y: size * 0.15),
        ]

        shinePath.move(to: shineVertices[0])
        for i in 1..<shineVertices.count {
            shinePath.addLine(to: shineVertices[i])
        }
        shinePath.closeSubpath()

        let shine = SKShapeNode(path: shinePath)
        shine.fillColor = metalShine
        shine.strokeColor = .clear
        shine.alpha = 0.7
        shine.zPosition = 1

        return shine
    }

    // MARK: - Utility

    /// Clear the texture cache (call on memory warning)
    static func clearCache() {
        textureCache.removeAll()
    }

    /// Create variant with size based on resource amount
    /// - Parameter amount: Resource value (affects size slightly)
    /// - Returns: Appropriately sized sprite
    static func createForAmount(_ amount: Int) -> SKSpriteNode {
        // Scale size slightly based on amount
        // Small (1-3): 12, Medium (4-7): 14, Large (8+): 16
        let size: CGFloat
        if amount <= 3 {
            size = 12
        } else if amount <= 7 {
            size = 14
        } else {
            size = 16
        }
        return createScrapMetal(size: size)
    }
}
