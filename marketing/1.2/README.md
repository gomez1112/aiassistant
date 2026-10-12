# Version 1.2 App Store media

The current [redesigned campaign](redesign/README.md) uses large benefit headlines, photographic device compositions with Dynamic Island, coordinated ink/pastel colors, and actual app screens. It replaces the first media set after the user's explicit approval.

Created for app `6759457807`, bundle `com.transfinite.aiassistant`, version **1.2**. Media was captured from source build **7**. The submitted distribution builds are **iOS 2** and **macOS 10**. Both app versions and the writing/studying/planning custom pages are **WAITING_FOR_REVIEW** as verified on October 12, 2026. [Submission records](submission.json) contain the build IDs, review links, and verified contact details.

## Current campaign

| Device | Screenshots | Main preview | Custom-page previews |
| --- | ---: | --- | --- |
| Dynamic Island iPhone | 6 at 1206 × 2622 | 886 × 1920, 20 seconds | Writing, studying, planning: 15 seconds each |
| iPhone Duo | 7 at 1398 × 2034 / 2853 × 2007 | 886 × 1920, 20 seconds | Writing, studying, planning: 15 seconds each |
| iPad | 6 at 2064 × 2752 | 1200 × 1600, 20 seconds | Writing, studying, planning: 15 seconds each |
| Mac | 5 at 2880 × 1800 | 1920 × 1080, 20 seconds | Apple's custom-page policy excludes Mac media |

Four **3840 × 1646** headers and four **1920 × 1280** search images cover the main listing and three audiences. Every image is an opaque PNG. All 13 previews use H.264 at 30 fps with stereo AAC at 48 kHz, benefit captions, and an original ambient soundtrack. Source-video timestamps were measured so captions correspond to the feature on screen.

Apple accepted all **45 assets** as **PREPARE_FOR_SUBMISSION**, with no processing errors. The replacement covers **72 draft placements**: 30 on the main iOS/Mac pages and 14 on each custom page. Screenshot order is explicit in all 13 groups. Original library files and the published 1.1.0 listing were preserved.

The [active manifest](manifest.json) records file hashes, remote asset IDs, placement IDs, target localizations, and verification. The prior manifest is retained at [redesign/source/replaced-manifest.json](redesign/source/replaced-manifest.json). Original export folders remain capture/source material; use `redesign/` for the active campaign.

## Custom product pages

Each page has fresh promotional copy and its own leading screenshot, preview story, header, and search artwork:

- [Writing with Ari](https://apps.apple.com/us/app/ai-assistant-ai-chat/id6759457807?ppid=8dbf8612-edb1-4cef-9a1a-bce8ca5090dc)
- [Study with Ari](https://apps.apple.com/us/app/ai-assistant-ai-chat/id6759457807?ppid=f72eeae5-630c-4f68-a1d5-6cf2a12bc492)
- [Plan with Ari](https://apps.apple.com/us/app/ai-assistant-ai-chat/id6759457807?ppid=36b44e77-6371-4443-96e0-309ca34f727d)

All three pages were included in the iOS 1.2 review submission. Their links become usable when Apple approves the pages. Only English media was replaced. Other existing localized screenshot sets were preserved. Existing release notes and published promotional text remain available in all supported listing languages.

## Capture and validation

All interface content was captured from the running app using fictional, isolated, in-memory examples. It does not access the user's CloudKit records or demonstrate a live PCC request. Debug capture hooks require `-marketing-capture`; the final Info.plist has no `MarketingCaptureEnabled` flag. Native Mac view snapshots omit some compositor-rendered navigation chrome, so Mac media shows a closer view of actual app content.

The marketing redesign changes no app code. The standalone Swift render/export/review tools compiled in Swift 6 mode with strict concurrency. Local checks verified every image's size and opacity, all 13 videos' actual codecs/dimensions/duration/audio, and their visible frames. Apple processing and remote placements were read back after upload. See the [campaign review boards](redesign/README.md#review-the-campaign), [video inspection](redesign/review/video-inspection.json), and [reproduction instructions](redesign/README.md#recreate-the-exports).

The prior app verification remains recorded in [release readiness](../../RELEASE_READINESS.md): iOS Simulator and Mac Debug/Release builds passed, 22 Swift Testing tests and two UI regressions passed, and signed Mac Release entitlements/signature were verified. The screenshot capture exposed a saved-output navigation crash under the Mac sidebar; `NavigationPath` fixed it before this media redesign.

## Release and listing limitations

Both distribution builds uploaded successfully and passed Apple's processing. iOS 1.2 build 2 and macOS 1.2 build 10 are waiting for review. The first Mac submission using build 9 was withdrawn after the user supplied the new privacy URL; replacement binaries include the new in-app privacy link. All three custom pages are waiting for review with the iOS submission. The existing `AFTER_APPROVAL` setting will publish each update after Apple approves it; this work has not itself published a release.

The support URL is `https://apps.transfinite.us/support`, the privacy URL is `https://apps.transfinite.us/ai-assistant/privacy-policy`, and the review contact is `transfinite@transfinite.us`, `+19143158248`. Support URLs were verified across 11 localizations per platform, the privacy URL across all 11 app-info localizations, and the contact fields on both review records. Both public pages returned HTTP 200. Settings and the subscription paywall share the updated in-app privacy URL.

The website still describes AI as on-device only. [Proposed privacy-page wording](privacy-disclosure.md) describes version 1.2's optional PCC processing; the website itself was not changed. [Release readiness](../../RELEASE_READINESS.md) records the verified production CloudKit schema and remaining real-device PCC/sync checks.

The final native refresh synchronized the version listing and review contacts, but selected the published app-info record instead of the queued 1.2 app-info record. Apple rejected a change to the published record's privacy URL with `ENTITY_ERROR.ATTRIBUTE.INVALID.INVALID_STATE`. The queued record's 11 privacy URLs were successfully changed and verified before submission. Local app-info files retain the new URL as the desired state; Bitrig's managed lock was not edited by hand and still reflects the published record. A full refresh before approval can restore the old privacy URL locally. Refresh after approval to reconcile that record.

Bitrig's listing updater created the two 1.2 drafts, then failed because Apple had already copied their review-details records. Metadata was completed with the API and verified. After explicit approval, a full refresh reconciled the native listing files and Bitrig-managed sync records with the uploaded drafts. Two pre-existing, approved purchase descriptions have 46 characters and trigger Bitrig's 45-character local validator. Apple rejects changes to those active localization records with `ENTITY_ERROR.ATTRIBUTE.UNMODIFIABLE`; the approved product text was preserved. This local validation issue does not prevent the successfully uploaded media, but the native listing updater remains blocked until that approved-record mismatch is resolved.
