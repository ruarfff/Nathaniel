//
//  AudioManager.swift
//  Nathaniel Shared
//
//  Manages audio playback for sound effects and background music.
//  Integrates with GameSettings for user preferences.
//

import AVFoundation
import SpriteKit

class AudioManager {
    // MARK: - Singleton

    static let shared = AudioManager()

    // MARK: - Sound Effect Types

    enum SoundEffect: String {
        case laser = "laserFire"
        case explosion
        case gunShot
        case rayGun
        case laserCannon
        case evilLaugh
        case arrowShot
        case laserBlast = "zap"
        case collect
    }

    // MARK: - Music Types

    enum Music: String {
        case menu = "menuMusic"
        case gameplay = "gameMusic"
        case gameplay2 = "gameMusic2"
        case gameplay3 = "gameMusic3"
    }

    // MARK: - Properties

    private var musicPlayer: AVAudioPlayer?
    private var requestedMusic: Music?
    private var shouldLoopMusic = true
    private let settings: GameSettings
    private let makeMusicPlayer: (URL) throws -> AVAudioPlayer

    /// Preloaded sound effect actions for better performance
    private var soundEffectActions: [SoundEffect: SKAction] = [:]

    // MARK: - Init

    init(
        settings: GameSettings = .shared,
        makeMusicPlayer: @escaping (URL) throws -> AVAudioPlayer = { try AVAudioPlayer(contentsOf: $0) }
    ) {
        self.settings = settings
        self.makeMusicPlayer = makeMusicPlayer
        self.preloadSoundEffects()
        self.configureAudioSession()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        #if os(iOS) || os(tvOS)
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("AudioManager: Failed to configure audio session: \(error)")
            }
        #endif
    }

    // MARK: - Sound Effects

    private func preloadSoundEffects() {
        for effect in [
            SoundEffect.laser,
            .explosion,
            .gunShot,
            .rayGun,
            .laserCannon,
            .evilLaugh,
            .arrowShot,
            .laserBlast,
            .collect,
        ] {
            let filename = "\(effect.rawValue).wav"
            self.soundEffectActions[effect] = SKAction.playSoundFileNamed(filename, waitForCompletion: false)
        }
    }

    /// Play a sound effect on the given node (typically the scene)
    /// - Parameters:
    ///   - effect: The sound effect to play
    ///   - node: The node to run the action on (usually the scene)
    func playSoundEffect(_ effect: SoundEffect, on node: SKNode) {
        guard self.settings.soundEffectsEnabled else { return }

        if let action = soundEffectActions[effect] {
            node.run(action)
        } else {
            // Fallback if not preloaded
            let filename = "\(effect.rawValue).wav"
            node.run(SKAction.playSoundFileNamed(filename, waitForCompletion: false))
        }
    }

    /// Convenience method to get the action for running on a node
    /// Useful when you want to combine with other actions
    func soundEffectAction(_ effect: SoundEffect) -> SKAction? {
        guard self.settings.soundEffectsEnabled else { return nil }
        return self.soundEffectActions[effect]
    }

    // MARK: - Background Music

    /// Play background music
    /// - Parameters:
    ///   - music: The music track to play
    ///   - loop: Whether to loop the music (default: true)
    func playMusic(_ music: Music, loop: Bool = true) {
        if self.requestedMusic != music {
            self.musicPlayer?.stop()
            self.musicPlayer = nil
        }
        self.requestedMusic = music
        self.shouldLoopMusic = loop
        self.onMusicSettingChanged()
    }

    /// Stop the currently playing music
    func stopMusic() {
        self.musicPlayer?.stop()
        self.musicPlayer = nil
        self.requestedMusic = nil
    }

    // MARK: - Settings Integration

    /// Apply the music setting to the latest track requested by a scene.
    func onMusicSettingChanged() {
        guard self.settings.musicEnabled else {
            self.musicPlayer?.pause()
            return
        }
        guard let music = requestedMusic else { return }

        if self.musicPlayer == nil {
            guard let url = Bundle.main.url(forResource: music.rawValue, withExtension: "mp3") else {
                print("AudioManager: Could not find music file: \(music.rawValue).mp3")
                return
            }

            do {
                self.musicPlayer = try self.makeMusicPlayer(url)
                self.musicPlayer?.volume = 0.7
                self.musicPlayer?.prepareToPlay()
            } catch {
                print("AudioManager: Failed to play music: \(error)")
                return
            }
        }

        self.musicPlayer?.numberOfLoops = self.shouldLoopMusic ? -1 : 0
        if self.musicPlayer?.isPlaying == false {
            self.musicPlayer?.play()
        }
    }
}
