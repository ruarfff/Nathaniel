//
//  GameViewController.swift
//  Nathaniel iOS
//
//  Created by Ruairi O'Brien on 11/29/25.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let scene: SKScene
        if SmokeTestRunner.isEnabled {
            scene = GameScene.newGameScene(levelConfig: .levelOne)
        } else {
            scene = MainMenuScene.newMenuScene()
        }

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
        // Note: Use object: nil to receive notifications from any sender,
        // as scenes may post with different view references
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneDidChange(_:)),
            name: .skViewDidPresentScene,
            object: nil
        )
        #endif

        // Add pinch gesture for zoom
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.state == .changed else { return }

        // Get the current scene and check if it's a GameScene
        if let skView = view as? SKView,
           let gameScene = skView.scene as? GameScene {
            gameScene.handlePinchZoom(scale: gesture.scale)
        }

        // Reset scale to get incremental changes
        gesture.scale = 1.0
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // Force landscape for this game (matches original 800x480 design)
        return .landscape
    }

    override var prefersStatusBarHidden: Bool {
        return true
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
