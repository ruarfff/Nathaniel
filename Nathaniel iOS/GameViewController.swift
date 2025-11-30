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
        
        let scene = GameScene.newGameScene()

        // Present the scene
        let skView = self.view as! SKView
        skView.presentScene(scene)
        
        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // Force landscape for this game (matches original 800x480 design)
        return .landscapeRight
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
