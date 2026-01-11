//
//  InputProvider.swift
//  Nathaniel
//
//  Platform-agnostic input handling abstraction
//

import SpriteKit

// MARK: - Input Event Types

/// Represents a platform-agnostic input event
enum InputEvent {
    /// Primary pointer down (tap on iOS, left-click on macOS)
    case pointerDown(location: CGPoint)

    /// Pointer moved during drag
    case pointerMoved(location: CGPoint)

    /// Pointer up (finger lift on iOS, mouse release on macOS)
    case pointerUp(location: CGPoint)

    /// Input cancelled (e.g., phone call interruption)
    case pointerCancelled

    /// Secondary click (right-click on macOS, not available on iOS)
    case secondaryClick(location: CGPoint)

    /// Scroll wheel input (macOS only)
    case scroll(deltaY: CGFloat)

    /// Keyboard key press (macOS only)
    case keyDown(keyCode: UInt16)
}

// MARK: - Input Provider Protocol

/// Protocol for objects that can receive unified input events
protocol InputReceiver: AnyObject {
    /// Handle an input event. Return true if the event was consumed.
    func handleInputEvent(_ event: InputEvent) -> Bool
}

// MARK: - Input Handling Scene Base Class

/// Base scene class that provides unified input handling across iOS and macOS.
///
/// Subclasses should override the `handle*` methods instead of platform-specific
/// methods like `touchesBegan` or `mouseDown`. This keeps all platform-specific
/// code in this single file.
///
/// Example usage:
/// ```swift
/// class MyScene: InputHandlingScene {
///     override func handlePointerDown(at location: CGPoint) -> Bool {
///         // Handle tap/click
///         return true
///     }
/// }
/// ```
class InputHandlingScene: SKScene {

    // MARK: - Unified Input Methods
    // Note: Methods are marked @objc dynamic to allow overriding from extensions

    /// Handle primary pointer down (tap on iOS, left-click on macOS).
    /// Override in subclasses. Return true if the event was handled.
    /// - Parameter location: The location in scene coordinates
    /// - Returns: True if the event was consumed
    @discardableResult
    @objc dynamic func handlePointerDown(at location: CGPoint) -> Bool {
        return false
    }

    /// Handle pointer movement during drag.
    /// Override in subclasses. Return true if the event was handled.
    /// - Parameter location: The location in scene coordinates
    /// - Returns: True if the event was consumed
    @discardableResult
    @objc dynamic func handlePointerMoved(to location: CGPoint) -> Bool {
        return false
    }

    /// Handle pointer up (finger lift on iOS, mouse release on macOS).
    /// Override in subclasses. Return true if the event was handled.
    /// - Parameter location: The location in scene coordinates
    /// - Returns: True if the event was consumed
    @discardableResult
    @objc dynamic func handlePointerUp(at location: CGPoint) -> Bool {
        return false
    }

    /// Handle cancelled input (e.g., interrupted by phone call).
    /// Override in subclasses.
    @objc dynamic func handlePointerCancelled() {
        // Override in subclass
    }

    /// Handle secondary click (right-click on macOS).
    /// This is not available on iOS.
    /// Override in subclasses. Return true if the event was handled.
    /// - Parameter location: The location in scene coordinates
    /// - Returns: True if the event was consumed
    @discardableResult
    @objc dynamic func handleSecondaryClick(at location: CGPoint) -> Bool {
        return false
    }

    /// Handle scroll wheel input (macOS only).
    /// Override in subclasses. Return true if the event was handled.
    /// - Parameter deltaY: The scroll delta (positive = scroll up)
    /// - Returns: True if the event was consumed
    @discardableResult
    @objc dynamic func handleScroll(deltaY: CGFloat) -> Bool {
        return false
    }

    /// Handle keyboard key press (macOS only).
    /// Override in subclasses. Return true if the event was handled.
    /// - Parameter keyCode: The key code of the pressed key
    /// - Returns: True if the event was consumed
    @discardableResult
    @objc dynamic func handleKeyDown(keyCode: UInt16) -> Bool {
        return false
    }
}

// MARK: - iOS Touch Handling

#if os(iOS) || os(tvOS)
extension InputHandlingScene {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        handlePointerDown(at: location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        handlePointerMoved(to: location)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        handlePointerUp(at: location)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        handlePointerCancelled()
    }
}
#endif

// MARK: - macOS Mouse/Keyboard Handling

#if os(OSX)
extension InputHandlingScene {
    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        handlePointerDown(at: location)
    }

    override func mouseDragged(with event: NSEvent) {
        let location = event.location(in: self)
        handlePointerMoved(to: location)
    }

    override func mouseUp(with event: NSEvent) {
        let location = event.location(in: self)
        handlePointerUp(at: location)
    }

    override func rightMouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        handleSecondaryClick(at: location)
    }

    override func scrollWheel(with event: NSEvent) {
        handleScroll(deltaY: event.scrollingDeltaY)
    }

    override func keyDown(with event: NSEvent) {
        handleKeyDown(keyCode: event.keyCode)
    }
}
#endif
