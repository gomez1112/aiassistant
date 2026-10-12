# OS 27.1 readiness

Checked October 12, 2026. The app supports iOS/iPadOS/macOS 27.0 and newer, including 27.1. A 27.0 minimum preserves support for the installed Mac SDK and existing OS 27 devices. The installed iOS SDK is 27.1; the installed Mac SDK is 27.0 and the host runs macOS 27.0.1. Actual macOS 27.1 runtime testing remains outstanding.

## Toolchain and configuration

- Swift compiler 6.4; Swift 6 language mode for the app and both test targets.
- Approachable Concurrency and complete strict concurrency checking enabled per target in Debug and Release.
- Actual Bitrig builds used `/Applications/Xcode-beta.app` for the iOS 27.1 SDK. The implementation uses APIs present in the released OS 27 SDK, without beta-only API adoption or earlier-OS compatibility code.
- iPhone, iPad, and native Mac support preserved. No third-party dependencies added or updated.
- Launch screen, background remote notifications, CloudKit container entitlements, Mac sandbox, selected-file access, and outgoing network access configured.

## Private Cloud Compute

- `com.apple.developer.private-cloud-compute` is `true` in the app entitlements file and is included by the app target.
- App ID `com.transfinite.aiassistant` has the `PRIVATE_CLOUD_COMPUTE` capability enabled in Apple’s developer account; verified through App Store Connect API.
- A fresh Apple-issued Mac development profile was generated using the existing Apple Development certificate and the same three registered Macs. It contains PCC, the correct App ID/team, and `iCloud.com.transfinite.aiassistant`.
- Mac Debug builds select `aiassistant PCC macOS Development 2026-10-12` explicitly because automatic signing continued selecting the old profile without PCC. The profile is installed in the local Xcode provisioning-profile directory and kept outside the repository. iOS Debug retains automatic signing. Release now selects the PCC-capable App Store profiles described below. To return Mac Debug to automatic signing once Xcode refreshes its managed profile, remove the three SDK-specific signing overrides in the app target’s Debug configuration.
- The signed Mac app contains the PCC entitlement, CloudKit container, sandbox, and outgoing-network entitlement. `codesign --verify --deep --strict` passed with normal access to the certificate trust store.
- The iOS simulator’s generated simulated-entitlements file contains PCC; simulator signatures are not evidence of device/distribution provisioning.
- Settings offers a persisted, device-local PCC choice. Cloud inference is opt-in and is used consistently for chat, transforms, and library summaries. No request silently switches from local to cloud processing. Availability and Apple’s separate per-user quota are checked, with actionable network/quota/context-size errors.
- A real PCC round trip on a provisioned device or distribution build has not yet been verified. The Mac UI was launched using isolated, in-memory marketing fixtures. This does not verify a live PCC request or production persistence.

## CloudKit production

Container: `iCloud.com.transfinite.aiassistant` (team `88QL9VPLMY`). The production schema was exported successfully and contains all five model record types: `CD_Thread`, `CD_Message`, `CD_Artifact`, `CD_LibraryItem`, and `CD_UserPreferences`.

The current production export confirms `CD_Message.CD_statusRaw` is deployed as a STRING field. It matches the additive message-status field versioned in `CloudKitSchema.ckdb`. The previously identified production schema gap is resolved; all five app model types are present. This was verified again after the version 1.2 distribution signing check, without changing production records or the project's schema file.

Actual two-device CloudKit sync and production record writes remain unverified. An exported schema and in-memory tests do not prove sync.

## Fixed issues

