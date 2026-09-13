#if DEBUG

//
    //  GameplayActionHandlers.swift
    //  Nathaniel Shared
//
    //  Action handlers for gameplay: spawning, combat, resources, Hermes mode.
//

    import SpriteKit

    /// Handles gameplay actions: enemy spawning, combat, resources, Hermes mode
    enum GameplayActionHandlers: GameActionHandler {
        static let actionNames = [
            "restartLevel",
            "spawnEnemy",
            "killAllEnemies",
            "healPlayer",
            "addResources",
            "setHermesMode",
            "toggleHermesFollow",
            "getHermesMode",
        ]

        static func execute(
            name: String,
            params: [String: String]?,
            scene: GameScene
        ) -> ActionResult {
            switch name {
            case "restartLevel":
                .failure("Restart action not yet implemented")
            case "spawnEnemy":
                self.spawnEnemy(params: params, scene: scene)
            case "killAllEnemies":
                self.killAllEnemies(scene: scene)
            case "healPlayer":
                self.healPlayer(scene: scene)
            case "addResources":
                self.addResources(params: params, scene: scene)
            case "setHermesMode":
                self.setHermesMode(params: params, scene: scene)
            case "toggleHermesFollow":
                self.toggleHermesFollow(scene: scene)
            case "getHermesMode":
                self.getHermesMode(scene: scene)
            default:
                .failure("Unknown gameplay action: \(name)")
            }
        }

        // MARK: - Enemy Spawning

        private static func spawnEnemy(
            params: [String: String]?,
            scene: GameScene
        ) -> ActionResult {
            guard let typeStr = ActionParams.parseString("type", from: params) else {
                return .failure("Missing type parameter (grunt, soldier, boss, spawner)")
            }
            guard let point = ActionParams.parsePoint(from: params) else {
                return .failure("Missing x,y parameters")
            }
            guard let enemyManager = scene.internalEnemyManager else {
                return .failure("Enemy manager not found")
            }

            let target = scene.internalNathaniel

            // Spawn the appropriate enemy type
            switch typeStr.lowercased() {
            case "grunt", "gr":
                enemyManager.addEnemy(name: "Grunt", at: point, target: target)
                return .success("Spawned Grunt at (\(point.x), \(point.y))")
            case "soldier", "so":
                enemyManager.addEnemy(name: "Soldier", at: point, target: target)
                return .success("Spawned Soldier at (\(point.x), \(point.y))")
            case "boss", "bo":
                enemyManager.addEnemy(name: "Boss", at: point, target: target)
                return .success("Spawned Boss at (\(point.x), \(point.y))")
            case "spawner", "sp":
                enemyManager.addEnemy(name: "Spawner", at: point, target: target)
                return .success("Spawned Spawner")
            default:
                return .failure("Unknown enemy type: \(typeStr). Use: grunt, soldier, or boss")
            }
        }

        // MARK: - Combat

        private static func killAllEnemies(scene: GameScene) -> ActionResult {
            guard let enemyManager = scene.internalEnemyManager else {
                return .failure("Enemy manager not found")
            }
            let count = enemyManager.aliveCount
            for enemy in enemyManager.enemies where enemy.isAlive {
                enemy.currentHP = 0
            }
            return .success("Killed \(count) enemies")
        }

        private static func healPlayer(scene: GameScene) -> ActionResult {
            if let nathaniel = scene.internalNathaniel {
                nathaniel.currentHP = nathaniel.maxHP
                nathaniel.updateHealthBar()
            }
            if let hermes = scene.internalHermes {
                hermes.currentHP = hermes.maxHP
                hermes.updateHealthBar()
            }
            return .success("Healed all players to full health")
        }

        // MARK: - Resources

        private static func addResources(
            params: [String: String]?,
            scene: GameScene
        ) -> ActionResult {
            guard let amount = ActionParams.parseInt("amount", from: params) else {
                return .failure("Missing amount parameter")
            }
            ResourceManager.shared.addResources(amount)
            return .success("Added \(amount) resources")
        }

        // MARK: - Hermes Mode

        private static func setHermesMode(
            params: [String: String]?,
            scene: GameScene
        ) -> ActionResult {
            guard let modeStr = ActionParams.parseString("mode", from: params) else {
                return .failure("Missing mode parameter (following, independent)")
            }
            guard let hermes = scene.internalHermes else {
                return .failure("Hermes not found")
            }
            guard scene.internalLevelManager?.state == .playing, hermes.isAlive else {
                return .failure("Hermes can only change mode during play")
            }

            switch modeStr.lowercased() {
            case "following", "follow":
                scene.setHermesMode(.following)
                return .success("Hermes set to following mode")
            case "independent", "build":
                scene.setHermesMode(.independent)
                return .success("Hermes set to independent mode")
            default:
                return .failure("Unknown mode: \(modeStr). Use: following or independent")
            }
        }

        private static func toggleHermesFollow(scene: GameScene) -> ActionResult {
            guard let hermes = scene.internalHermes else {
                return .failure("Hermes not found")
            }
            guard scene.internalLevelManager?.state == .playing, hermes.isAlive else {
                return .failure("Hermes can only change mode during play")
            }
            scene.toggleHermesFollowMode()
            let newMode = hermes.mode == .following ? "following" : "independent"
            return .success("Hermes mode toggled to \(newMode)")
        }

        private static func getHermesMode(scene: GameScene) -> ActionResult {
            guard let hermes = scene.internalHermes else {
                return .failure("Hermes not found")
            }
            let modeString = switch hermes.mode {
            case .following: "following"
            case .independent: "independent"
            }
            return .success("Hermes mode: \(modeString)")
        }
    }

#endif
