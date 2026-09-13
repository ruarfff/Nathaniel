//
//  HermesParityTests.swift
//  NathanielTests
//
//  Verifies the original Hermes movement, construction, and tower combat rules.
//

@testable import Nathaniel
import SpriteKit
import XCTest

final class HermesParityTests: XCTestCase {
    func testHermesStaysInBuildModeAndFollowsWithoutTeleporting() {
        let previousSpeed = DevSettings.shared.hermesSpeed
        DevSettings.shared.hermesSpeed = 40
        defer { DevSettings.shared.hermesSpeed = previousSpeed }

        let hermes = Hermes()
        let nathaniel = Nathaniel()
        nathaniel.position = CGPoint(x: 1_000, y: 0)
        hermes.followTarget = nathaniel

        hermes.moveTo(CGPoint(x: 500, y: 0))
        hermes.destination = CGPoint(x: 500, y: 0)
        hermes.update(deltaTime: 1)
        XCTAssertTrue(hermes.isInBuildMode)
        XCTAssertEqual(hermes.position, .zero)
        XCTAssertEqual(hermes.sprite.size, CGSize(width: 80, height: 72))

        hermes.enterFollowMode()
        hermes.update(deltaTime: 1)
        XCTAssertEqual(hermes.position.x, 40, accuracy: 0.001)
        XCTAssertEqual(hermes.position.y, 0, accuracy: 0.001)

        hermes.enterBuildMode()
        hermes.update(deltaTime: 1)
        XCTAssertEqual(hermes.position.x, 40, accuracy: 0.001)
        XCTAssertFalse(hermes.isMoving)
    }

    func testHermesStopsWithinOneHundredPointsOfNathaniel() {
        let hermes = Hermes()
        let nathaniel = Nathaniel()
        nathaniel.position = CGPoint(x: 100, y: 0)
        hermes.followTarget = nathaniel
        hermes.enterFollowMode()

        hermes.update(deltaTime: 1)

        XCTAssertEqual(hermes.position, .zero)
        XCTAssertFalse(hermes.isMoving)
    }

    func testBuildingHasNoRadiusAndRequiresStationaryHermes() {
        let resources = ResourceManager.shared
        let previousTotal = resources.totalCollected
        resources.restore(total: 30)
        defer { resources.restore(total: previousTotal) }

        let hermes = Hermes()
        let scene = SKScene(size: CGSize(width: 2_000, height: 2_000))
        let structures = StructureManager(scene: scene)
        let controller = TowerPlacementController(viewportSize: scene.size)
        controller.setup(scene: scene, structureManager: structures, resourceManager: resources, hermes: hermes)
        controller.configureValidator(tmxRenderer: nil, enemyManager: nil, playerCharacters: [hermes])
        let position = CGPoint(x: 1_000, y: 1_000)
        let cost = TowerType.gunTower.cost

        XCTAssertTrue(controller.attemptPlacement(type: .gunTower, at: position))
        XCTAssertEqual(resources.totalCollected, 30 - cost)
        XCTAssertEqual(structures.hermesTowerCount, 1)

        XCTAssertFalse(controller.attemptPlacement(type: .gunTower, at: CGPoint(x: 1_040, y: 1_000)))
        hermes.enterFollowMode()
        XCTAssertFalse(controller.attemptPlacement(type: .gunTower, at: CGPoint(x: 1_200, y: 1_000)))
        XCTAssertEqual(resources.totalCollected, 30 - cost)
    }

    @MainActor
    func testFollowingDestroysBuiltTowersAndTheirProjectiles() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        let structures = try XCTUnwrap(scene.findStructureManagerPublic())
        let gun = try XCTUnwrap(structures.addHermesTower(type: .gunTower, at: CGPoint(x: 320, y: 200)) as? GunTower)
        let laser = structures.addHermesTower(type: .laserTower, at: CGPoint(x: 400, y: 200))
        let mapTower = structures.addHealTower(at: CGPoint(x: 500, y: 200))
        let enemy = Grunt()
        enemy.position = CGPoint(x: 360, y: 200)
        gun.gun.update(deltaTime: gun.gun.cooldownTime)
        gun.attackTarget(enemy, deltaTime: 0)
        let bullet = try XCTUnwrap(gun.gun.activeBullets.first)
        scene.toggleSelectedCharacter()
        scene.toggleBuildMenu()
        let wallet = ResourceManager.shared.totalCollected
        let refund = gun.constructionCost / 4 + laser.constructionCost / 4

        scene.setHermesMode(.following)