- Cancelled chat, transform, and summary operations cannot clear the state of a newer request or write results to a deleted source.
- Switching chats cancels the prior generation and updates the source of coaching actions; windows own independent conversation and generation state.
- In-flight requests are persisted as pending and do not consume the completed-message quota. Failed/stopped/pending turns are excluded from future model prompts.
- Failed/cancelled model requests and recoverable storage initialization/save errors no longer crash Debug builds or report a successful save.
- Output Studio cancels stale results when its format changes, respects current premium access, and keeps its sheet open when a save fails.
- Saving a reply after switching conversations retains its original source thread.
- PDF/OCR extraction uses a dedicated worker for synchronous framework I/O, supports cancellation, bounds image decoding, and applies image orientation.
- Chat header accessibility identifiers restored, navigation remains available while typing, mode selection uses a native menu Picker, and UI checks handle adaptive selectors.
- Paid features describe actual behavior: file uploads replace the unsupported faster-CloudKit-sync promise, and PCC quota limits are disclosed.

## Verification

- iOS simulator build: passed with the iOS 27.1 SDK.
- Signed native Mac Debug build: passed with the macOS 27.0 SDK.
- Mac signature and PCC entitlements: verified.
- Unit tests on iPhone Duo / iOS 27.1: 22 passed.
- PCC Settings control on iPhone Duo: enabling and disabling changed both processing status and privacy labels immediately. On-device processing was restored after the check.
- Affected UI regression tests on iPhone Duo / iOS 27.1: 3 passed, 0 failed, with no compiler warnings. These cover sending a reply, mode selection/message actions, and switching chats while the composer is focused.

Bitrig/Xcode sometimes reports an App Intents metadata-extraction warning because the app has no App Intents dependency. No framework was added solely to suppress that tooling warning.

## Version 1.2 distribution check

- App version 1.2; source/capture build 7. The final distribution builds are iOS 2 and macOS 10. Both app versions and all three custom pages are waiting for App Review. Version 1.1.0 was already released and remains intact.
- Debug and Release builds passed for iOS Simulator and native macOS. The capture flag is absent from Info.plist, and fixture/capture code is excluded from Release builds.
- Automatic Mac Release signing selected the old profile without PCC. Apple-issued `aiassistant PCC macOS App Store 2026-10-12` and `aiassistant PCC iOS App Store 2026-10-12` profiles now include PCC and use the existing Apple Distribution certificate. Profiles are installed locally, outside git.
- Release selects these profiles and the existing distribution identity with per-SDK overrides. Separate iOS/macOS distribution entitlements select production APNs and CloudKit. To return to automatic signing after Xcode refreshes its managed profiles, remove the Release SDK-specific signing identity/style/profile overrides; preserve the distribution entitlements.
- The Mac App Store Release app's signature passed verification and its signed entitlements include PCC, production APNs, production CloudKit, and the intended container. The iOS App Store profile was verified to contain PCC. Both final distribution archives uploaded successfully and passed Apple's processing. A real PCC round trip remains unverified.
- Capture testing found SwiftUI's navigation comparison-type crash when opening an output under the Mac sidebar. The output stack now uses NavigationPath. The complete five-scene Mac flow ran successfully afterward.
- 22 unit tests and 2 UI regressions passed on iPhone 18 Pro / iOS 27.0. The new UI regression switches tabs, opens saved study cards, flips a card, and advances the deck. The second preserves an unsent draft across tab switching and rotation.
- [Marketing assets and upload report](marketing/1.2/README.md) records all 45 accepted media assets, 72 placements, and 3 custom pages included in the iOS submission. [Submission records](marketing/1.2/submission.json) record the final builds, review IDs, and states verified on October 12, 2026. Both platforms retain automatic release after approval; no release has been published by this work.
- The user-supplied support and privacy URLs are saved across all listing localizations, and both review records use `transfinite@transfinite.us` and `+19143158248`. Settings and the paywall use the new privacy URL. Both web pages returned HTTP 200. The first Mac submission was withdrawn and both binaries were replaced to include that code change before final submission. The website still needs the optional PCC disclosure described in [this proposed wording](marketing/1.2/privacy-disclosure.md); the website is outside this repository and was not edited.
- Production was re-exported after the distribution signing check: all five model types exist, and `CD_Message.CD_statusRaw` is present. Actual two-device sync and production record writes remain unverified. Production entitlements alone do not prove sync.
