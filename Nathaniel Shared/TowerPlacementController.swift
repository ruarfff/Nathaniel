//
//  TowerPlacementController.swift
//  Nathaniel Shared
//
//  Coordinates tower placement from the build menu to the battlefield.
//  Handles drag preview, placement validation, and tower creation.
//

import SpriteKit

// MARK: - Placement Indicator

/// Visual indicator showing where a tower will be placed and whether it's valid
class PlacementIndicator: SKNode {

    // MARK: - Properties

    private let indicatorCircle: SKShapeNode
    private let rangeCircle: SKShapeNode

    /// Whether the current position is valid for placement
    var isValid: Bool = true {
        didSet {
            updateAppearance()
        }
    }

    // MARK: - Constants

    static let indicatorRadius: CGFloat = 25
    static let rangeRadius: CGFloat = TowerConfig.buildRadius

    // MARK: - Initialization

    override init() {
        // Create placement indicator circle
        indicatorCircle = SKShapeNode(circleOfRadius: Self.indicatorRadius)
        indicatorCircle.lineWidth = 3

        // Create build range circle (shows Hermes's build radius)
        rangeCircle = SKShapeNode(circleOfRadius: Self.rangeRadius)
        rangeCircle.lineWidth = 2
        rangeCircle.strokeColor = SKColor.cyan.withAlphaComponent(0.3)
        rangeCircle.fillColor = .clear

        super.init()

        addChild(indicatorCircle)
        zPosition = 90  // Below characters but above ground

        isHidden = true
        updateAppearance()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Visual Update

    private func updateAppearance() {
        if isValid {
            indicatorCircle.strokeColor = SKColor.green
            indicatorCircle.fillColor = SKColor.green.withAlphaComponent(0.3)
        } else {
            indicatorCircle.strokeColor = SKColor.red
            indicatorCircle.fillColor = SKColor.red.withAlphaComponent(0.3)
        }
    }

    // MARK: - Range Circle

    /// Show the build range circle centered on Hermes
    func showRangeCircle(centeredAt hermesPosition: CGPoint, in scene: SKScene) {
        rangeCircle.removeFromParent()
        rangeCircle.position = hermesPosition
        scene.addChild(rangeCircle)
    }

    /// Hide the build range circle
    func hideRangeCircle() {
        rangeCircle.removeFromParent()
    }
}

// MARK: - Tower Placement Controller Delegate

/// Protocol for tower placement events
protocol TowerPlacementControllerDelegate: AnyObject {
    /// Called when a tower is successfully placed
    func placementController(_ controller: TowerPlacementController, didPlaceTower type: TowerType, at position: CGPoint)

    /// Called when placement fails (insufficient resources, invalid position)
    func placementController(_ controller: TowerPlacementController, didFailPlacement type: TowerType, reason: PlacementResult)

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
        return draggingType != nil
    }

    // MARK: - Initialization

    init(viewportSize: CGSize) {
        buildMenu = BuildMenu(size: viewportSize)
        placementIndicator = PlacementIndicator()
        validator = PlacementValidator()

        buildMenu.delegate = self
    }

    /// Setup references needed for placement
    func setup(scene: SKScene, structureManager: StructureManager, resourceManager: ResourceManager, hermes: Character?) {
        self.scene = scene
        self.structureManager = structureManager
        self.resourceManager = resourceManager
        validator.hermes = hermes
    }

    /// Configure validator with game objects
    func configureValidator(tmxRenderer: TMXRenderer?, enemyManager: EnemyManager?, playerCharacters: [Character]) {
        validator.tmxRenderer = tmxRenderer
        validator.enemyManager = enemyManager
        validator.structureManager = structureManager
        validator.playerCharacters = playerCharacters
    }

    // MARK: - Menu Control

    /// Show the build menu
    func showMenu() {
        buildMenu.show()
    }

    /// Hide the build menu
    func hideMenu() {
        buildMenu.hide()
    }

