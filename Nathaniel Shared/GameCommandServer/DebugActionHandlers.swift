#if DEBUG

//
    //  DebugActionHandlers.swift
    //  Nathaniel Shared
//
    //  Action handlers for debug/targeting state inspection.
//

    import SpriteKit

    /// Handles debug and targeting inspection actions
    enum DebugActionHandlers: GameActionHandler {
        static let actionNames = [
            "getCombatState",
            "getNathanielTarget",
            "getHermesTarget",
            "getHermesCombatState",
            "getTowerTargets",
            "waitForCombat",
        ]

        static func execute(
            name: String,
            params: [String: String]?,
            scene: GameScene
        ) -> ActionResult {
            switch name {
            case "getCombatState":
                self.getCombatState(scene: scene)
            case "getNathanielTarget":
                self.getNathanielTarget(scene: scene)
            case "getHermesTarget":
                self.getHermesTarget(scene: scene)
            case "getHermesCombatState":
                self.getHermesCombatState(scene: scene)
            case "getTowerTargets":
                self.getTowerTargets(scene: scene)
            case "waitForCombat":
                self.waitForCombat(scene: scene)
            default:
                .failure("Unknown debug action: \(name)")
            }
        }

        // MARK: - Combat State

        private static func getCombatState(scene: GameScene) -> ActionResult {
            var state: [String: String] = [:]

            // Nathaniel targeting
            if let nathaniel = scene.internalNathaniel {
                if let target = nathaniel.currentTarget as? Enemy {
                    let index = scene.internalEnemyManager?.enemies.firstIndex(where: { $0 === target }) ?? -1
                    state["nathanielTarget"] = "enemy_\(index)"
                } else {
                    state["nathanielTarget"] = "none"
                }
                state["nathanielManualOverride"] = nathaniel.targeting.manualTargetOverride != nil ? "true" : "false"
                state["nathanielTargetingBehavior"] = "\(nathaniel.targeting.behavior)"
            }

            // Hermes targeting
            if let hermes = scene.internalHermes {
                if let target = hermes.currentTarget as? Enemy {
                    let index = scene.internalEnemyManager?.enemies.firstIndex(where: { $0 === target }) ?? -1
                    state["hermesTarget"] = "enemy_\(index)"
                } else {
                    state["hermesTarget"] = "none"
                }
                state["hermesManualOverride"] = hermes.targeting.manualTargetOverride != nil ? "true" : "false"
                state["hermesTargetingBehavior"] = "\(hermes.targeting.behavior)"
                state["hermesIsFiring"] = hermes.isFiring ? "true" : "false"
                let modeString = switch hermes.mode {
                case .following: "following"
                case .independent: "independent"
                }
                state["hermesMode"] = modeString
            }

            // Tower targeting
            if let structMgr = scene.internalStructureManager {
                var towerTargets: [String] = []
                for (idx, tower) in structMgr.structures.enumerated() where tower.isActive {
                    if let target = tower.currentTarget {
                        let enemyIdx = scene.internalEnemyManager?.enemies.firstIndex(where: { $0 === target }) ?? -1
                        towerTargets.append("tower_\(idx)->enemy_\(enemyIdx)")
                    } else {
                        towerTargets.append("tower_\(idx)->none")
                    }
                }
                state["towerTargets"] = towerTargets.joined(separator: ",")
                state["towerCount"] = "\(structMgr.structures.filter(\.isActive).count)"
            }

            let stateStr = state.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "; ")
            return .success(stateStr)
        }

        // MARK: - Nathaniel Target

        private static func getNathanielTarget(scene: GameScene) -> ActionResult {
            guard let nathaniel = scene.internalNathaniel else {
                return .failure("Nathaniel not found")
            }
            if let target = nathaniel.currentTarget as? Enemy {
                let index = scene.internalEnemyManager?.enemies.firstIndex(where: { $0 === target }) ?? -1
                let manual = nathaniel.targeting.manualTargetOverride != nil ? " (manual)" : " (auto)"
                return .success("enemy_\(index)\(manual) at (\(Int(target.position.x)), \(Int(target.position.y)))")
            }
            return .success("none")
        }

        // MARK: - Hermes Target

        private static func getHermesTarget(scene: GameScene) -> ActionResult {
            guard let hermes = scene.internalHermes else {
                return .failure("Hermes not found")
            }
            if let target = hermes.currentTarget as? Enemy {
                let index = scene.internalEnemyManager?.enemies.firstIndex(where: { $0 === target }) ?? -1
                let manual = hermes.targeting.manualTargetOverride != nil ? " (manual)" : " (auto)"
                return .success("enemy_\(index)\(manual) at (\(Int(target.position.x)), \(Int(target.position.y)))")
            }
            return .success("none")
        }

        // MARK: - Hermes Combat State

        private static func getHermesCombatState(scene: GameScene) -> ActionResult {
            guard let hermes = scene.internalHermes else {
                return .failure("Hermes not found")
            }
            var state: [String] = []
            let modeString = switch hermes.mode {
            case .following: "following"
            case .independent: "independent"
            }
            state.append("mode=\(modeString)")
            state.append("isFiring=\(hermes.isFiring)")
            state.append("behavior=\(hermes.targeting.behavior)")
            if let target = hermes.currentTarget as? Enemy {
                let index = scene.internalEnemyManager?.enemies.firstIndex(where: { $0 === target }) ?? -1
                state.append("target=enemy_\(index)")
            } else {
                state.append("target=none")
            }
            state.append("manualOverride=\(hermes.targeting.manualTargetOverride != nil)")
            return .success(state.joined(separator: "; "))
        }

        // MARK: - Tower Targets

        private static func getTowerTargets(scene: GameScene) -> ActionResult {
            guard let structMgr = scene.internalStructureManager else {
                return .failure("StructureManager not found")
            }
            var results: [String] = []
            for (idx, tower) in structMgr.structures.enumerated() where tower.isActive {
                let typeName = tower.name
                if let target = tower.currentTarget {
                    let enemyIdx = scene.internalEnemyManager?.enemies.firstIndex(where: { $0 === target }) ?? -1
                    results.append("\(typeName)_\(idx)->enemy_\(enemyIdx)")
                } else {
                    results.append("\(typeName)_\(idx)->none")
                }
            }
            if results.isEmpty {
                return .success("No active towers")
            }
            return .success(results.joined(separator: "; "))
        }

        // MARK: - Wait for Combat

        private static func waitForCombat(scene: GameScene) -> ActionResult {
            // Synchronous check - caller should poll if needed
            let hasNathanielTarget = scene.internalNathaniel?.currentTarget != nil
            let hasHermesTarget = scene.internalHermes?.currentTarget != nil
            let enemyCount = scene.internalEnemyManager?.aliveCount ?? 0
            return .success(
                "nathanielHasTarget=\(hasNathanielTarget); hermesHasTarget=\(hasHermesTarget); enemies=\(enemyCount)"
            )
        }
    }

#endif
