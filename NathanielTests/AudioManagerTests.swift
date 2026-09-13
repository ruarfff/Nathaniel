//
//  AudioManagerTests.swift
//  NathanielTests
//
//  Checks music selection across muted scene changes without playing audio.
//

import AVFoundation
@testable import Nathaniel
import XCTest

@MainActor
final class AudioManagerTests: XCTestCase {
    func testEnablingMusicAfterMutedStartupPlaysRequestedGameplayTrack() throws {
        let settings = try self.makeSettings()
        var players: [SilentMusicPlayer] = []
        let manager = AudioManager(settings: settings) { url in
            let player = try SilentMusicPlayer(contentsOf: url)
            players.append(player)
            return player
        }

        manager.playMusic(.gameplay, loop: false)
        XCTAssertTrue(players.isEmpty)
        settings.musicEnabled = true
        manager.onMusicSettingChanged()

        let player = try XCTUnwrap(players.last)
        XCTAssertEqual(player.url?.lastPathComponent, "gameMusic.mp3")
        XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(player.numberOfLoops, 0)
    }

    func testMutedSceneChangeReplacesMenuMusicWhenEnabled() throws {
        let settings = try self.makeSettings()
        settings.musicEnabled = true
        var players: [SilentMusicPlayer] = []
        let manager = AudioManager(settings: settings) { url in
            let player = try SilentMusicPlayer(contentsOf: url)
            players.append(player)
            return player
        }
        manager.playMusic(.menu)
        let menuPlayer = try XCTUnwrap(players.last)
        XCTAssertTrue(menuPlayer.isPlaying)

        settings.musicEnabled = false
        manager.onMusicSettingChanged()
        XCTAssertFalse(menuPlayer.isPlaying)
        manager.playMusic(.gameplay)
        settings.musicEnabled = true
        manager.onMusicSettingChanged()

        let player = try XCTUnwrap(players.last)
        XCTAssertEqual(player.url?.lastPathComponent, "gameMusic.mp3")
        XCTAssertTrue(player.isPlaying)
        XCTAssertFalse(menuPlayer.isPlaying)
        XCTAssertEqual(player.numberOfLoops, -1)
    }

    func testRepeatedTogglesPreserveTheTrackAndPlaybackPosition() throws {
        let settings = try self.makeSettings()
        settings.musicEnabled = true
        var players: [SilentMusicPlayer] = []
        let manager = AudioManager(settings: settings) { url in
            let player = try SilentMusicPlayer(contentsOf: url)
            players.append(player)
            return player
        }
        manager.playMusic(.gameplay)
        let player = try XCTUnwrap(players.last)
        player.currentTime = 2

        for _ in 0 ..< 3 {
            settings.musicEnabled = false
            manager.onMusicSettingChanged()
            manager.onMusicSettingChanged()
            XCTAssertFalse(player.isPlaying)
            settings.musicEnabled = true
            manager.onMusicSettingChanged()
            manager.onMusicSettingChanged()
            XCTAssertTrue(player.isPlaying)
        }

        XCTAssertTrue(players.last === player)
        XCTAssertEqual(player.currentTime, 2, accuracy: 0.01)
    }

    private func makeSettings() throws -> GameSettings {
        let suite = "Nathaniel.AudioManagerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        self.addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return GameSettings(defaults: defaults)
    }
}

private final class SilentMusicPlayer: AVAudioPlayer {
    private var simulatedPlaying = false

    override var isPlaying: Bool {
        self.simulatedPlaying
    }

    override func play() -> Bool {
        self.simulatedPlaying = true
        return true
    }

    override func pause() {
        self.simulatedPlaying = false
    }

    override func stop() {
        self.simulatedPlaying = false
    }
}