    /// Toggle menu visibility
    func toggleMenu() {
        buildMenu.toggle()
    }

    /// Update menu affordability based on current resources
    func updateAffordability() {
        buildMenu.updateAffordability()
    }

    // MARK: - Touch Handling

    /// Handle touch began - returns true if handled
    func handleTouchBegan(at point: CGPoint) -> Bool {
        return buildMenu.handleTouchBegan(at: point)
    }

    /// Handle touch moved - returns true if handled
    func handleTouchMoved(to point: CGPoint, in scene: SKScene) -> Bool {
        guard isDragging else { return false }

        // Update build menu (moves ghost tower)
        _ = buildMenu.handleTouchMoved(to: point)

        // Update placement indicator
        placementIndicator.position = point
        placementIndicator.isHidden = false

        // Validate position
        let result = validator.validate(position: point)
        let isValid = result == .valid
        placementIndicator.isValid = isValid

        // Update ghost tower validity visual
        buildMenu.updateGhostValidity(isValid: isValid)

        return true
    }

    /// Handle touch ended - returns true if handled
    func handleTouchEnded(at point: CGPoint) -> Bool {
        guard isDragging else { return false }

        // Forward to build menu
        return buildMenu.handleTouchEnded(at: point)
    }

    /// Handle touch cancelled
    func handleTouchCancelled() {
        buildMenu.handleTouchCancelled()
        cleanupDragState()
    }

    // MARK: - Placement

    /// Attempt to place a tower at the given position
    private func attemptPlacement(type: TowerType, at position: CGPoint) {
        // Validate position
        let result = validator.validate(position: position)
        guard result == .valid else {
            // Play failure sound
            if let scene = scene {
                AudioManager.shared.playSoundEffect(.laserBlast, on: scene)  // Use zap as error sound
            }
            delegate?.placementController(self, didFailPlacement: type, reason: result)
            cleanupDragState()
            return
        }

        // Check affordability
        guard let resourceManager = resourceManager, resourceManager.canAfford(type.cost) else {
            // Play failure sound
            if let scene = scene {
                AudioManager.shared.playSoundEffect(.laserBlast, on: scene)
            }
            delegate?.placementController(self, didFailPlacement: type, reason: .valid)  // Valid position but can't afford
            cleanupDragState()
            return
        }

        // Spend resources
        guard resourceManager.spendResources(type.cost) else {
            cleanupDragState()
            return
        }

        // Create tower
        structureManager?.addHermesTower(type: type, at: position)

        // Play success sound
        if let scene = scene {
            AudioManager.shared.playSoundEffect(.collect, on: scene)  // Use collect sound for construction
        }

        // Notify delegate
        delegate?.placementController(self, didPlaceTower: type, at: position)

        // Update affordability after spending
        buildMenu.updateAffordability()

        cleanupDragState()
    }

    /// Clean up after drag ends
    private func cleanupDragState() {
        draggingType = nil
        placementIndicator.isHidden = true
        placementIndicator.hideRangeCircle()
    }

    // MARK: - BuildMenuDelegate

    func buildMenu(_ menu: BuildMenu, didStartDragging type: TowerType, from position: CGPoint) {
        draggingType = type

        // Show placement indicator
        placementIndicator.isHidden = false

        // Show build range circle around Hermes
        if let hermes = validator.hermes, let scene = scene {
            placementIndicator.showRangeCircle(centeredAt: hermes.position, in: scene)
        }
    }

    func buildMenu(_ menu: BuildMenu, didEndDragging type: TowerType, at position: CGPoint) {
        attemptPlacement(type: type, at: position)
    }

    func buildMenu(_ menu: BuildMenu, didCancelDragging type: TowerType) {
        delegate?.placementController(self, didCancelPlacement: type)
        cleanupDragState()
    }

    func buildMenuCurrentResources(_ menu: BuildMenu) -> Int {
        return resourceManager?.totalCollected ?? 0
    }
}
