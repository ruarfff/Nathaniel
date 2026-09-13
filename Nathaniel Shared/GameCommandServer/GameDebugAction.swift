//
//  GameDebugAction.swift
//  Nathaniel Shared
//
//  Provides a small set of debug actions for test setup.
//

#if DEBUG
    import SpriteKit

    enum GameDebugAction: String, CaseIterable {
        case loadLevel, mainMenu, pause, resume
        case spawnEnemy, killAllEnemies, healPlayer, addResources, setHermesMode

        var parameters: String {
            switch self {
            case .loadLevel: "level: 1-5, or 0 for survival"
            case .spawnEnemy: "type: grunt|soldier|boss|spawner; x, y: world coordinates"
            case .addResources: "amount: positive integer"
            case .setHermesMode: "mode: following|independent"
            default: ""
            }
        }

        static func available(in scene: SKScene) -> [GameDebugAction] {
            scene is GameScene ? allCases : [.loadLevel, .mainMenu]
        }

        func execute(on scene: SKScene, params: [String: String]?) -> ActionResult {
            switch self {
            case .loadLevel:
                guard let value = params?["level"], let number = Int(value),
                      let config = LevelConfig.level(number)
                else {
                    return .failure("Invalid level; use 1-5, or 0 for survival")
                }
                guard let view = scene.view else { return .failure("Scene has no view") }
                view.presentScene(GameScene.newGameScene(levelConfig: config))
                return .success("Loaded level \(number)")
            case .mainMenu:
                guard let view = scene.view else { return .failure("Scene has no view") }
                view.presentScene(MainMenuScene.newMenuScene())
                return .success("Opened main menu")
            default:
                guard let game = scene as? GameScene else { return .failure("Action requires a game scene") }
                return self.execute(in: game, params: params)
            }
        }

        private func execute(in game: GameScene, params: [String: String]?) -> ActionResult {
            guard let level = game.internalLevelManager,
                  level.state == .playing || level.state == .paused
            else {
                return .failure("Load a level before changing gameplay state")
            }
            switch self {
            case .pause:
                game.pauseGame()
            case .resume:
                game.resumeGame()
            case .spawnEnemy:
                guard let type = params?["type"], ["grunt", "soldier", "boss", "spawner"].contains(type),
                      let xValue = params?["x"], let x = Double(xValue), x.isFinite,
                      let yValue = params?["y"], let y = Double(yValue), y.isFinite,
                      let enemies = game.internalEnemyManager
                else {
                    return .failure("Expected enemy type and finite x,y coordinates")
                }
                enemies.addEnemy(name: type.capitalized, at: CGPoint(x: x, y: y), target: game.internalNathaniel)
            case .killAllEnemies:
                for enemy in game.internalEnemyManager?.enemies ?? [] where enemy.isAlive {
                    enemy.currentHP = 0
                }
            case .healPlayer:
                for player in [game.internalNathaniel, game.internalHermes].compactMap(\.self) {
                    player.currentHP = player.maxHP
                    player.updateHealthBar()
                }
            case .addResources:
                guard let value = params?["amount"], let amount = Int(value), amount > 0,
                      !ResourceManager.shared.totalCollected.addingReportingOverflow(amount).overflow
                else {
                    return .failure("Expected a positive amount that fits the resource total")
                }
                ResourceManager.shared.addResources(amount)
            case .setHermesMode:
                guard let mode = params?["mode"], ["following", "independent"].contains(mode),
                      level.state == .playing, game.internalHermes?.isAlive == true
                else {
                    return .failure("Expected following or independent while Hermes is alive and playing")
                }
                game.setHermesMode(mode == "following" ? .following : .independent)
            case .loadLevel, .mainMenu:
                return .failure("Navigation requires a scene view")
            }
            return .success()
        }
    }
#endif
