# SwiftUI and resizability review

Applied the App Resizability and SwiftUI Pro skills on 2026-10-12. The app remains on iOS and macOS 27.0 or later. Verified Swift 6.4, Swift 6 language mode, strict concurrency, and Approachable Concurrency per target. The installed SDKs are iOS 27.1 and macOS 27.0.

## Resizability prerequisites and coverage

The generated launch screen exists, iPad declares all four orientations, and UIRequiresFullScreen is absent in Debug and Release. There are no xcconfig overrides. The SwiftUI App/WindowGroup lifecycle already supports scenes and multiple windows. All original 50 Swift source/test files were scanned for screen, orientation, idiom, lifecycle, keyboard geometry, and inset assumptions; no legacy UIKit targets were found.

The two detected safe-area defects were in ArtifactDetailView and LibraryView's detail screen. Both were fixed; the latter now lives in LibraryItemDetailView. A second review confirmed complete file coverage and preservation of full-bleed decorative backgrounds.

## Changes by file

### RootTabView.swift: preserve navigation state with adaptive native containers

Before: a custom Mac HStack with a 188-point sidebar and a switch replacing tab content.

After: one native `TabView(selection: $selectedTab)` with `.tabViewStyle(.sidebarAdaptable)`, plus `.defaultTabBarPlacement(.sidebar)` on iOS. The selected tab stays in scene-owned State; individual windows retain their own DataModel. The hierarchy does not branch on width. The default placement API has explicit iOS/macOS 27 availability.

### ChatView.swift: keep layout types concrete and let system controls adapt

Before: `AnyView` around navigation, headers, mode selection, messages, and attachments; custom navigation buttons occupied the chat surface.

After: `some View` and ContentBuilder composition with native toolbar actions. The composer uses `safeAreaBar(edge: .bottom, spacing: 0)`. Mode selection binds directly through Bindable. The compact chrome also responds to short height, keyboard focus, and accessibility text sizes. Optional errors drive item-based alerts instead of separate Boolean state.

The upgrade banner is extracted to UpgradeTeaserBanner.swift. The floating fade is replaced by the native bar's scroll-edge treatment.

### ComposerBar.swift and ModeChipBar.swift: keep controls operable at every text size

Before: composer buttons used 36-point frames; mode chips used 38-point heights. The compact picker's image and text wrapped badly at the largest text size.

After: 44-point touch targets inside the actual button labels, a title-only native compact picker, and ViewThatFits falling back from the segmented picker to the menu. ModeChip is in its own file. Only the composer symbols cap their text-size scaling at xxxLarge to fit their fixed control targets; the message field and other text retain full Dynamic Type.

### ChatStarterView.swift and AppEmptyStateView.swift: scroll instead of clipping

Before: the starter content was constrained to the viewport height; custom empty states assumed the full content would fit.

After: scrolling content has a viewport minimum height and can grow taller. Accessibility text sizes use one starter column and descriptions wrap. Empty states use ContentUnavailableView within a scrollable viewport.

### MacContentHeader.swift: let search and actions reflow

Before: a stored view-builder closure, a fixed 220-point search field, and one horizontal header arrangement.

After: stored built view content, a flexible search field, and ViewThatFits choosing horizontal or stacked search headers. Decorative divider overlays use builder closures.

### ArtifactDetailView.swift and LibraryItemDetailView.swift: use actual safe areas

Before:

```swift
.safeAreaPadding(.bottom, 72)
.toolbar(.hidden, for: .tabBar)
```

After:

```swift
.toolbarVisibility(.hidden, for: .tabBar)
```

No bottom control needed the 72-point clearance. Transform and summary alerts now bind directly to their optional error. Library detail and add-item sheets are separate files. TagEditorSheet and AddLibraryItemSheet present save failures inside the active sheet.

### FlashcardView.swift and FlashcardDeckView.swift: allow long cards to grow

Before: `.frame(height: 220)`, 3D flips even with Reduce Motion, and an unbounded row of progress dots.

After: `.frame(minHeight: 220)` with vertically expanding text, opacity-only flips when Reduce Motion is enabled, and bounded native progress. The deck parses one snapshot per body evaluation.

### ArtifactContentView.swift, QuizView.swift, and BulletListView.swift: preserve valid study state

Before: replacement CloudKit content could leave old quiz/deck indices and checked rows addressing a different source. Quiz progress repeatedly parsed the same content and used an unnecessary GeometryReader. Checklist controls expanded outside their button label.

After: `.id(artifact.content)` resets study state only when the source changes, retaining it through resizing. Quiz rendering parses one snapshot and passes each question to progress calculation. Checklist rows use a native Toggle with a full-height tappable label. Principal output types are extracted from the former 1,200-line detail file.

### FlowLayout.swift and OutputsView.swift: wrap tags within available width

Before: unspecified width became zero; oversized tags were measured and placed at unconstrained widths; output rows used a single horizontal tag stack.

After: unspecified width uses the natural row width, and measurement and placement share a constrained child proposal. Output row tags use the wrapping layout. SwiftUI provides RTL placement mirroring.

### MessageListView.swift and WelcomeOfferGate.swift: own delayed work

Before: copy feedback and the delayed welcome offer used unowned tasks with ignored cancellation.

After: `.task(id:)` cancels delayed view work when its view disappears. The welcome offer rechecks premium access and the shared presentation flag before presenting, preventing duplicate offers in multiple windows.

### ThreadListSheet.swift and SubscriptionPaywallView.swift: simplify presentation and resize sheets

Before: chat deletion combined an optional thread with a derived Boolean binding. The Mac paywall required at least 620 by 760 points; policy actions sat in a fixed horizontal row.

After: deletion uses the item-based confirmation dialog. The scrollable paywall has a smaller minimum and an ideal size, policy actions reflow vertically, purchase disclosures wrap, and the subscribe background is part of the tappable label. Product refresh and restoration are owned by view tasks; the existing StoreKit purchase integration is preserved.

## Validation

- `bitrig build -destination all --keep-going` passed for iOS Simulator and signed macOS. No Swift compiler warnings; the existing AppIntents metadata warning remains because the app has no AppIntents dependency.
- 22 unit tests and 5 critical UI tests passed together: composer/keyboard/reply, mode and assistant actions, chat-sheet navigation, paywall reachability, and the new draft-preservation test across tabs and rotation.
- The composer and mode UI tests passed again after the final accessibility refinements.
- Simulator inspection confirmed that an unsent draft survives folding from the inner display to the outer display. The compact display was checked at the largest accessibility text setting; the mode picker remains on one line, the composer symbols fit, and the starter actions can be reached by scrolling. A partially folded landscape pose was also inspected. Text size was restored to Large and the device left open.
- `git diff --check` passed.

Mac runtime resizing, iPad split-window dragging, every Duo rotation, and RTL runtime behavior were not exercised in this pass. macOS was compiled without launching. Actual PCC requests and production CloudKit sync remain covered by the separate release-readiness checklist.

## Priority of the completed fixes

1. Safe areas, scrolling, and touch targets keep primary actions reachable in small windows and at larger text sizes.
2. Native adaptive navigation and stable scene state preserve work through resizing and tab changes.
3. View-owned tasks, optional-item presentation, and study-source resets prevent delayed or stale UI state.

Design decisions follow Apple's [Layout](https://developer.apple.com/design/human-interface-guidelines/layout), [Windows](https://developer.apple.com/design/human-interface-guidelines/windows), and [Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) guidance.
