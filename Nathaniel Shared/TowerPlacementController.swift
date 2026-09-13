//
//  TowerPlacementController.swift
//  Nathaniel Shared
//
//  Coordinates tower construction through one validation and spending path.
//

import SpriteKit

// MARK: - Placement Indicator

/// Visual indicator showing where a tower will be placed and whether it's valid
class PlacementIndicator: SKNode {
    // MARK: - Properties

    private let indicatorCircle: SKShapeNode

    /// Whether the current position is valid for placement
    var isValid: Bool = true {
        didSet {
            self.updateAppearance()
        }
    }

    // MARK: - Constants

    static let indicatorRadius: CGFloat = 25

    // MARK: - Initialization

    override init() {
        // Create placement indicator circle
        self.indicatorCircle = SKShapeNode(circleOfRadius: Self.indicatorRadius)
        self.indicatorCircle.lineWidth = 3

        super.init()

        addChild(self.indicatorCircle)
        zPosition = 90 // Below characters but above ground

        isHidden = true
        self.updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Visual Update

    private func updateAppearance() {
        if self.isValid {
            self.indicatorCircle.strokeColor = SKColor.green
            self.indicatorCircle.fillColor = SKColor.green.withAlphaComponent(0.3)
        } else {
            self.indicatorCircle.strokeColor = SKColor.red
            self.indicatorCircle.fillColor = SKColor.red.withAlphaComponent(0.3)
        }
    }
}

// MARK: - Tower Placement Controller Delegate

/// Protocol for tower placement events
protocol TowerPlacementControllerDelegate: AnyObject {
    /// Called when a tower is successfully placed
    func placementController(
        _ controller: TowerPlacementController,
        didPlaceTower type: TowerType,
        at position: CGPoint
    )

    /// Called when placement fails (insufficient resources, invalid position)
    func placementController(
        _ controller: TowerPlacementController,
        didFailPlacement type: TowerType,
        reason: PlacementResult
    )

    /// Called when placement is cancelled
    func placementController(_ controller: TowerPlacementController, didCancelPlacement type: TowerType)
}

// MARK: - Tower Placement Controller

/// Coordinates tower placement from build menu to battlefield
class TowerPlacementController: BuildMenuDelegate {
    // MARK: - Properties

    weak var delegate: TowerPlacementControllerDelegate?

    /// The build menu
    let buildMenu: BuildMenu

    /// Placement indicator
    let placementIndicator: PlacementIndicator

    /// Placement validator
    let validator: PlacementValidator

    /// Hermes must be stationary in build mode to place towers.
    weak var hermes: Hermes?

    /// Reference to structure manager for creating towers
    weak var structureManager: StructureManager?

    /// Reference to resource manager for spending resources
    weak var resourceManager: ResourceManager?

    /// Reference to scene
    weak var scene: SKScene?

    /// Currently dragging tower type
    private(set) var draggingType: TowerType?

    /// Whether currently in a drag operation
    var isDragging: Bool {
        self.draggingType != nil
    }

    // MARK: - Initialization

    init(viewportSize: CGSize) {
        self.buildMenu = BuildMenu(size: viewportSize)
        self.placementIndicator = PlacementIndicator()
        self.validator = PlacementValidator()

        self.buildMenu.delegate = self
    }

    /// Setup references needed for placement
    func setup(
        scene: SKScene,
        structureManager: StructureManager,
        resourceManager: ResourceManager,
        hermes: Hermes?
    ) {
        self.scene = scene
        self.structureManager = structureManager
        self.resourceManager = resourceManager
        self.validator.resourceManager = resourceManager
        self.hermes = hermes
    }

    /// Configure validator with game objects
    func configureValidator(tmxRenderer: TMXRenderer?, enemyManager: EnemyManager?, playerCharacters: [Character]) {
        self.validator.tmxRenderer = tmxRenderer
        self.validator.enemyManager = enemyManager
        self.validator.structureManager = self.structureManager
        self.validator.playerCharacters = playerCharacters
    }

    // MARK: - Menu Control

    /// Show the build menu
    func showMenu() {
        guard self.hermes?.isInBuildMode == true else { return }
        self.buildMenu.show()
    }

    /// Hide the build menu
    func hideMenu() {
        self.buildMenu.hide()
    }

    /// Toggle menu visibility
    func toggleMenu() {
        if self.buildMenu.isVisible {
            self.hideMenu()
        } else {
            self.showMenu()
        }
    }

    /// Update menu affordability based on current resources
    func updateAffordability() {
        self.buildMenu.updateAffordability()
    }