        XCTAssertEqual(structures.hermesTowerCount, 0)
        XCTAssertEqual(structures.count, 1)
        XCTAssertTrue(mapTower.isAlive)
        XCTAssertFalse(gun.isAlive)
        XCTAssertFalse(laser.isAlive)
        XCTAssertFalse(gun.isActive)
        XCTAssertFalse(laser.isActive)
        XCTAssertFalse(bullet.isActive)
        XCTAssertNil(bullet.sprite.parent)
        XCTAssertFalse(scene.isBuildMenuVisible)
        XCTAssertEqual(scene.findHermesPublic()?.mode, .following)
        XCTAssertEqual(ResourceManager.shared.totalCollected, wallet + refund)
        scene.setHermesMode(.following)
        XCTAssertEqual(ResourceManager.shared.totalCollected, wallet + refund)
    }

    func testDismantlingRefundsEachSurvivingTowerOnceAndRoundsDown() {
        let scene = SKScene()
        let structures = StructureManager(scene: scene)
        for (type, paidCost) in [(TowerType.gunTower, 5), (.laserTower, 15), (.healTower, 10)] {
            let tower = structures.addHermesTower(type: type, at: .zero)
            tower.constructionCost = paidCost
        }
        let destroyed = structures.addHermesTower(type: .gunTower, at: .zero)
        destroyed.constructionCost = 100
        destroyed.currentHP = 0

        XCTAssertEqual(structures.dismantleHermesTowers(), 6)
        XCTAssertEqual(structures.hermesTowerCount, 0)
        XCTAssertEqual(structures.dismantleHermesTowers(), 0)
    }

    @MainActor
    func testLoadingFollowingDeploymentPreservesPaidCostAndRefundsOnce() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let original = GameScene.newGameScene()
        view.presentScene(original)
        defer { view.presentScene(nil) }
        let structures = try XCTUnwrap(original.findStructureManagerPublic())
        let tower = structures.addHermesTower(type: .gunTower, at: CGPoint(x: 320, y: 200))
        tower.constructionCost = 11
        let save = try XCTUnwrap(original.createSaveState(displayName: "Following deployment"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(save)) as? [String: Any])
        var hermes = try XCTUnwrap(json["hermes"] as? [String: Any])
        hermes["mode"] = "following"
        json["hermes"] = hermes
        let state = try JSONDecoder().decode(SavedGameState.self, from: JSONSerialization.data(withJSONObject: json))
        let restored = GameScene.newGameScene(fromSave: state)
        view.presentScene(restored)

        XCTAssertEqual(restored.findStructureManagerPublic()?.hermesTowerCount, 0)
        XCTAssertEqual(ResourceManager.shared.totalCollected, save.resources + 2)
        restored.setHermesMode(.following)
        XCTAssertEqual(ResourceManager.shared.totalCollected, save.resources + 2)

        let secondSave = try XCTUnwrap(restored.createSaveState(displayName: "After dismantling"))
        let reloaded = GameScene.newGameScene(fromSave: secondSave)
        view.presentScene(reloaded)
        XCTAssertEqual(ResourceManager.shared.totalCollected, save.resources + 2)
        XCTAssertTrue(try XCTUnwrap(reloaded.createSaveState(displayName: "Check")).towers.isEmpty)
    }

    func testOlderTowerSavesDecodeWithoutAPaidCost() throws {
        let saved = try XCTUnwrap(GunTower().toSavedTowerState(isHermesOwned: true))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        json.removeValue(forKey: "constructionCost")
        let restored = try JSONDecoder().decode(
            SavedTowerState.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
        XCTAssertNil(restored.constructionCost)
    }

    func testCorpsesBlockTowerPlacement() {
        let resources = ResourceManager.shared
        let previousTotal = resources.totalCollected
        resources.reset()
        defer {
            resources.reset()
            resources.restore(total: previousTotal)
        }
        let position = CGPoint(x: 500, y: 500)
        resources.spawnResource(amount: 10, at: position)
        let validator = PlacementValidator()
        validator.resourceManager = resources

        XCTAssertEqual(validator.validate(position: position), .overlapsResource)
        XCTAssertEqual(validator.validate(position: CGPoint(x: 600, y: 500)), .valid)
    }

    func testTowerFootprintMustStayInsideAllMapEdges() {
        let map = TMXMap(width: 4, height: 4, tileWidth: 48, tileHeight: 48)
        let renderer = TMXRenderer(map: map)
        let validator = PlacementValidator()
        validator.tmxRenderer = renderer

        for position in [
            CGPoint(x: 24, y: 24), CGPoint(x: 168, y: 24),
            CGPoint(x: 24, y: 168), CGPoint(x: 168, y: 168),
        ] {
            XCTAssertEqual(validator.validate(position: position), .valid, "Touching map edge: \(position)")
        }
        for position in [
            CGPoint(x: 23.5, y: 96), CGPoint(x: 168.5, y: 96),
            CGPoint(x: 96, y: 23.5), CGPoint(x: 96, y: 168.5),
        ] {
            XCTAssertEqual(validator.validate(position: position), .blockedByTerrain, "Outside map: \(position)")
        }
    }

    func testTowerCanTouchSolidTilesButCannotOverlapThem() {
        let map = TMXMap(width: 4, height: 4, tileWidth: 48, tileHeight: 48)
        let collision = TMXLayer(name: "Collision", width: 4, height: 4)
        collision.tiles = Array(repeating: 1, count: 16)
        collision.tiles[5] = 0
        map.layers = [collision]
        let renderer = TMXRenderer(map: map)
        let validator = PlacementValidator()
        validator.tmxRenderer = renderer

        XCTAssertEqual(validator.validate(position: CGPoint(x: 72, y: 120)), .valid)
        for position in [
            CGPoint(x: 71.5, y: 120), CGPoint(x: 72.5, y: 120),
            CGPoint(x: 72, y: 119.5), CGPoint(x: 72, y: 120.5),
        ] {
            XCTAssertEqual(
                validator.validate(position: position),
                .blockedByTerrain,
                "Overlaps solid tile: \(position)"
            )
        }
    }

    func testHermesLaserDealsDamageWhileInBuildModeAtNormalFrameRates() {
        for framesPerSecond in [30, 60, 120] {
            let hermes = Hermes()
            let enemy = Grunt()
            enemy.position = CGPoint(x: 200, y: 0)
            let initialHealth = enemy.currentHP

            hermes.updateCombat(deltaTime: Hermes.laserCooldownTime)
            hermes.setManualTarget(enemy)
            for _ in 0 ..< framesPerSecond * 3 / 2 {
                hermes.updateCombat(deltaTime: 1 / Double(framesPerSecond))
            }

            XCTAssertTrue(hermes.isInBuildMode)
            XCTAssertEqual(Double(initialHealth - enemy.currentHP), 37, accuracy: 1)
            XCTAssertEqual(hermes.attackRange, 450)
        }
    }

    func testLaserTowerDealsDamageAtNormalFrameRatesAndStopsWithoutATarget() {
        for framesPerSecond in [30, 60, 120] {
            let tower = LaserTower()
            let enemy = Grunt()
            enemy.position = CGPoint(x: 200, y: 0)
            let initialHealth = enemy.currentHP

            tower.update(deltaTime: tower.cooldownTime)
            tower.targeting.setManualTarget(enemy)
            for _ in 0 ..< framesPerSecond * 3 / 2 {
                tower.update(deltaTime: 1 / Double(framesPerSecond))
            }

            XCTAssertEqual(Double(initialHealth - enemy.currentHP), 30, accuracy: 1)
            enemy.position = CGPoint(x: 1_000, y: 0)
            tower.update(deltaTime: 1 / Double(framesPerSecond))
            XCTAssertFalse(tower.beam.isActive)
        }
    }

    func testHealTowerPrioritizesNathanielAndHealsOnlyOnePlayerPerTick() {
        let tower = HealTower()
        let nathaniel = Nathaniel()
        let hermes = Hermes()
        nathaniel.currentHP -= 6
        hermes.currentHP -= 50
        tower.healTargets = [hermes, nathaniel]

        tower.update(deltaTime: 1)
        XCTAssertEqual(nathaniel.currentHP, nathaniel.maxHP - 1)
        XCTAssertEqual(hermes.currentHP, hermes.maxHP - 50)

        tower.update(deltaTime: 1)
        XCTAssertEqual(nathaniel.currentHP, nathaniel.maxHP)
        XCTAssertEqual(hermes.currentHP, hermes.maxHP - 50)

        tower.update(deltaTime: 1)
        XCTAssertEqual(hermes.currentHP, hermes.maxHP - 45)
    }

    func testGunTowerUsesOriginalGunDamageAndCooldown() {
        let tower = GunTower()
        XCTAssertEqual(tower.sprite.size, CGSize(width: 48, height: 48))
        XCTAssertEqual(tower.gun.damage, 25)
        XCTAssertEqual(tower.gun.cooldownTime, 0.8)
        XCTAssertEqual(tower.attackRange, 500)
    }
}
