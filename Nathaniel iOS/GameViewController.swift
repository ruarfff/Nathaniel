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

        // Start with the main menu
        let scene = MainMenuScene.newMenuScene()

        // Present the scene
        let skView = self.view as! SKView
        skView.presentScene(scene)

        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true

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
}
