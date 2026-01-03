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
            context: GameActionContext
        ) -> ActionResult {
            switch name {
            case "selectNathaniel":
                self.selectNathaniel(context: context)
            case "selectHermes":
                self.selectHermes(context: context)
            case "moveNathaniel":
                self.moveNathaniel(params: params, context: context)
            case "targetEnemy":
                self.targetEnemy(params: params, context: context)
            case "toggleCharacter":
                self.toggleCharacter(context: context)
            default:
                .failure("Unknown character action: \(name)")
            }
        }

        // MARK: - Selection Actions

        private static func selectNathaniel(context: GameActionContext) -> ActionResult {
            guard let nathaniel = context.nathaniel else {
                return .failure("Nathaniel not found")
            }
            context.handleTap(at: nathaniel.position)
            return .success("Selected Nathaniel")
        }

        private static func selectHermes(context: GameActionContext) -> ActionResult {
            guard let hermes = context.hermes else {
                return .failure("Hermes not found")
            }
            context.handleTap(at: hermes.position)
            return .success("Selected Hermes")
        }

        private static func toggleCharacter(context: GameActionContext) -> ActionResult {
            context.toggleSelectedCharacter()
            return .success("Toggled character selection")
        }

        // MARK: - Movement Actions

        private static func moveNathaniel(
            params: [String: String]?,
            context: GameActionContext
        ) -> ActionResult {
            guard let point = ActionParams.parsePoint(from: params) else {
                return .failure("Missing x,y parameters")
            }
            context.handleMoveCommand(to: point)
            return .success("Moving Nathaniel to (\(point.x), \(point.y))")
        }

        // MARK: - Targeting Actions

        private static func targetEnemy(
            params: [String: String]?,
            context: GameActionContext
        ) -> ActionResult {
            guard let index = ActionParams.parseInt("index", from: params) else {
                return .failure("Missing index parameter")
            }
            guard let enemyManager = context.enemyManager else {
                return .failure("Enemy manager not found")
            }

            let aliveEnemies = enemyManager.enemies.filter(\.isAlive)
            guard index >= 0, index < aliveEnemies.count else {
                return .failure("Invalid enemy index")
            }

            let enemy = aliveEnemies[index]
            context.handleTap(at: enemy.position)
            return .success("Targeted enemy \(index)")
        }
    }

#endif
