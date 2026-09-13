import SpriteKit

/// Controller for camera behavior including following, zoom, and map bounds clamping.
class CameraController {
    // MARK: - Properties

    /// The camera node being controlled
    private let camera: SKCameraNode

    /// Map bounds in world coordinates
    private var mapSize: CGSize = .zero

    /// Visible viewport size in scene coordinates (accounts for aspectFill scaling)
    private var visibleViewportSize: CGSize = .zero

    // MARK: - Zoom Properties

    /// Current camera zoom level (1.0 = default, higher = zoomed out)
    private var zoom: CGFloat = 1.0

    /// Minimum camera scale (zoomed in)
    private let minZoom: CGFloat = 0.5

    /// Maximum camera scale (zoomed out)
    private let maxZoom: CGFloat = 2.0

    /// Whether camera is currently animating to a new position
    private(set) var isAnimating: Bool = false

    // MARK: - Initialization

    /// Create a camera controller with an existing camera node
    /// - Parameter camera: The SKCameraNode to control
    init(camera: SKCameraNode) {
        self.camera = camera
    }

    // MARK: - Configuration

    /// Configure the controller with map and viewport information
    /// - Parameters:
    ///   - mapSize: The total map size in pixels
    ///   - viewportSize: The visible viewport size in scene coordinates
    func configure(mapSize: CGSize, viewportSize: CGSize) {
        self.mapSize = mapSize
        self.visibleViewportSize = viewportSize
    }

    // MARK: - Position Clamping

    /// Clamp a position to keep the camera within map bounds.
    /// Accounts for zoom level and viewport size. Centers on map if map is smaller than viewport.
    /// - Parameter position: The desired camera position
    /// - Returns: The clamped position within map bounds
    func clampToMapBounds(_ position: CGPoint) -> CGPoint {
        guard self.mapSize.width > 0, self.mapSize.height > 0 else { return position }

        let effectiveViewport = self.visibleViewportSize.width > 0 ? self.visibleViewportSize : self.mapSize
        let halfWidth = (effectiveViewport.width / 2) * self.zoom
        let halfHeight = (effectiveViewport.height / 2) * self.zoom

        var clampedPos = position

        // Handle X clamping: if map is narrower than viewport, center on map
        if self.mapSize.width <= halfWidth * 2 {
            clampedPos.x = self.mapSize.width / 2
        } else {
            clampedPos.x = max(halfWidth, min(self.mapSize.width - halfWidth, clampedPos.x))
        }

        // Handle Y clamping: if map is shorter than viewport, center on map
        if self.mapSize.height <= halfHeight * 2 {
            clampedPos.y = self.mapSize.height / 2
        } else {
            clampedPos.y = max(halfHeight, min(self.mapSize.height - halfHeight, clampedPos.y))
        }

        return clampedPos
    }

    // MARK: - Camera Following

    /// Make the camera smoothly follow a target position
    /// - Parameters:
    ///   - targetPosition: The position to follow
    ///   - smoothing: Interpolation factor (0-1), higher = faster follow
    func updateFollow(target targetPosition: CGPoint, smoothing: CGFloat = 0.1) {
        // Skip if camera is animating (e.g., during character switch)
        guard !self.isAnimating else { return }

        // Clamp target position to map bounds
        let clampedPos = self.clampToMapBounds(targetPosition)

        // Smooth camera movement (lerp)
        let currentPos = self.camera.position
        self.camera.position = CGPoint(
            x: currentPos.x + (clampedPos.x - currentPos.x) * smoothing,
            y: currentPos.y + (clampedPos.y - currentPos.y) * smoothing
        )
    }

    /// Immediately set camera position (clamped to map bounds, no smoothing)
    /// Use this for initial positioning or teleporting the camera
    /// - Parameter position: Target position
    func setPosition(_ position: CGPoint) {
        self.camera.position = self.clampToMapBounds(position)
    }

    // MARK: - Camera Animation

    /// Animate camera to a target position with smooth easing
    /// - Parameters:
    ///   - position: Target position
    ///   - duration: Animation duration
    func animateTo(_ position: CGPoint, duration: TimeInterval = 0.3) {
        // Mark as animating to prevent follow from interfering
        self.isAnimating = true

        // Clamp target position to map bounds
        let clampedPos = self.clampToMapBounds(position)

        // Animate to the clamped position
        let moveAction = SKAction.move(to: clampedPos, duration: duration)
        moveAction.timingMode = .easeInEaseOut

        self.camera.run(moveAction) { [weak self] in
            self?.isAnimating = false
        }
    }

    // MARK: - Camera Zoom

    /// Get effective min zoom (from DevSettings in DEBUG)
    private var effectiveMinZoom: CGFloat {
        #if DEBUG
            return DevSettings.shared.cameraMinZoom
        #else
            return self.minZoom
        #endif
    }

    /// Get effective max zoom (from DevSettings in DEBUG)
    private var effectiveMaxZoom: CGFloat {
        #if DEBUG
            return DevSettings.shared.cameraMaxZoom
        #else
            return self.maxZoom
        #endif
    }

    /// Update camera zoom by a scale factor
    /// - Parameter scale: Multiplier for current zoom (>1 zooms out, <1 zooms in)
    func updateZoom(by scale: CGFloat) {
        let newZoom = self.zoom * scale
        self.zoom = max(self.effectiveMinZoom, min(self.effectiveMaxZoom, newZoom))
        self.camera.setScale(self.zoom)
    }

    /// Set camera zoom to an absolute value
    /// - Parameter zoomLevel: Target zoom level (clamped to min/max)
    func setZoom(_ zoomLevel: CGFloat) {
        self.zoom = max(self.effectiveMinZoom, min(self.effectiveMaxZoom, zoomLevel))
        self.camera.setScale(self.zoom)
    }

    /// Handle pinch gesture zoom
    /// - Parameter scale: Gesture scale factor
    func handlePinchZoom(scale: CGFloat) {
        self.updateZoom(by: scale)
    }
}
