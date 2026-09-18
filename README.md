# Sausage Panic 🌭

A native iPhone arcade-game prototype: pull back, fling a glossy sausage across a chaotic kitchen, collect mustard, and avoid becoming breakfast.

## Open and play

1. Open `SausagePanic.xcodeproj` in Xcode 15 or newer on a Mac.
2. Select the **SausagePanic** scheme and an iPhone simulator, then Run.
3. For a physical phone, select your Apple development team under Signing & Capabilities, replace the example bundle ID with one you control, then Run.

Requires iOS 17 or newer. No downloaded art packs, dependencies, server, API keys or account are needed.

## Controls

- Touch and drag while resting on a pan. Drag down to increase height; left to increase horizontal speed. Drag up/right to reduce them.
- The dotted arc previews the launch. Release to jump. A quick tap uses a default launch.
- Land near a pan’s centre for perfect combos. Landings earn coins and add 1.5 seconds to the clock; mustard earns three coins and decorates the sausage.
- Later pans move, and forks bob through the flight path. Miss a landing or run out of time and the run ends.
- The pause button also contains sound/haptic settings. Backgrounding automatically pauses; resume explicitly.
- Earned coins unlock four characters. Abandoning a run does not bank its coins.

## Included

- SwiftUI menus, HUD, pause screen, score sharing and immediate retries.
- SceneKit 3D geometry, glossy materials, lighting, shadows and antialiasing; a 60 fps target.
- Fixed-step ballistic simulation, swept landing detection, course generation, moving pans, fork hazards and topping pickups.
- Local best scores, coin progression, cosmetic unlocks, synthesised WAV sound effects and haptics.
- UTC daily seeded course, with a separate local daily best. This is not an online leaderboard.
- Reduce Motion support for decorative rotations and wobble. The game still requires visually guided touch control; it is not fully VoiceOver-playable.
- Core simulation tests and a macOS GitHub Actions job to run tests and compile the simulator app.

## Visual quality / 4K

The sausage and kitchen use resolution-independent 3D geometry, not upscaled low-resolution sprites. Rendering follows the device screen. This prototype does not force a 3840×2160 framebuffer or include a 4K movie-art pipeline. The glossy 3D prototype establishes the style; custom animation and production art remain future work.

## Validation status

Source packaging, XML property lists, sound files and Xcode project references were checked during creation. Xcode and Swift are unavailable in the creation environment, so **the app has not been compiled or run on an iPhone/simulator, and the Swift tests have not yet executed**. Run the included workflow after uploading, then test on a physical device. Treat this as source for a prototype, not an App Store-ready build.

Commands on a Mac:

```sh
swift test
xcodebuild -project SausagePanic.xcodeproj -scheme SausagePanic \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## Before release

Complete a successful build, physical-device gameplay/performance testing and launch-tuning pass. Add the final app icon and screenshots, production art/audio, signing, App Store metadata, and any desired Game Center leaderboard integration. SceneKit is used for this compact prototype; consider a supported long-term rendering architecture before expanding production scope. There are no ads, subscriptions, purchases or analytics in this version.

## Development

The included GitHub Actions workflow runs core tests and compiles the simulator app on every push.

Project layout: `GameCore.swift` owns gameplay, `KitchenScene.swift` renders it, `GameStore.swift` handles lifecycle/progression, and `GameScreen.swift` supplies the interface. The Swift package tests only the portable game core; the Xcode project builds the full app.
