#if DEBUG

//
    //  PauseActionHandlers.swift
    //  Nathaniel Shared
//
    //  Action handlers for pause menu interactions.
//

    import SpriteKit

    /// Handles pause menu actions
    enum PauseActionHandlers: GameActionHandler {
        static let actionNames = [
            "pause",
            "resume",
            "isPaused",
            "showPauseMenu",
            "hidePauseMenu",
            "pauseMenuIsVisible",
            "pauseMenuTapResume",
            "pauseMenuTapSettings",
            "pauseMenuTapSaveGame",
            "pauseMenuTapExitToMenu",
            "pauseMenuConfirmExit",
            "pauseMenuCancelExit",
            "exitToMenu",
        ]

        static func execute(
            name: String,
            params: [String: String]?,
            context: GameActionContext
        ) -> ActionResult {
            switch name {
            case "pause":
                context.pauseGame()
                return .success("Game paused")

            case "resume":
                context.resumeGame()
                return .success("Game resumed")

            case "isPaused":
                guard let levelManager = context.levelManager else {
                    return .failure("Level manager not found")
                }
                return .success("isPaused: \(levelManager.isPaused)")

            case "showPauseMenu":
                context.pauseGame()
                return .success("Pause menu shown")

            case "hidePauseMenu":
                context.resumeGame()
                return .success("Pause menu hidden")

            case "pauseMenuIsVisible":
                guard let pauseMenu = context.pauseMenu else {
                    return .failure("Pause menu not found")
                }
                return .success("pauseMenuIsVisible: \(pauseMenu.isVisible)")

            case "pauseMenuTapResume":
                return self.tapPauseMenuButton(context: context) { $0.onResume?() }

            case "pauseMenuTapSettings":
                return self.tapPauseMenuButton(context: context) { $0.onSettings?() }

            case "pauseMenuTapSaveGame":
                return self.tapPauseMenuButton(context: context) { $0.onSaveGame?() }

            case "pauseMenuTapExitToMenu":
                guard let pauseMenu = context.pauseMenu else {
                    return .failure("Pause menu not found")
                }
                guard pauseMenu.isVisible else {
                    return .failure("Pause menu is not visible")
                }
                pauseMenu.showExitConfirmation()
                return .success("Tapped Exit to Menu button (showing confirmation)")

            case "pauseMenuConfirmExit":
                guard let pauseMenu = context.pauseMenu else {
                    return .failure("Pause menu not found")
                }
                guard pauseMenu.isShowingConfirmation else {
                    return .failure("Exit confirmation is not showing")
                }
                pauseMenu.onExitToMenu?()
                return .success("Confirmed exit to menu")

            case "pauseMenuCancelExit":
                guard let pauseMenu = context.pauseMenu else {
                    return .failure("Pause menu not found")
                }
                guard pauseMenu.isShowingConfirmation else {
                    return .failure("Exit confirmation is not showing")
                }
                pauseMenu.hideConfirmation()
                return .success("Cancelled exit")

            case "exitToMenu":
                return self.exitToMenu(params: params, context: context)

            default:
                return .failure("Unknown pause action: \(name)")
            }
        }

        // MARK: - Helpers

        private static func tapPauseMenuButton(
            context: GameActionContext,
            action: (PauseMenu) -> Void
        ) -> ActionResult {
            guard let pauseMenu = context.pauseMenu else {
                return .failure("Pause menu not found")
            }
            guard pauseMenu.isVisible else {
                return .failure("Pause menu is not visible")
            }
            action(pauseMenu)
            return .success("Tapped button")
        }

        private static func exitToMenu(
            params: [String: String]?,
            context: GameActionContext
        ) -> ActionResult {
            let skipConfirm = params?["skipConfirm"] == "true"
            guard let pauseMenu = context.pauseMenu else {
                return .failure("Pause menu not found")
            }

            if skipConfirm {
                pauseMenu.onExitToMenu?()
                return .success("Exiting to main menu")
            } else {
                if !pauseMenu.isVisible {
                    context.pauseGame()
                }
                pauseMenu.showExitConfirmation()
                return .success("Exit confirmation shown (tap pauseMenuConfirmExit to confirm)")
            }
        }
    }

#endif
