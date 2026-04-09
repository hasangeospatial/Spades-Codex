# Spades Offline (iOS)

A lightweight **no-ads** Spades implementation built with SwiftUI, with offline solo play and Game Center multiplayer options.

## What this includes

- 4-player Spades with you as player 1 and 3 bot players.
- Three bot difficulty levels: Easy, Medium, Hard.
- Rule enforcement for:
  - Follow-suit behavior.
  - No leading spades until broken (unless only spades remain).
- Team scoring (P1/P3 vs P2/P4) with simple bids and hand scoring.
- Optional Game Center online matchmaking controls in the app UI (iOS).
- No ads, analytics SDKs, or ad network dependencies.

## Run on iOS

1. Open this folder in **Xcode 15+** on macOS.
2. Select the `SpadesOfflineApp` scheme.
3. Run on an iPhone simulator or device.
4. Choose **Solo Offline** or **Online Multiplayer**, and set bot difficulty as needed.

> The package includes a non-SwiftUI fallback `main` for Linux/CI environments, but the full app UI is for iOS/macOS via SwiftUI.

## Test

```bash
swift test
```
