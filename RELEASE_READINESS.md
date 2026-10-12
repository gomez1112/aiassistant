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
- Mac Debug builds select `aiassistant PCC macOS Development 2026-10-12` explicitly because automatic signing continued selecting the old profile without PCC. The profile is installed in the local Xcode provisioning-profile directory and kept outside the repository. iOS and distribution signing retain their existing automatic configuration. To return Mac Debug to automatic signing once Xcode refreshes its managed profile, remove the three SDK-specific signing overrides in the app target’s Debug configuration.
- The signed Mac app contains the PCC entitlement, CloudKit container, sandbox, and outgoing-network entitlement. `codesign --verify --deep --strict` passed with normal access to the certificate trust store.
- The iOS simulator’s generated simulated-entitlements file contains PCC; simulator signatures are not evidence of device/distribution provisioning.
- Settings offers a persisted, device-local PCC choice. Cloud inference is opt-in and is used consistently for chat, transforms, and library summaries. No request silently switches from local to cloud processing. Availability and Apple’s separate per-user quota are checked, with actionable network/quota/context-size errors.
- A real PCC round trip on a provisioned device or distribution build has not yet been verified. The Mac app was built and its signature checked, but not launched.

## CloudKit production

Container: `iCloud.com.transfinite.aiassistant` (team `88QL9VPLMY`). The production schema was exported successfully and contains all five model record types: `CD_Thread`, `CD_Message`, `CD_Artifact`, `CD_LibraryItem`, and `CD_UserPreferences`.

The existing app uses `Message.statusRaw`, but the exported production and development schemas were both missing `CD_Message.CD_statusRaw`. The additive STRING field is now versioned in `CloudKitSchema.ckdb`, validated, and imported successfully into development. No production records or existing fields were changed.

**Required before distribution:** Open [CloudKit Console](https://icloud.developer.apple.com/dashboard/database/teams/88QL9VPLMY/containers/iCloud.com.transfinite.aiassistant/environments/DEVELOPMENT/types), review the added message-status field, and choose **Deploy Schema Changes**. Re-export production afterward to verify that the field is present. Development-signed builds use development; TestFlight/App Store builds use production. Changing APNs or CloudKit environment strings in the source does not deploy a schema.

The [Bitrig CloudKit skill](/Applications/Bitrig.app/Contents/Resources/BitrigAI_BitrigAI.bundle/Contents/Resources/bitrig-cloudkit-plugin/skills/cloudkit/SKILL.md) states: “the Console is the only way to deploy; cktool’s schema commands operate on development.” This is a tool limitation, not a request for extra approval of the completed development-schema fix.

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
