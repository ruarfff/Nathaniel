# Character Toggle Feature - Implementation Plan

**Beads Issue:** Nathaniel-7uj
**Status:** In Progress

## Overview

Add UI controls to toggle between Nathaniel and Hermes characters on both iOS (touch) and macOS (keyboard + mouse). When switching, the camera should smoothly center on the newly selected character.

## Current State

### What Already Works
- **macOS Space key**: Already toggles between characters (keyCode 49 in `GameScene.swift:1068`)
- **Tap-to-select**: Tapping on a character selects them
- **Camera follow**: Camera already smoothly follows `selectedCharacter` via `updateCameraFollow()`
- **Selection logic**: `selectCharacter()` method handles all selection state changes

### What's Missing
- **iOS toggle UI**: No touch-friendly button to switch characters
- **macOS visual indicator**: No on-screen hint that Space toggles characters
- **Instant camera snap**: When toggling, camera should snap/animate to new character position (not just lerp slowly)

## Implementation Plan

### Phase 1: Add Character Toggle Button to HUD

**File:** [HUD.swift](../Nathaniel%20Shared/HUD.swift)

Add a character toggle button near the bottom-center "SELECTED" panel. This will be visible on both platforms.

**Changes:**
1. Add new properties:
   ```swift
   private var characterToggleButton: SKNode?
   private let toggleButtonName = "characterToggleButton"
   var onCharacterToggle: (() -> Void)?
   ```

2. Create `showCharacterToggleButton()` method:
   - Position: To the right of the bottom "SELECTED" container
   - Style: Match existing button aesthetics (rounded rect, white border)
   - Content: Two-headed arrow icon or "SWITCH" text
   - Always visible (both characters are always available)

3. Add touch handling in `handleTouch(at:)`:
   - Check if toggle button was tapped
   - Call `onCharacterToggle?()` callback

**UI Mockup:**
```
┌─────────────────────────────────────────────────────────────┐
│  LIVES ❤❤❤                              RESOURCES         │
│  SCORE 1250                                   30           │
│                                                             │
│                                                             │
│                         (game area)                         │
│                                                             │
│                                                             │
│  [BUILD]        SELECTED              [⇄ SWITCH]           │
│                NATHANIEL                                    │
└─────────────────────────────────────────────────────────────┘
```

### Phase 2: Wire Up Toggle Callback in GameScene

**File:** [GameScene.swift](../Nathaniel%20Shared/GameScene.swift)

**Changes:**
1. In `setupHUD()`, add callback:
   ```swift
   hud.onCharacterToggle = { [weak self] in
       self?.toggleSelectedCharacter()
   }
   ```

2. Add `toggleSelectedCharacter()` method:
   ```swift
   private func toggleSelectedCharacter() {
       if selectedCharacter === nathaniel {
           if let hermes = hermes {
               selectCharacter(hermes)
           }
       } else {
           if let nathaniel = nathaniel {
               selectCharacter(nathaniel)
           }
       }
   }
   ```

3. Refactor Space key handler to use `toggleSelectedCharacter()`:
   ```swift
   case 49: // Space key
       toggleSelectedCharacter()
   ```

### Phase 3: Improve Camera Centering on Toggle

**File:** [GameScene.swift](../Nathaniel%20Shared/GameScene.swift)

Currently the camera lerps slowly (10% per frame). When explicitly toggling, we want faster/instant centering.

**Options:**

**Option A: Instant Snap**
- Set camera position directly to new character's position
- Simple but jarring

**Option B: Quick Animation (Recommended)**
- Animate camera to new position over 0.3-0.5 seconds
- Use `SKAction.move(to:duration:)` with easing
- During animation, disable normal follow lerp

**Implementation for Option B:**

1. Add property to track if camera is animating:
   ```swift
   private var isCameraAnimating = false
   ```

2. Modify `selectCharacter()` to trigger camera animation:
   ```swift
   func selectCharacter(_ character: Character) {
       // ... existing selection logic ...

       // Animate camera to new character
       animateCameraTo(character.position)
   }
   ```

3. Add camera animation method:
   ```swift
   private func animateCameraTo(_ position: CGPoint) {
       guard let renderer = mapRenderer else { return }

       isCameraAnimating = true

       // Clamp target position to map bounds
       let clampedPos = clampCameraPosition(position, renderer: renderer)

       let moveAction = SKAction.move(to: clampedPos, duration: 0.3)
       moveAction.timingMode = .easeInEaseOut

       cameraNode.run(moveAction) { [weak self] in
           self?.isCameraAnimating = false
       }
   }
   ```

4. Modify `updateCameraFollow()` to skip during animation:
   ```swift
   private func updateCameraFollow() {
       guard !isCameraAnimating else { return }
       // ... existing lerp logic ...
   }
   ```

### Phase 4: Add Keyboard Hint for macOS (Optional Enhancement)

**File:** [HUD.swift](../Nathaniel%20Shared/HUD.swift)

On macOS only, show "(Space)" hint near the toggle button or in the SELECTED panel.

```swift
#if os(macOS)
// Add small hint label: "Press Space"
#endif
```

This is low priority - the button works on both platforms.

## File Changes Summary

| File | Changes |
|------|---------|
| [HUD.swift](../Nathaniel%20Shared/HUD.swift) | Add toggle button, callback, touch handling |
| [GameScene.swift](../Nathaniel%20Shared/GameScene.swift) | Add `toggleSelectedCharacter()`, wire callback, camera animation |

## Testing Plan

### iOS Simulator
1. Build and run on iOS Simulator
2. Verify toggle button appears in bottom HUD area
3. Tap toggle button - should switch between Nathaniel/Hermes
4. Verify camera animates to new character
5. Verify "SELECTED" label updates to show new character name

### macOS
1. Build and run on macOS
2. Verify toggle button appears
3. Test button click
4. Test Space key still works
5. Verify camera animation on toggle

### Edge Cases
- Toggle when one character is dead
- Toggle while camera is already animating
- Toggle during build menu open (should close build menu)

## Questions for User

1. **Button style**: Should the toggle button be always visible, or only when Nathaniel is selected (since Hermes already has BUILD button)?

2. **Visual design**: Simple text "SWITCH" or graphical icon (arrows)?

3. **Camera animation**: Quick animation (0.3s) or instant snap?

## Dependencies

None - this feature is self-contained.

## Risks

- **Low risk**: All building blocks exist (selection logic, camera follow, button patterns in HUD)
- **Minimal change surface**: Only touches HUD.swift and GameScene.swift
