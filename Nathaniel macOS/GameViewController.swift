//
//  GameViewController.swift
//  Nathaniel macOS
//
//  Created by Ruairi O'Brien on 11/29/25.
//

import Cocoa
import SpriteKit
import GameplayKit

class GameViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Start with the main menu
        let scene = MainMenuScene.newMenuScene()

        // Present the scene
        let skView = self.view as! SKView
        skView.presentScene(scene)
        
        skView.ignoresSiblingOrder = true
        
        skView.showsFPS = true
        skView.showsNodeCount = true

        #if DEBUG
        // Wire up command server delegate
        updateCommandServerDelegate(scene: scene)

        // Observe scene changes to update the delegate
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneDidChange(_:)),
            name: .skViewDidPresentScene,
            object: skView
        )
        #endif
    }

    #if DEBUG
    @objc private func sceneDidChange(_ notification: Notification) {
        if let skView = view as? SKView, let scene = skView.scene {
            updateCommandServerDelegate(scene: scene)
        }
    }

    private func updateCommandServerDelegate(scene: SKScene) {
        if let delegate = scene as? GameCommandDelegate {
            GameCommandServer.shared.delegate = delegate
            print("[GameViewController] Command server delegate set to \(type(of: scene))")
        } else {
            print("[GameViewController] Scene \(type(of: scene)) does not conform to GameCommandDelegate")
        }
    }
    #endif
}

