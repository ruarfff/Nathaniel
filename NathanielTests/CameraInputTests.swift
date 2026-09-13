//
//  CameraInputTests.swift
//  NathanielTests
//
//  Verifies that normal zoom input survives subsequent game frames.
//

@testable import Nathaniel
import SpriteKit
import XCTest

@MainActor
final class CameraInputTests: XCTestCase {
    func testStoryboardViewForwardsWheelEventsToTheGame() throws {
        let storyboard = NSStoryboard(name: "Main", bundle: Bundle(for: GameViewController.self))
        let controller = try XCTUnwrap(storyboard.instantiateInitialController() as? NSWindowController)
        let view = try XCTUnwrap(controller.window?.contentViewController?.view as? SKView)
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer {
            view.presentScene(nil)
            controller.close()
        }
        scene.setZoom(1)
        let event = try XCTUnwrap(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: 10,
            wheel2: 0,
            wheel3: 0
        ))
        // Exercise the view responder directly; do not post to the user's event queue.
        try view.scrollWheel(with: XCTUnwrap(NSEvent(cgEvent: event)))
        XCTAssertNotEqual(scene.camera?.xScale, 1)
    }

    func testHUDRemainsFixedInTheViewWhileZooming() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        let hud = try XCTUnwrap(scene.internalHUD)
        let pause = try XCTUnwrap(hud.childNode(withName: "pauseButton"))
        scene.setZoom(1)
        let center = view.convert(scene.convert(.zero, from: pause), from: scene)
        let edge = view.convert(scene.convert(CGPoint(x: 20, y: 0), from: pause), from: scene)
        for zoom: CGFloat in [0.5, 2] {
            scene.setZoom(zoom)
            let zoomedCenter = view.convert(scene.convert(.zero, from: pause), from: scene)
            let zoomedEdge = view.convert(scene.convert(CGPoint(x: 20, y: 0), from: pause), from: scene)
            XCTAssertEqual(zoomedCenter.x, center.x, accuracy: 0.001)
            XCTAssertEqual(zoomedCenter.y, center.y, accuracy: 0.001)
            XCTAssertEqual(zoomedEdge.x - zoomedCenter.x, edge.x - center.x, accuracy: 0.001)
        }
    }

    func testWheelAndPinchZoomSurviveCameraFollowUpdates() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        let camera = try XCTUnwrap(scene.camera)
        scene.update(1)
        scene.setZoom(1)

        _ = scene.handleScroll(deltaY: 10)
        let wheelScale = camera.xScale
        XCTAssertNotEqual(wheelScale, 1)
        scene.update(1.016)
        XCTAssertEqual(camera.xScale, wheelScale, accuracy: 0.001)

        scene.handlePinchZoom(scale: 0.8)
        let pinchScale = camera.xScale
        XCTAssertNotEqual(pinchScale, wheelScale)
        scene.update(1.032)
        XCTAssertEqual(camera.xScale, pinchScale, accuracy: 0.001)
    }
}
