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
            context: GameActionContext
        ) -> ActionResult {
            switch name {
            case "getCombatState":
                self.getCombatState(context: context)
            case "getNathanielTarget":
                self.getNathanielTarget(context: context)
            case "getHermesTarget":
                self.getHermesTarget(context: context)
            case "getHermesCombatState":
                self.getHermesCombatState(context: context)
            case "getTowerTargets":
                self.getTowerTargets(context: context)
            case "waitForCombat":
                self.waitForCombat(context: context)
            default:
                .failure("Unknown debug action: \(name)")
            }
        }

        // MARK: - Combat State

        private static func getCombatState(context: GameActionContext) -> ActionResult {
            var state: [String: String] = [:]

            // Nathaniel targeting
            if let nathaniel = context.nathaniel {
                if let target = nathaniel.currentTarget as? Enemy {
                    let index = context.enemyManager?.enemies.firstIndex(where: { $0 === target }) ?? -1
                    state["nathanielTarget"] = "enemy_\(index)"
                } else {
                    state["nathanielTarget"] = "none"
                }
                state["nathanielManualOverride"] = nathaniel.manualTargetOverride != nil ? "true" : "false"
                state["nathanielTargetingBehavior"] = "\(nathaniel.targetingBehavior)"
            }

            // Hermes targeting
            if let hermes = context.hermes {
                if let target = hermes.currentTarget as? Enemy {
                    let index = context.enemyManager?.enemies.firstIndex(where: { $0 === target }) ?? -1
                    state["hermesTarget"] = "enemy_\(index)"
                } else {
                    state["hermesTarget"] = "none"
                }
                state["hermesManualOverride"] = hermes.manualTargetOverride != nil ? "true" : "false"
                state["hermesTargetingBehavior"] = "\(hermes.targetingBehavior)"
                state["hermesIsFiring"] = hermes.isFiring ? "true" : "false"
                let modeString = switch hermes.mode {
                case .following: "following"
                case .independent: "independent"
                case .locked: "locked"
                }
                state["hermesMode"] = modeString
            }

            // Tower targeting
            if let structMgr = context.structureManager {
                var towerTargets: [String] = []
                for (idx, tower) in structMgr.structures.enumerated() where tower.isActive {
                    if let target = tower.currentTarget as? Enemy {
                        let enemyIdx = context.enemyManager?.enemies.firstIndex(where: { $0 === target }) ?? -1
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

        private static func getNathanielTarget(context: GameActionContext) -> ActionResult {
            guard let nathaniel = context.nathaniel else {
                return .failure("Nathaniel not found")
            }
            if let target = nathaniel.currentTarget as? Enemy {
                let index = context.enemyManager?.enemies.firstIndex(where: { $0 === target }) ?? -1
                let manual = nathaniel.manualTargetOverride != nil ? " (manual)" : " (auto)"
                return .success("enemy_\(index)\(manual) at (\(Int(target.position.x)), \(Int(target.position.y)))")
            }
            return .success("none")
        }

        // MARK: - Hermes Target

        private static func getHermesTarget(context: GameActionContext) -> ActionResult {
            guard let hermes = context.hermes else {
                return .failure("Hermes not found")
            }
            if let target = hermes.currentTarget as? Enemy {
                let index = context.enemyManager?.enemies.firstIndex(where: { $0 === target }) ?? -1
                let manual = hermes.manualTargetOverride != nil ? " (manual)" : " (auto)"
                return .success("enemy_\(index)\(manual) at (\(Int(target.position.x)), \(Int(target.position.y)))")
            }
            return .success("none")
        }

        // MARK: - Hermes Combat State

        private static func getHermesCombatState(context: GameActionContext) -> ActionResult {
            guard let hermes = context.hermes else {
                return .failure("Hermes not found")
            }
            var state: [String] = []
            let modeString = switch hermes.mode {
            case .following: "following"
            case .independent: "independent"
            case .locked: "locked"
            }
            state.append("mode=\(modeString)")
            state.append("isFiring=\(hermes.isFiring)")
            state.append("behavior=\(hermes.targetingBehavior)")
            if let target = hermes.currentTarget as? Enemy {
                let index = context.enemyManager?.enemies.firstIndex(where: { $0 === target }) ?? -1
                state.append("target=enemy_\(index)")
            } else {
                state.append("target=none")
            }
            state.append("manualOverride=\(hermes.manualTargetOverride != nil)")
            return .success(state.joined(separator: "; "))
        }

        // MARK: - Tower Targets

        private static func getTowerTargets(context: GameActionContext) -> ActionResult {
            guard let structMgr = context.structureManager else {
                return .failure("StructureManager not found")
            }
            var results: [String] = []
            for (idx, tower) in structMgr.structures.enumerated() where tower.isActive {
                let typeName = tower.name
                if let target = tower.currentTarget as? Enemy {
                    let enemyIdx = context.enemyManager?.enemies.firstIndex(where: { $0 === target }) ?? -1
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

        private static func waitForCombat(context: GameActionContext) -> ActionResult {
            // Synchronous check - caller should poll if needed
            let hasNathanielTarget = context.nathaniel?.currentTarget != nil
            let hasHermesTarget = context.hermes?.currentTarget != nil
            let enemyCount = context.enemyManager?.aliveCount ?? 0
            return .success(
                "nathanielHasTarget=\(hasNathanielTarget); hermesHasTarget=\(hasHermesTarget); enemies=\(enemyCount)"
            )
        }
    }

#endif