    // MARK: - Touch Handling

    /// Handle touch began - returns true if handled
    func handleTouchBegan(at point: CGPoint) -> Bool {
        self.buildMenu.handleTouchBegan(at: point)
    }

    /// Handle touch moved - returns true if handled
    /// - Parameters:
    ///   - worldPoint: Touch position in world/scene coordinates (for placement validation)
    ///   - hudLocation: Touch position in HUD/camera coordinates (for ghost tower)
    ///   - scene: The scene for context
    func handleTouchMoved(to worldPoint: CGPoint, hudLocation: CGPoint, in scene: SKScene) -> Bool {
        guard self.isDragging else { return false }

        // Update build menu ghost tower (uses HUD coordinates)
        _ = self.buildMenu.handleTouchMoved(to: hudLocation)

        // Update placement indicator (uses world coordinates)
        self.placementIndicator.position = worldPoint
        self.placementIndicator.isHidden = false

        // Validate position (uses world coordinates)
        let result = self.validator.validate(position: worldPoint)
        let isValid = result == .valid
        self.placementIndicator.isValid = isValid

        // Update ghost tower validity visual
        self.buildMenu.updateGhostValidity(isValid: isValid)

        return true
    }

    /// Handle touch ended - returns true if handled
    /// - Parameters:
    ///   - worldPoint: Touch position in world/scene coordinates (for placement)
    ///   - hudLocation: Touch position in HUD/camera coordinates (for menu detection)
    func handleTouchEnded(at worldPoint: CGPoint, hudLocation: CGPoint) -> Bool {
        guard self.isDragging else { return false }

        // Forward to build menu with HUD coordinates for menu bounds check
        // but use world coordinates for the actual placement position
        return self.buildMenu.handleTouchEnded(at: hudLocation, worldPosition: worldPoint)
    }

    /// Handle touch cancelled
    func handleTouchCancelled() {
        self.buildMenu.handleTouchCancelled()
        self.cleanupDragState()
    }

    // MARK: - Placement

    /// Attempt to place a tower at the given position
    @discardableResult
    func attemptPlacement(type: TowerType, at position: CGPoint) -> Bool {
        guard let hermes, hermes.isAlive, hermes.isInBuildMode, let structureManager else {
            self.cleanupDragState()
            return false
        }

        // Validate position
        let result = self.validator.validate(position: position)
        guard result == .valid else {
            // Play failure sound
            if let scene {
                AudioManager.shared.playSoundEffect(.laserBlast, on: scene) // Use zap as error sound
            }
            self.delegate?.placementController(self, didFailPlacement: type, reason: result)
            self.cleanupDragState()
            return false
        }

        // Check affordability
        guard let resourceManager, resourceManager.canAfford(type.cost) else {
            // Play failure sound
            if let scene {
                AudioManager.shared.playSoundEffect(.laserBlast, on: scene)
            }
            self.delegate?
                .placementController(self, didFailPlacement: type, reason: .valid) // Valid position but can't afford
            self.cleanupDragState()
            return false
        }

        // Spend resources
        guard resourceManager.spendResources(type.cost) else {
            self.cleanupDragState()
            return false
        }

        // Create tower
        structureManager.addHermesTower(type: type, at: position)

        // Play success sound
        if let scene {
            AudioManager.shared.playSoundEffect(.collect, on: scene) // Use collect sound for construction
        }

        // Notify delegate
        self.delegate?.placementController(self, didPlaceTower: type, at: position)

        // Update affordability after spending
        self.buildMenu.updateAffordability()

        self.cleanupDragState()
        return true
    }

    /// Clean up after drag ends
    private func cleanupDragState() {
        self.draggingType = nil
        self.placementIndicator.isHidden = true
    }

    // MARK: - BuildMenuDelegate

    func buildMenu(_ menu: BuildMenu, didStartDragging type: TowerType, from position: CGPoint) {
        self.draggingType = type

        // Show placement indicator
        self.placementIndicator.isHidden = false
    }

    func buildMenu(_ menu: BuildMenu, didEndDragging type: TowerType, at position: CGPoint) {
        self.attemptPlacement(type: type, at: position)
    }

    func buildMenu(_ menu: BuildMenu, didCancelDragging type: TowerType) {
        self.delegate?.placementController(self, didCancelPlacement: type)
        self.cleanupDragState()
    }

    func buildMenuCurrentResources(_ menu: BuildMenu) -> Int {
        self.resourceManager?.totalCollected ?? 0
    }
}
