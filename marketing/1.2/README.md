# Version 1.2 App Store media

Created and uploaded on October 12, 2026 for app `6759457807`, bundle `com.transfinite.aiassistant`. The app target is version **1.2**, build **7**. Both platforms have 1.2 drafts; the released 1.1.0 versions were preserved.

## Uploaded assets

| Device | Screenshots | Screenshot pixels | App Preview |
| --- | ---: | --- | --- |
| iPhone with Dynamic Island | 6 | 1206 × 2622 | 886 × 1920, 25 seconds |
| iPhone Duo | 7 | 1398 × 2034 outer; 2853 × 2007 inner | 886 × 1920, 25 seconds |
| iPad Pro 13-inch | 6 | 2064 × 2752 | 1200 × 1600, 25 seconds |
| macOS | 5 | 2880 × 1800 | 1920 × 1080, 20 seconds |

All screenshots are opaque PNGs. All four previews have a stereo audio track and a 30 fps export. Preview framing preserves the source aspect ratio, including the Duo display. Silent audio avoids microphone recordings and music licensing requirements.

Eight additional images provide main-page, writing, studying, and planning artwork: four **3840 × 1646** headers and four **1920 × 1280** search-results assets. These use the app's real screens and its existing visual identity.

Apple's asset API reports **PREPARE_FOR_SUBMISSION for all 36 assets**, with no processing errors. There are **72 active placements**: 30 across the main iOS/Mac pages and 14 on each custom page. All 13 screenshot groups were ordered successfully. The old English draft screenshot placements were replaced after explicit confirmation; their original library images and the published listing were retained.

The [manifest](manifest.json) records each file, its SHA-256, dimensions, asset ID, placement ID, and target localization. It contains no credentials or signed upload URLs. Header, search, preview, and custom-page placement records use Apple's asset-library API; the native listing files do not represent every new asset type.

## Custom product pages

These pages are **drafts**, with English promotional text, audience-specific leading screenshots, three screenshots plus one preview for each mobile family, and their own header and search artwork:

- [Writing with Ari](https://apps.apple.com/us/app/ai-assistant-ai-chat/id6759457807?ppid=8dbf8612-edb1-4cef-9a1a-bce8ca5090dc)
- [Study with Ari](https://apps.apple.com/us/app/ai-assistant-ai-chat/id6759457807?ppid=f72eeae5-630c-4f68-a1d5-6cf2a12bc492)
- [Plan with Ari](https://apps.apple.com/us/app/ai-assistant-ai-chat/id6759457807?ppid=36b44e77-6371-4443-96e0-309ca34f727d)

The links become usable when Apple approves the pages. Apple's live asset policy supports custom pages on iPhone/Duo/iPad, and excludes the Mac profile. Mac media belongs to the main macOS listing.

Release notes were updated in all 11 existing languages on both platforms, and existing published promotional copy was carried forward into the new drafts. Screen captures and artwork use the English interface. Other existing localized screenshot sets were preserved.

## Capture and verification

All screen content comes from the running app, using fictional examples in an isolated in-memory store. Captures never read or change the user's CloudKit records. Prepared examples demonstrate the interface; they are not evidence of a live PCC inference request.

`MarketingCaptureSession` and the native Mac capture bridge compile only in Debug and require `-marketing-capture`. `MarketingCaptureEnabled` is absent from the final Info.plist. Optional arguments are `-marketing-scene writing|planning|outputs|library|study|privacy` and `-marketing-tour`. The tour switches through real native screens for recording. Mobile screenshots and recordings were captured with CoreSimulator; both Duo display sizes were also inspected with Bitrig's simulator.

The Mac capture exposed a SwiftUI navigation comparison-type crash when opening an output under the sidebar. `NavigationPath` resolves the conflicting value types. The full five-scene Mac tour completed afterward. Native view snapshots cannot export all compositor-only navigation chrome, so Mac media uses close views of actual app content. The Swift export utility crops that chrome, preserves the content, and adds headlines only to screenshots. It does not synthesize app controls or AI responses.

- Debug and Release builds passed for iOS Simulator and native Mac.
- 22 Swift Testing unit tests and 2 UI regressions passed on iPhone 18 Pro / iOS 27.0.
- The added UI test switches tabs, opens saved cards, flips a card, and advances the deck. The second checks draft preservation across tabs and rotation.
- The signed Mac App Store Release app has PCC, production APNs, and production CloudKit entitlements; its signature passed verification.
- All media passed local dimension/opacity inspection and Apple's server processing. Assets and placements were read back from App Store Connect.

## Repeating an export

Build the app with `bitrig build -destination all` using Debug. Launch the built app with the explicit capture arguments above. Use `simctl io <device-id> screenshot` and `recordVideo --codec=h264` for mobile media. The Mac bridge stores five screenshots and 200 native frames in its own `Library/Caches/AriMarketingCapture/mac` directory. [read_mac_captures.py](scripts/read_mac_captures.py) exports only those fixture captures through the app's debugger when its container cannot be read by the host process.

Compile the standalone renderer with Swift 6:

```sh
xcrun swiftc -swift-version 6 -strict-concurrency=complete -parse-as-library \
  marketing/1.2/scripts/AriMediaExport.swift -o /private/tmp/ari-media-export
```

Its `image`, `creative`, `mac-shot`, `frames`, `video`, `poster`, and `inspect` commands export or inspect media. `video` takes source-video, stereo-WAV, destination, width, and height arguments. `mac-shot` takes source-PNG, destination, headline, and subtitle. `frames` takes the native Mac frame directory and destination. Crops assume the documented 1440 × 900-point Mac capture window; recalculate them if that window changes. The standalone export utility retains the released AVFoundation writer adaptor and composition APIs; it is not shipped in the app and adds no dependency.

## Release and listing limitations

No app binary was uploaded, no page/version was submitted for review, and no release was published. [Release readiness](../../RELEASE_READINESS.md) records the verified production CloudKit schema and remaining real-device PCC/sync checks.

Bitrig's listing updater created the two 1.2 drafts, then failed because Apple had already copied their review-details records. Metadata was completed with the API and verified. After explicit approval, a full refresh reconciled the native listing files and Bitrig-managed sync records with the uploaded drafts. Two pre-existing, approved purchase descriptions have 46 characters and trigger Bitrig's 45-character local validator. Apple rejects changes to those active localization records with `ENTITY_ERROR.ATTRIBUTE.UNMODIFIABLE`; the approved product text was preserved. This local validation issue does not prevent the successfully uploaded media, but the native listing updater remains blocked until that approved-record mismatch is resolved.
