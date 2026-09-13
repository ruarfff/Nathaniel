//
//  SaveSlotSelectorTests.swift
//  NathanielTests
//
//  Verifies save slot presentation and dismissal through the shared overlay.
//

@testable import Nathaniel
import SpriteKit
import XCTest

@MainActor
final class SaveSlotSelectorTests: XCTestCase {
    func testSelectorRetainsItsLayoutAndActiveMode() throws {
        let selector = SaveSlotSelector(size: CGSize(width: 800, height: 480))
        XCTAssertTrue(selector.isHidden)
        XCTAssertFalse(selector.isVisible)
        XCTAssertEqual(selector.animationDuration, 0.2)
        XCTAssertEqual(try XCTUnwrap(selector.overlayBackground).fillColor.alphaComponent, 0.8, accuracy: 0.001)

        selector.show(mode: .save)
        let panel = try XCTUnwrap(selector.menuPanel)
        let background = try XCTUnwrap(panel.children.first as? SKShapeNode)
        XCTAssertEqual(background.path?.boundingBox.size, CGSize(width: 320, height: 300))
        XCTAssertEqual((panel.childNode(withName: "title") as? SKLabelNode)?.text, "SAVE GAME")
        XCTAssertEqual(panel.children.filter { $0.name?.hasPrefix("slot_") == true }.count, 3)
        XCTAssertTrue(selector.isVisible)
        XCTAssertFalse(selector.isHidden)

        selector.show(mode: .load)

        XCTAssertEqual(selector.mode, .save)
        XCTAssertEqual((panel.childNode(withName: "title") as? SKLabelNode)?.text, "SAVE GAME")
        XCTAssertEqual(panel.children.filter { $0.name?.hasPrefix("slot_") == true }.count, 3)
    }

    func testHiddenSelectorIgnoresTouchesAndCompletesHideImmediately() {
        let selector = SaveSlotSelector(size: CGSize(width: 800, height: 480))
        var didComplete = false

        XCTAssertFalse(selector.handleTouch(at: .zero))
        selector.hide { didComplete = true }

        XCTAssertTrue(didComplete)
        XCTAssertFalse(selector.isVisible)
    }

    func testSlotAndCancelCallbacksRunWhenSelected() async throws {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 480)
        let view = SKView(frame: frame)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        let scene = SKScene(size: frame.size)
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        view.presentScene(scene)
        window.orderFront(nil)
        defer {
            view.presentScene(nil)
            window.orderOut(nil)
        }
        let selector = SaveSlotSelector(size: frame.size)
        scene.addChild(selector)
        let selected = expectation(description: "Slot selected before the fade completes")
        var selectedSlot: Int?
        selector.onSlotSelected = { [weak selector] slot in
            selectedSlot = slot
            XCTAssertEqual(slot, 2)
            XCTAssertEqual(selector?.isHidden, false)
            XCTAssertEqual(selector?.isVisible, false)
            selected.fulfill()
        }
        selector.show(mode: .save)
        let slot = try XCTUnwrap(selector.menuPanel?.childNode(withName: "slot_2"))

        XCTAssertTrue(selector.handleTouch(at: scene.convert(.zero, from: slot)))
        XCTAssertFalse(selector.isVisible)
        XCTAssertEqual(selectedSlot, 2)
        await fulfillment(of: [selected], timeout: 3)

        let cancelled = expectation(description: "Cancel before the fade completes")
        selector.onCancel = { [weak selector] in
            XCTAssertEqual(selector?.isHidden, false)
            XCTAssertEqual(selector?.isVisible, false)
            cancelled.fulfill()
        }
        selector.show(mode: .load)
        XCTAssertEqual((selector.menuPanel?.childNode(withName: "title") as? SKLabelNode)?.text, "LOAD GAME")
        let cancel = try XCTUnwrap(selector.menuPanel?.childNode(withName: "cancelButton"))

        XCTAssertTrue(selector.handleTouch(at: scene.convert(.zero, from: cancel)))
        await fulfillment(of: [cancelled], timeout: 3)
    }
}
