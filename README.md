# Ari Assistant

A cross-platform AI assistant app built with SwiftUI, SwiftData, CloudKit, OnboardingKit, and FlexStore.

## Platforms

- iOS and iPadOS 27.0 or later (built and tested with the iOS 27.1 SDK)
- macOS 27.0 or later (compatible with macOS 27.1)

## What It Does

- Optional Apple Private Cloud Compute for chat, transforms, and summaries, with a device-local processing preference
- Multi-mode chat experience (General, Write, Summarize, Explain, Plan, Brainstorm)
- Output generation and saved artifacts
- Personal library for reusable source material
- Local-first SwiftData persistence with CloudKit sync
- Subscription + lifetime monetization using StoreKit 2 and FlexStore
- Onboarding flow powered by OnboardingKit

## Tech Stack

- SwiftUI
- SwiftData
- CloudKit
- StoreKit 2
- [OnboardingKit](https://github.com/gomez1112/OnboardingKit)
- [FlexStore](https://github.com/gomez1112/FlexStore)

## Project Structure

- `aiassistant/` app source
- `aiassistantTests/` unit tests
- `aiassistantUITests/` UI tests
- `ai.storekit` local StoreKit configuration
- `StoreKitSchemaNotes.md` StoreKit notes

## Monetization Setup

Defined in `aiassistant/Models/Monetization.swift`:

- Weekly subscription
- Monthly subscription
- Yearly subscription
- Lifetime unlock: one-time purchase
- Free tier daily limit: `3` messages/day

Policy links:

- Privacy: https://gomez1112.github.io/Legal/privacy/
- Terms: https://gomez1112.github.io/Legal/terms/

## Building and Running in Bitrig

Build with `bitrig build -destination all --keep-going`. Bitrig launches the iOS app in its built-in simulator. Use Run on… for your own device or Mac.

The project uses Swift 6 language mode, Swift 6.4, strict concurrency checking, and Approachable Concurrency. It uses released OS 27 APIs; no beta-only APIs or earlier-OS compatibility paths were added.

The shared scheme already selects `ai.storekit` for local purchase testing. TestFlight and App Store builds use real App Store Connect products instead.

See [RELEASE_READINESS.md](RELEASE_READINESS.md) for PCC signing verification, the production CloudKit schema status, and remaining release checks.

## Notes

- The app uses SwiftData with a CloudKit-backed configuration and falls back to local storage if CloudKit container load fails.
- macOS uses native Settings scene integration.
- The custom subscription paywall uses the existing FlexStore service. Ari+ removes the app’s chat cap; Apple’s separate PCC quota still applies.
