#if DEBUG

//
    //  SettingsActionHandlers.swift
    //  Nathaniel Shared
//
    //  Action handlers for settings menu interactions.
//

    import SpriteKit

    /// Handles settings menu actions
    enum SettingsActionHandlers: GameActionHandler {
        static let actionNames = [
            "settingsMenuIsVisible",
            "openSettings",
            "showSettingsMenu",
            "closeSettings",
            "hideSettingsMenu",
            "toggleSoundEffects",
            "toggleMusic",
            "getSoundEffectsEnabled",
            "getMusicEnabled",
            "getCurrentSettings",
            "getSettings",
            "setSoundEffects",
            "setMusic",
            "settingsMenuTapBack",
        ]

        static func execute(
            name: String,
            params: [String: String]?,
            context: GameActionContext
        ) -> ActionResult {
            switch name {
            case "settingsMenuIsVisible":
                guard let settingsMenu = context.settingsMenu else {
                    return .failure("Settings menu not found")
                }
                return .success("settingsMenuIsVisible: \(settingsMenu.isVisible)")

            case "openSettings", "showSettingsMenu":
                guard let settingsMenu = context.settingsMenu else {
                    return .failure("Settings menu not found")
                }
                settingsMenu.show()
                return .success("Settings menu opened")

            case "closeSettings", "hideSettingsMenu":
                guard let settingsMenu = context.settingsMenu else {
                    return .failure("Settings menu not found")
                }
                settingsMenu.hide()
                return .success("Settings menu closed")

            case "toggleSoundEffects":
                let current = GameSettings.shared.soundEffectsEnabled
                GameSettings.shared.soundEffectsEnabled = !current
                return .success("Sound effects: \(!current)")

            case "toggleMusic":
                let current = GameSettings.shared.musicEnabled
                GameSettings.shared.musicEnabled = !current
                // Apply immediately
                if !current {
                    AudioManager.shared.resumeMusic()
                } else {
                    AudioManager.shared.pauseMusic()
                }
                return .success("Music: \(!current)")

            case "getSoundEffectsEnabled":
                return .success("soundEffectsEnabled: \(GameSettings.shared.soundEffectsEnabled)")

            case "getMusicEnabled":
                return .success("musicEnabled: \(GameSettings.shared.musicEnabled)")

            case "getCurrentSettings", "getSettings":
                let soundEffects = GameSettings.shared.soundEffectsEnabled
                let music = GameSettings.shared.musicEnabled
                return .success("soundEffects: \(soundEffects), music: \(music)")

            case "setSoundEffects":
                guard let enabled = ActionParams.parseBool("enabled", from: params) else {
                    return .failure("Missing or invalid 'enabled' parameter (true/false)")
                }
                GameSettings.shared.soundEffectsEnabled = enabled
                return .success("Sound effects set to: \(enabled)")

            case "setMusic":
                guard let enabled = ActionParams.parseBool("enabled", from: params) else {
                    return .failure("Missing or invalid 'enabled' parameter (true/false)")
                }
                GameSettings.shared.musicEnabled = enabled
                if enabled {
                    AudioManager.shared.resumeMusic()
                } else {
                    AudioManager.shared.pauseMusic()
                }
                return .success("Music set to: \(enabled)")

            case "settingsMenuTapBack":
                guard let settingsMenu = context.settingsMenu else {
                    return .failure("Settings menu not found")
                }
                guard settingsMenu.isVisible else {
                    return .failure("Settings menu is not visible")
                }
                settingsMenu.hide {
                    settingsMenu.onBack?()
                }
                return .success("Tapped Back button")

            default:
                return .failure("Unknown settings action: \(name)")
            }
        }
    }

#endif
