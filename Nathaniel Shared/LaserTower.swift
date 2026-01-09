import SpriteKit

// MARK: - Laser Beam

/// Visual representation of a laser beam
class LaserBeam {
    /// The line node representing the beam
    let node: SKShapeNode

    /// Beam color
    var color: SKColor {
        didSet {
            self.node.strokeColor = self.color
        }
    }

    /// Beam thickness
    var thickness: CGFloat {
        didSet {
            self.node.lineWidth = self.thickness
        }
    }

    /// Whether the beam is currently active
    var isActive: Bool = false {
        didSet {
            self.node.isHidden = !self.isActive
        }
    }

    init(color: SKColor = .red, thickness: CGFloat = 3) {
        self.color = color
        self.thickness = thickness

        self.node = SKShapeNode()
        self.node.strokeColor = color
        self.node.lineWidth = thickness
        self.node.lineCap = .round
        self.node.zPosition = 50
        self.node.isHidden = true
    }

    /// Update the beam to fire from origin to target
    func fire(from origin: CGPoint, to target: CGPoint) {
        let path = CGMutablePath()
        path.move(to: origin)
        path.addLine(to: target)
        self.node.path = path
        self.isActive = true
    }

    /// Deactivate the beam
    func deactivate() {
        self.isActive = false
        self.node.path = nil
    }
}

// MARK: - Laser Tower

/// Armed tower that fires continuous laser beams at enemies
class LaserTower: DefensiveStructure {
    // MARK: - Constants

    /// Resource cost to build this tower
    static let cost: Int = BuildConfig.TowerCosts.laserTower

    // MARK: - Properties

    /// Damage per second while beam is active
    let damagePerSecond: Int = 20

    /// Cooldown between beam bursts
    let cooldownTime: TimeInterval = 3.5

    /// Duration of each beam burst
    let burstDuration: TimeInterval = 1.5

    /// Time elapsed in current cooldown
    private var cooldownElapsed: TimeInterval = 0

    /// Time elapsed in current burst
    private var burstElapsed: TimeInterval = 0

    /// Whether currently firing
    private(set) var isFiring: Bool = false

    /// The laser beam visual
    let beam: LaserBeam

    /// Sound played flag (to avoid repeating)
    private var hasPlayedSound: Bool = false

    // MARK: - Initialization

    init() {
        self.beam = LaserBeam(color: .red, thickness: 3)

        super.init(name: "LaserTower", maxHP: 600, attackRange: 350)

        // Track build cost for recoup calculation
        buildCost = LaserTower.cost

        // Load tower texture
        loadTexture(named: "lasertower", size: CGSize(width: 48, height: 64))
    }

    /// Called when adding to scene - adds beam node to scene
    func setupBeamNode(in scene: SKScene) {
        scene.addChild(self.beam.node)
    }

    // MARK: - Update

    override func update(deltaTime: TimeInterval) {
        guard isActive, isAlive else {
            self.beam.deactivate()
            return
        }

        // Update cooldown
        if !self.isFiring {
            self.cooldownElapsed += deltaTime
        }

        super.update(deltaTime: deltaTime)
    }

    override func attackTarget(_ target: Enemy, deltaTime: TimeInterval) {
        // Check if ready to fire
        if !self.isFiring, self.cooldownElapsed >= self.cooldownTime {
            // Start firing
            self.isFiring = true
            self.burstElapsed = 0
            self.cooldownElapsed = 0
            self.hasPlayedSound = false
        }

        if self.isFiring {
            self.burstElapsed += deltaTime

            // Play sound during burst (once)
            if !self.hasPlayedSound, self.burstElapsed > 0.1 {
                if let scene = sprite.scene {
                    AudioManager.shared.playSoundEffect(.laser, on: scene)
                }
                self.hasPlayedSound = true
            }

            // Update beam visual
            self.beam.fire(from: position, to: target.position)

            // Deal damage over time - towers generate threat so enemies retaliate
            let damage = Int(CGFloat(damagePerSecond) * CGFloat(deltaTime))
            if damage > 0 {
                // target is already Enemy, use threat-aware damage
                target.takeDamage(damage, from: self)
            }

            // Check if burst is over
            if self.burstElapsed >= self.burstDuration {
                self.isFiring = false
                self.beam.deactivate()
            }
        }
    }

    // MARK: - Death

    override func onDeath() {
        self.beam.deactivate()
        self.beam.node.removeFromParent()
        super.onDeath()
    }
}
