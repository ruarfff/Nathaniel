//
//  GameViewController.swift
//  Nathaniel macOS
//
//  Created by Ruairi O'Brien on 11/29/25.
//

import Cocoa
import GameplayKit
import SpriteKit

class GameViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Start with the main menu
        let scene = MainMenuScene.newMenuScene()

        // Present the scene
        guard let skView = self.view as? SKView else {
            fatalError("GameViewController requires an SKView in the storyboard")
        }
        skView.presentScene(scene)

        skView.ignoresSiblingOrder = true

        skView.showsFPS = true
        skView.showsNodeCount = true
    }
}
