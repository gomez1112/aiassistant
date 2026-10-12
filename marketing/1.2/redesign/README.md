# Ari 1.2 — redesigned marketing campaign

**A little help. A lot more possible.**

This campaign replaces the first version 1.2 media set. It uses larger outcome headlines, ink/cream/peach/lilac colors, photographic device mockups, and the app's actual interface. [AppScreens templates](https://appscreens.com/templates) informed the typography and compositions; none of their template artwork is included.

## Review the campaign

- [iPhone with Dynamic Island](review/iphone.png)
- [iPhone Duo, both displays](review/duo.png)
- [iPad](review/ipad.png)
- [Mac](review/mac.png)
- [Headers and search results](review/creative.png)
- [General iPhone preview](previews/iphone-default-preview.mp4)
- [Writing preview](previews/iphone-writing-preview.mp4)
- [Studying preview](previews/iphone-study-preview.mp4)
- [Planning preview](previews/iphone-planning-preview.mp4)

## Deliverables

| Placement | Deliverables | Export |
| --- | --- | --- |
| Dynamic Island iPhone | 6 screenshots; general/writing/studying/planning previews | PNG 1206 × 2622; MP4 886 × 1920 |
| iPhone Duo | 7 screenshots, including an unfolded landscape composition; four previews | PNG 1398 × 2034 / 2853 × 2007; MP4 886 × 1920 |
| iPad | 6 screenshots; four previews | PNG 2064 × 2752; MP4 1200 × 1600 |
| Mac | 5 screenshots; one general preview | PNG 2880 × 1800; MP4 1920 × 1080 |
| Main page and three custom pages | 4 headers; 4 search images | PNG 3840 × 1646 / 1920 × 1280 |

All 32 placement images are opaque PNGs. All 13 videos use H.264 at 30 fps with stereo AAC at 48 kHz. General stories run 20 seconds; audience stories run 15 seconds. Every custom page has an audience-specific opening screenshot, preview, header, search image, and promotional text.

The [video inspection report](review/video-inspection.json) records each exported file's actual properties. [Source timestamps](source/source-timings.json) align captions with the recorded scenes. Simulator recordings have variable frame timestamps, so the exporter uses measured times rather than assuming that the UI changed on the scheduled tour boundary.

## Content and provenance

Screen content comes from the running app with isolated, fictional marketing fixtures. The compositor places captured screen pixels into the device artwork; it does not generate app controls, rewrite responses, or show a live PCC request. Original screenshots and recordings remain the source material.

The angled smartphone asset is an original, generated photographic-style mockup with a Dynamic Island treatment. It is illustrative hardware artwork, not a photograph of a physical test device or an assertion that it is a particular iPhone model. iPhone Duo, iPad Pro M5, and MacBook Air M5 frames come from [Apple Design Resources](https://developer.apple.com/design/resources/). Standalone Apple bezel files are not redistributed in this repository. Review Apple's [marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines/) and the accompanying resource license when reusing them.

App Store previews contain real footage from inside the app, direct cuts, contextual captions, and an original ambient score. They omit exterior-device compositions in accordance with Apple's [App Preview guidance](https://developer.apple.com/app-store/app-previews/). The footer discloses that unlimited chat requires Ari+. The soundtrack contains no stock recordings or third-party samples.

Mac screenshots show a closer view of actual app content inside the MacBook frame. Native window snapshots omit some compositor-rendered navigation chrome; these assets preserve the captured content and avoid reproducing missing controls.

## Recreate the exports

The standalone tools are outside the app target and add no dependencies. Compile with the installed Swift 6 toolchain in strict concurrency mode:

```sh
xcrun swiftc -swift-version 6 -strict-concurrency=complete -parse-as-library \
  marketing/1.2/scripts/CampaignRenderer.swift -o /private/tmp/ari-campaign-renderer
xcrun swiftc -swift-version 6 -strict-concurrency=complete -parse-as-library \
  marketing/1.2/scripts/CampaignPreview.swift -o /private/tmp/ari-campaign-preview
xcrun swiftc -swift-version 6 -strict-concurrency=complete -parse-as-library \
  marketing/1.2/scripts/CampaignReview.swift -o /private/tmp/ari-campaign-review
```

The renderer takes the capture directory, a directory containing the downloaded/mounted Apple bezels, `source/angled-phone.png`, and an output directory. The preview exporter takes the capture directory, output directory, original stereo WAV, and measured timestamp JSON. The review tool takes the campaign output directory. Preview composition uses the configuration APIs available in the installed macOS 27 SDK.

The primary [manifest](../manifest.json) records the active remote asset IDs, placement IDs, hashes, and target localizations after replacement. The prior manifest is retained at `source/replaced-manifest.json` for provenance. Credentials and signed upload URLs are never stored in the campaign.
