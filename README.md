# Ari Assistant

A cross-platform AI assistant app built with SwiftUI, SwiftData, CloudKit, OnboardingKit, and FlexStore.

## Platforms

- iOS
- iPadOS
- macOS

## What It Does

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
- `aiassistant.storekit` local StoreKit configuration
- `StoreKitSchemaNotes.md` StoreKit notes

## Monetization Setup

Defined in `aiassistant/Models/Monetization.swift`:

- Weekly subscription
- Monthly subscription
- Yearly subscription
- Lifetime unlock: 
- Free tier daily limit: `10` messages/day

Policy links:

- Privacy: https://gomez1112.github.io/Legal/privacy/
- Terms: https://gomez1112.github.io/Legal/terms/

## Running the App

1. Open `aiassistant.xcodeproj` in Xcode.
2. Select the desired destination (iOS, iPadOS, or macOS).
3. Build and run.

## Local StoreKit Testing

1. In Xcode, choose your run scheme.
2. Edit Scheme > Run > Options.
3. Set **StoreKit Configuration** to `aiassistant.storekit`.
4. Run and test weekly/monthly/yearly/lifetime purchases locally.

## Notes

- The app uses SwiftData with a CloudKit-backed configuration and falls back to local storage if CloudKit container load fails.
- macOS uses native Settings scene integration.
- Subscription paywall uses FlexStore `SubscriptionPassStoreView`.
