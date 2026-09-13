#if DEBUG

//
    //  BuildingActionHandlers.swift
    //  Nathaniel Shared
//
    //  Action handlers for building and tower management.
//

    import SpriteKit

    /// Handles tower construction and build menu actions.
    enum BuildingActionHandlers: GameActionHandler {
        static let actionNames = [
            "toggleBuildMenu",
            "buildTower",
            "getTowerInfo",
        ]

        static func execute(
            name: String,
            params: [String: String]?,
            context: GameActionContext
        ) -> ActionResult {
            switch name {
            case "toggleBuildMenu":
                self.toggleBuildMenu(context: context)
            case "buildTower":
                self.buildTower(params: params, context: context)
            case "getTowerInfo":
                self.getTowerInfo(context: context)
            default:
                .failure("Unknown building action: \(name)")
            }
        }

        // MARK: - Build Menu

        private static func toggleBuildMenu(context: GameActionContext) -> ActionResult {
            context.toggleBuildMenu()
            return .success("Build menu \(context.isBuildMenuVisible ? "opened" : "closed")")
        }

        // MARK: - Tower Building

        private static func buildTower(
            params: [String: String]?,
            context: GameActionContext
        ) -> ActionResult {
            guard let typeStr = ActionParams.parseString("type", from: params) else {
                return .failure("Missing type parameter (gun, laser, heal)")
            }
            guard let hermes = context.hermes else {
                return .failure("Hermes not found")
            }
            guard let structMgr = context.structureManager else {
                return .failure("StructureManager not found")
            }

            // Determine tower type
            let towerType: TowerType
            switch typeStr.lowercased() {
            case "gun", "guntower":
                towerType = .gunTower
            case "laser", "lasertower":
                towerType = .laserTower
            case "heal", "healtower":
                towerType = .healTower
            default:
                return .failure("Unknown tower type: \(typeStr). Use: gun, laser, or heal")
            }

            // Check affordability
            guard ResourceManager.shared.canAfford(towerType.cost) else {
                return .failure(
                    "Not enough resources. Need \(towerType.cost), have \(ResourceManager.shared.totalCollected)"
                )
            }

            // Determine position (near Hermes if not specified)
            let position: CGPoint = if let point = ActionParams.parsePoint(from: params) {
                point
            } else {
                // Place 80 pixels to the right of Hermes
                CGPoint(x: hermes.position.x + 80, y: hermes.position.y)
            }

            guard hermes.isInBuildMode else {
                return .failure("Hermes must be in build mode")
            }
            guard context.scene?.buildTower(type: towerType, at: position) == true else {
                return .failure("Tower placement failed: position blocked or resources unavailable")
            }

            return .success(
                "Built \(towerType.displayName) at (\(Int(position.x)), \(Int(position.y))). Towers: \(structMgr.hermesTowerCount)"
            )
        }

        // MARK: - Tower Info

        private static func getTowerInfo(context: GameActionContext) -> ActionResult {
            guard let structMgr = context.structureManager else {
                return .failure("StructureManager not found")
            }
            let count = structMgr.hermesTowerCount
            return .success("Towers: \(count)")
        }
    }

#endif
