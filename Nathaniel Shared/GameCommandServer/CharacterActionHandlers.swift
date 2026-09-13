#if DEBUG

//
    //  CharacterActionHandlers.swift
    //  Nathaniel Shared
//
    //  Action handlers for character selection and movement.
//

    import SpriteKit

    /// Handles character-related actions: selection, movement, targeting
    enum CharacterActionHandlers: GameActionHandler {
        static let actionNames = [
            "selectNathaniel",
            "selectHermes",
            "moveNathaniel",
            "targetEnemy",
            "toggleCharacter",
        ]

        static func execute(
            name: String,
            params: [String: String]?,
            scene: GameScene
        ) -> ActionResult {
            switch name {
            case "selectNathaniel":
                self.selectNathaniel(scene: scene)
            case "selectHermes":
                self.selectHermes(scene: scene)
            case "moveNathaniel":
                self.moveNathaniel(params: params, scene: scene)
            case "targetEnemy":
                self.targetEnemy(params: params, scene: scene)
            case "toggleCharacter":
                self.toggleCharacter(scene: scene)
            default:
                .failure("Unknown character action: \(name)")
            }
        }

        // MARK: - Selection Actions

        private static func selectNathaniel(scene: GameScene) -> ActionResult {
            guard let nathaniel = scene.internalNathaniel else {
                return .failure("Nathaniel not found")
            }
            scene.handleTap(at: nathaniel.position)
            return .success("Selected Nathaniel")
        }

        private static func selectHermes(scene: GameScene) -> ActionResult {
            guard let hermes = scene.internalHermes else {
                return .failure("Hermes not found")
            }
            scene.handleTap(at: hermes.position)
            return .success("Selected Hermes")
        }

        private static func toggleCharacter(scene: GameScene) -> ActionResult {
            scene.toggleSelectedCharacter()
            return .success("Toggled character selection")
        }

        // MARK: - Movement Actions

        private static func moveNathaniel(
            params: [String: String]?,
            scene: GameScene
        ) -> ActionResult {
            guard let point = ActionParams.parsePoint(from: params) else {
                return .failure("Missing x,y parameters")
            }
            scene.handleMoveCommand(to: point)
            return .success("Moving Nathaniel to (\(point.x), \(point.y))")
        }

        // MARK: - Targeting Actions

        private static func targetEnemy(
            params: [String: String]?,
            scene: GameScene
        ) -> ActionResult {
            guard let index = ActionParams.parseInt("index", from: params) else {
                return .failure("Missing index parameter")
            }
            guard let enemyManager = scene.internalEnemyManager else {
                return .failure("Enemy manager not found")
            }

            let aliveEnemies = enemyManager.enemies.filter(\.isAlive)
            guard index >= 0, index < aliveEnemies.count else {
                return .failure("Invalid enemy index")
            }

            let enemy = aliveEnemies[index]
            scene.handleTap(at: enemy.position)
            return .success("Targeted enemy \(index)")
        }
    }

#endif
