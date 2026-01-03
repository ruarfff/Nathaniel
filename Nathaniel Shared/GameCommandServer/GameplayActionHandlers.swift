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
            context: GameActionContext
        ) -> ActionResult {
            switch name {
            case "restartLevel":
                .failure("Restart action not yet implemented")
            case "spawnEnemy":
                self.spawnEnemy(params: params, context: context)
            case "killAllEnemies":
                self.killAllEnemies(context: context)
            case "healPlayer":
                self.healPlayer(context: context)
            case "addResources":
                self.addResources(params: params, context: context)
            case "setHermesMode":
                self.setHermesMode(params: params, context: context)
            case "toggleHermesFollow":
                self.toggleHermesFollow(context: context)
            case "getHermesMode":
                self.getHermesMode(context: context)
            default:
                .failure("Unknown gameplay action: \(name)")
            }
        }

        // MARK: - Enemy Spawning

        private static func spawnEnemy(
            params: [String: String]?,
            context: GameActionContext
        ) -> ActionResult {
            guard let typeStr = ActionParams.parseString("type", from: params) else {
                return .failure("Missing type parameter (grunt, soldier, boss)")
            }
            guard let point = ActionParams.parsePoint(from: params) else {
                return .failure("Missing x,y parameters")
            }
            guard let enemyManager = context.enemyManager else {
                return .failure("Enemy manager not found")
            }

            let target = context.nathaniel

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
            default:
                return .failure("Unknown enemy type: \(typeStr). Use: grunt, soldier, or boss")
            }
        }

        // MARK: - Combat

        private static func killAllEnemies(context: GameActionContext) -> ActionResult {
            guard let enemyManager = context.enemyManager else {
                return .failure("Enemy manager not found")
            }
            let count = enemyManager.aliveCount
            for enemy in enemyManager.enemies where enemy.isAlive {
                enemy.currentHP = 0
            }
            return .success("Killed \(count) enemies")
        }

        private static func healPlayer(context: GameActionContext) -> ActionResult {
            if let nathaniel = context.nathaniel {
                nathaniel.currentHP = nathaniel.maxHP
                nathaniel.updateHealthBar()
            }
            if let hermes = context.hermes {
                hermes.currentHP = hermes.maxHP
                hermes.updateHealthBar()
            }
            return .success("Healed all players to full health")
        }

        // MARK: - Resources

        private static func addResources(
            params: [String: String]?,
            context: GameActionContext
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
            context: GameActionContext
        ) -> ActionResult {
            guard let modeStr = ActionParams.parseString("mode", from: params) else {
                return .failure("Missing mode parameter (following, independent)")
            }
            guard let hermes = context.hermes else {
                return .failure("Hermes not found")
            }
            // Can't change mode while locked
            guard hermes.mode != .locked else {
                return .failure("Cannot change mode while Hermes is locked (towers deployed)")
            }

            switch modeStr.lowercased() {
            case "following", "follow":
                hermes.enterFollowMode()
                return .success("Hermes set to following mode")
            case "independent", "build":
                hermes.enterIndependentMode()
                return .success("Hermes set to independent mode")
            default:
                return .failure("Unknown mode: \(modeStr). Use: following or independent")
            }
        }

        private static func toggleHermesFollow(context: GameActionContext) -> ActionResult {
            guard let hermes = context.hermes else {
                return .failure("Hermes not found")
            }
            guard hermes.mode != .locked else {
                return .failure("Cannot toggle mode while Hermes is locked (towers deployed)")
            }
            hermes.toggleMode()
            let newMode = hermes.mode == .following ? "following" : "independent"
            return .success("Hermes mode toggled to \(newMode)")
        }

        private static func getHermesMode(context: GameActionContext) -> ActionResult {
            guard let hermes = context.hermes else {
                return .failure("Hermes not found")
            }
            let modeString = switch hermes.mode {
            case .following: "following"
            case .independent: "independent"
            case .locked: "locked"
            }
            return .success("Hermes mode: \(modeString)")
        }
    }

#endif
