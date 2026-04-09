# Spades Offline (iOS)

A lightweight **offline-only, ad-free** Spades implementation built with SwiftUI.

## What this includes

- 4-player Spades with you as player 1 and 3 bot players.
- Rule enforcement for:
  - Follow-suit behavior.
  - No leading spades until broken (unless only spades remain).
- Team scoring (P1/P3 vs P2/P4) with simple bids and hand scoring.
- No network calls, no analytics, and no ad SDK dependencies.

## Run on iOS

1. Open this folder in **Xcode 15+** on macOS.
2. Select the `SpadesOfflineApp` scheme.
3. Run on an iPhone simulator or device.

> The package includes a non-SwiftUI fallback `main` for Linux/CI environments, but the full app UI is for iOS/macOS via SwiftUI.

## Test

```bash
swift test
```
