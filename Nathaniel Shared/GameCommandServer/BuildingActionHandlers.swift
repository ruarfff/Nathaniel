#if DEBUG

//
    //  BuildingActionHandlers.swift
    //  Nathaniel Shared
//
    //  Action handlers for building and tower management.
//

    import SpriteKit

    /// Handles building-related actions: towers, build menu, Hermes release
    enum BuildingActionHandlers: GameActionHandler {
        static let actionNames = [
            "toggleBuildMenu",
            "buildTower",
            "releaseHermes",
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
            case "releaseHermes":
                self.releaseHermes(context: context)
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

            // Validate position is within build radius
            guard TowerConfig.isWithinBuildRange(towerPosition: position, hermesPosition: hermes.position) else {
                return .failure("Position out of build range (max \(TowerConfig.buildRadius) from Hermes)")
            }

            // Spend resources and build
            guard ResourceManager.shared.spendResources(towerType.cost) else {
                return .failure("Failed to spend resources")
            }

            structMgr.addHermesTower(type: towerType, at: position)

            // Lock Hermes if this is the first tower
            if structMgr.hermesTowerCount == 1 {
                hermes.lock()
            }

            return .success(
                "Built \(towerType.displayName) at (\(Int(position.x)), \(Int(position.y))). Towers: \(structMgr.hermesTowerCount)"
            )
        }

        // MARK: - Hermes Release

        private static func releaseHermes(context: GameActionContext) -> ActionResult {
            guard let hermes = context.hermes else {
                return .failure("Hermes not found")
            }
            guard let structMgr = context.structureManager else {
                return .failure("StructureManager not found")
            }

            let towerCount = structMgr.hermesTowerCount
            guard towerCount > 0 else {
                return .failure("No towers deployed")
            }

            let recoupAmount = structMgr.destroyAllHermesTowers(camera: context.cameraNode)

            // Unlock Hermes if locked
            if hermes.mode == .locked {
                hermes.unlock()
            }

            return .success("Released Hermes. Destroyed \(towerCount) towers, recouped \(recoupAmount) resources")
        }

        // MARK: - Tower Info

        private static func getTowerInfo(context: GameActionContext) -> ActionResult {
            guard let structMgr = context.structureManager else {
                return .failure("StructureManager not found")
            }
            let count = structMgr.hermesTowerCount
            let recoup = structMgr.potentialRecoupAmount
            return .success("Towers: \(count), potential recoup: \(recoup)")
        }
    }

#endif
