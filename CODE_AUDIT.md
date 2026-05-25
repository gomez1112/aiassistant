# Code Audit: Bugs, UI/UX, Accessibility, Logic

Audit date: 2026-05-24  
Project: `aiassistant`  
Scope: SwiftUI app source, models, engines, StoreKit config, unit tests, UI tests, and manual Computer Use accessibility snapshot.

## Fix Status

Fix pass applied after this audit:
- FlexStore is now the only entitlement source used by paywall display and premium feature gates; the older `SubscriptionStore` source was removed.
- Generation, transform, and summary failures now return typed failures and show transient UI instead of saving error strings as user content.
- CloudKit/local fallback state is explicit through `PersistenceMode`, including local-only warnings and a recovery UI instead of a launch crash.
- Compact chat chrome, message actions, Ari actions, mode controls, and core toolbar controls have stable accessibility identifiers and larger hit targets.
- Duplicate saved artifacts, stale artifact source links, case-duplicate tags, sample-data duplication, unsafe URL unwraps, StoreKit resource bundling, and UI-test release flag exposure were addressed.
- Verification after fixes: iPhone 17 full test suite passed 16/16; iPad Pro 13-inch unit/build path passed 9/9; macOS Debug build succeeded.

## 1. Executive Summary

- No compiler-blocking issue was found: the iPhone 17 simulator test run passed 15/15 with no diagnostics.
- Highest-priority fixes are §4.1, §4.2, §4.3, §4.4, §4.5, §4.6, §4.8, and §4.9.
- Chat/keyboard changes are improved, but compact chrome still has automation and accessibility gaps: duplicate empty-state identifiers (§6.1), small action targets (§6.2, §6.3, §6.4), and streaming VoiceOver spam (§7.4).
- The largest logic risks are monetization entitlement drift (§4.3), error strings saved as durable user content (§4.2, §4.8), and silent CloudKit local fallback (§4.6).
- The largest performance risks are unbounded in-memory queries/search (§5.2, §5.15) and repeated relationship sorting in the chat hot path (§5.14).
- The largest test gaps are UI-test launch flags compiled into release behavior (§4.1), StoreKit paths bypassed by UI tests (§10.2), and compact layout tests that can pass without exercising compact layout (§10.3).

## 2. Scope And Methodology

- Static review covered all 39 Swift files, StoreKit notes/config, README, entitlements, and Xcode project metadata.
- Build/test verification used XcodeBuildMCP against project `aiassistant.xcodeproj`, scheme `aiassistant`, destination iPhone 17 simulator.
- Manual UI verification used Computer Use against the running macOS app to inspect the accessibility tree for chat controls.
- Severity scale: Critical means likely crash/data loss/security break in common use; High means user-blocking or monetization/data integrity risk; Medium means real but bounded bug; Low means friction, maintainability, or config drift.

## 3. Critical Findings

No confirmed Critical issues were found in the current tree. The app builds and the simulator test suite passes. The High issues below are still release-blocking candidates because they affect purchases, persistence, generated content integrity, and accessibility.

## 4. High Severity Findings

### 4.1 Release builds honor UI-test launch arguments

Evidence: `AIAssistantApp` reads raw launch arguments and switches to in-memory UI-test storage at `aiassistant/aiassistantApp.swift:21`, `aiassistant/aiassistantApp.swift:25`, and `aiassistant/aiassistantApp.swift:39`. It also bypasses onboarding at `aiassistant/aiassistantApp.swift:71`. `AssistantEngine` returns deterministic fake replies when `-ui-testing-fast-ai` is present at `aiassistant/Engines/AssistantEngine.swift:86`, and `ChatView` seeds deterministic chat content at `aiassistant/Views/Chat/ChatView.swift:710`.

Impact: test-only behavior is compiled into the runtime path. On macOS, launch arguments are user-controllable, and on iOS this creates a release binary with hidden behavior that can bypass onboarding, avoid persistent storage, and fake assistant generation.

Recommendation: wrap all UI-test flags in `#if DEBUG` or inject a test-only environment through the test target rather than raw process arguments in production code.

### 4.2 Generation failures are persisted as normal assistant replies

Evidence: Foundation Models errors are converted into a non-empty string, `Generation failed: ...`, at `aiassistant/Engines/AssistantEngine.swift:150` and `aiassistant/Engines/AssistantEngine.swift:155`. `DataModel.sendMessage` persists any non-empty reply as an assistant `Message` at `aiassistant/Engines/DataModel.swift:99` and `aiassistant/Engines/DataModel.swift:105`.

Impact: transient model errors become durable conversation content. Users can copy, save, transform, and sync a failure message as if it were an answer.

Recommendation: return a typed failure result and show a transient error banner/retry action instead of creating a saved assistant message.

### 4.3 Paying users can be gated by split entitlement sources

Evidence: the paywall considers access active if `entitlementStore`, `flexStore.isSubscribed`, or lifetime purchase is active at `aiassistant/Views/Settings/SubscriptionPaywallView.swift:89`. Feature gates only check `SubscriptionStore.hasPremiumAccess` in chat, outputs, and library at `aiassistant/Views/Chat/ChatView.swift:50`, `aiassistant/Views/Outputs/ArtifactDetailView.swift:176`, and `aiassistant/Views/Library/LibraryView.swift:429`.

Impact: if FlexStore observes a purchase before `SubscriptionStore` refreshes, the paywall can dismiss while premium actions still show paywalls. This is a monetization trust bug for newly purchased or restored users.

Recommendation: create one entitlement facade used by both paywall display and feature gates, or mirror FlexStore entitlement changes into `SubscriptionStore` before dismissing the paywall.

### 4.4 The last free send presents a paywall while generation is active

Evidence: `sendMessage()` sets `isGenerating = true` at `aiassistant/Views/Chat/ChatView.swift:503`, then immediately calls `presentPaywall(context:)` for the final free send at `aiassistant/Views/Chat/ChatView.swift:506`, before starting the generation task at `aiassistant/Views/Chat/ChatView.swift:510`.

Impact: the paywall can cover the active conversation, stop button, and streaming state immediately after the user sends a valid message. This is especially disruptive on compact iPhone layouts.

Recommendation: defer the limit paywall until generation completes, or show a non-modal post-send upgrade prompt.

### 4.5 Cancellation does not guard against late streaming state

Evidence: `cancelGeneration()` cancels the outer task and calls `assistant.cancel()` at `aiassistant/Views/Chat/ChatView.swift:528`. `AssistantEngine.cancel()` only resets `state` and `streamingText` at `aiassistant/Engines/AssistantEngine.swift:230`. The Foundation Models session is retained at `aiassistant/Engines/AssistantEngine.swift:249`, and streaming still writes `streamingText` and `state` inside the loop at `aiassistant/Engines/AssistantEngine.swift:265`.

Impact: if the stream yields after UI cancellation, the visible assistant state can revive or mutate while the UI has already left the generating state.

Recommendation: track a generation ID/token and ignore late stream events after cancellation; clear the retained session when the generation ends or is cancelled.

### 4.6 CloudKit fallback silently disables sync while UI still promises sync

Evidence: app startup falls back to `cloudKitDatabase: .none` at `aiassistant/aiassistantApp.swift:55` and `aiassistant/aiassistantApp.swift:58`. Settings still says data can sync via CloudKit at `aiassistant/Views/Settings/SettingsView.swift:145`, and the paywall sells “Priority sync” at `aiassistant/Models/Monetization.swift:86`.

Impact: users may believe their data is syncing or that premium improves sync when the app is actually running on a local-only store.

Recommendation: expose persistence mode in environment, show a user-visible degraded-sync warning, and do not advertise sync while in fallback mode.

### 4.7 A second ModelContainer failure is still a launch crash

Evidence: after CloudKit container creation fails, the fallback container creation is attempted at `aiassistant/aiassistantApp.swift:54`; if that also fails, the app calls `fatalError` at `aiassistant/aiassistantApp.swift:63`.

Impact: corrupt local stores, schema incompatibilities, disk errors, or test environment issues can still crash the app before any recovery UI appears.

Recommendation: route unrecoverable container errors into a minimal recovery scene with reset/export diagnostics instead of `fatalError`.

### 4.8 Transform and summary failures are persisted as user content

Evidence: transform failures return strings at `aiassistant/Engines/AssistantEngine.swift:196` and `aiassistant/Engines/AssistantEngine.swift:199`; `DataModel.transformArtifact` saves that output into a new artifact at `aiassistant/Engines/DataModel.swift:198`. Summary failures return strings at `aiassistant/Engines/AssistantEngine.swift:220` and `aiassistant/Engines/AssistantEngine.swift:221`; `DataModel.summarizeItem` stores the result at `aiassistant/Engines/DataModel.swift:217`.

Impact: failed transforms and summaries become saved outputs or library summaries, polluting user data and sync.

Recommendation: make transform/summarize return typed success/failure, and display failure UI without writing model objects.

### 4.9 Product-load failures can render an empty paywall

Evidence: subscription plans only show a loader when FlexStore is loading and products are empty at `aiassistant/Views/Settings/SubscriptionPaywallView.swift:119`. If loading finishes with no products, the `ForEach` at `aiassistant/Views/Settings/SubscriptionPaywallView.swift:126` renders nothing, and `subscribeButton` renders only if `selectedProduct` exists at `aiassistant/Views/Settings/SubscriptionPaywallView.swift:137`.

Impact: StoreKit/catalog failure can leave users with a paywall that has features and legal links but no plan, no retry, and no explanation.

Recommendation: add an explicit empty/error state with retry and restore actions.

## 5. Medium Severity Logic And Data Findings

### 5.1 Daily free-message fetch has no upper day bound

Evidence: `todaysUserMessageFetchDescriptor` filters only `createdAt >= startOfDay` at `aiassistant/Views/Chat/ChatView.swift:99`.

Impact: future-dated messages caused by clock changes, imports, or bad test data count against today’s limit.

Recommendation: use `createdAt >= startOfDay && createdAt < nextStartOfDay`.

### 5.2 The free-message banner counts all user messages in memory

Evidence: `@Query` loads every user message at `aiassistant/Views/Chat/ChatView.swift:24`, then filters with `Calendar.isDateInToday` at `aiassistant/Views/Chat/ChatView.swift:85`.

Impact: the chat screen grows slower as history grows, even though only today’s count is needed.

Recommendation: query today’s count with a predicate and avoid keeping all user messages live in the view.

### 5.3 Cancelled generations leave orphan user messages

Evidence: `sendMessage` inserts the user message before generation at `aiassistant/Engines/DataModel.swift:67` and `aiassistant/Engines/DataModel.swift:74`. If the task is cancelled, it saves and returns without assistant content at `aiassistant/Engines/DataModel.swift:94`.

Impact: users who tap Stop get a saved prompt with no visible status explaining that the answer was cancelled.

Recommendation: persist a message status, insert a cancelled assistant/system notice, or roll back the user message on cancellation.

### 5.4 Conversation history maps future system/tool roles to Assistant

Evidence: `MessageRole` includes `.system` and `.tool` at `aiassistant/Models/Message.swift:10`, but `buildConversationContext` maps every non-user role to `Assistant` at `aiassistant/Engines/AssistantEngine.swift:424`.

Impact: if system or tool messages are introduced later, prompts will misrepresent their role and can leak implementation text as assistant content.

Recommendation: handle each role explicitly or exclude internal roles from user-facing context.

### 5.5 Prompt history is unbounded per message

Evidence: the engine includes the last 10 messages at `aiassistant/Engines/AssistantEngine.swift:424`, but each entry uses full `msg.text` at `aiassistant/Engines/AssistantEngine.swift:428`.

Impact: a few long imported or generated messages can overflow context, slow generation, or degrade model quality.

Recommendation: summarize or cap history by token/character budget.

### 5.6 Security-scoped file access failure is ignored

Evidence: `startAccessingSecurityScopedResource()` is stored in `hasAccess` at `aiassistant/Views/Chat/ChatView.swift:628`, but extraction proceeds regardless at `aiassistant/Views/Chat/ChatView.swift:639`.

Impact: import failures can surface as generic unreadable-file errors, and sandbox permissions are not handled deterministically.

Recommendation: if security-scoped access fails, throw a specific permission error before reading.

### 5.7 PDF import limits pages but not bytes or extracted text length

Evidence: PDFs are capped at 50 pages at `aiassistant/Views/Chat/ChatView.swift:653`, then every page’s full string is appended at `aiassistant/Views/Chat/ChatView.swift:657`.

Impact: a 50-page dense PDF can create a huge prompt, memory pressure, and slow UI/model behavior.

Recommendation: add file-size, extracted-character, and prompt-budget limits with a truncation notice.

### 5.8 OCR import is not cancellation-aware

Evidence: image extraction is run in `Task.detached` at `aiassistant/Views/Chat/ChatView.swift:611`, and Vision performs synchronously at `aiassistant/Views/Chat/ChatView.swift:677`.

Impact: dismissing or replacing the import cannot stop a long OCR request once started.

Recommendation: retain the import task, check cancellation before/after Vision, and clear stale results by import ID.

### 5.9 Attachment import can update stale view state

Evidence: `importAttachment(from:)` creates an untracked `Task` at `aiassistant/Views/Chat/ChatView.swift:606` and writes `pendingAttachmentText` later at `aiassistant/Views/Chat/ChatView.swift:619`.

Impact: if the user starts another import, switches thread, or dismisses the view, an older import can replace current attachment state.

Recommendation: store an import task or token and ignore completions that are not the latest import.

### 5.10 Output Studio generation can mutate state after dismissal

Evidence: `OutputStudioSheet.generate()` starts an untracked task at `aiassistant/Views/Chat/OutputStudioSheet.swift:104` and writes `result`, `title`, and `isProcessing` after await at `aiassistant/Views/Chat/OutputStudioSheet.swift:113`.

Impact: dismissing the sheet during generation can still update state and model engine flags afterward.

Recommendation: store/cancel the task on dismiss and guard state updates with `Task.isCancelled`.

### 5.11 Artifact transforms give no navigation to the created artifact

Evidence: the detail view launches a transform at `aiassistant/Views/Outputs/ArtifactDetailView.swift:181`, ignores the returned artifact at `aiassistant/Views/Outputs/ArtifactDetailView.swift:183`, and remains on the original item. The new artifact is inserted at `aiassistant/Engines/DataModel.swift:198`.

Impact: users may think the transform did nothing, especially when the new artifact appears elsewhere in Outputs.

Recommendation: navigate to the new artifact, show a success banner with “Open”, or replace the current detail context.

### 5.12 Library summaries can update after the detail view is gone

Evidence: `LibraryItemDetailView.summarize()` launches an untracked task at `aiassistant/Views/Library/LibraryView.swift:434`, then writes model state and local state at `aiassistant/Views/Library/LibraryView.swift:436`.

Impact: leaving the screen mid-summary can still mutate the item and local view state later.

Recommendation: keep a cancellable task and cancel it on disappearance.

### 5.13 Assistant transform state is a single shared boolean

Evidence: `AssistantEngine` uses one `isTransforming` flag for transforms at `aiassistant/Engines/AssistantEngine.swift:179` and library summaries at `aiassistant/Engines/AssistantEngine.swift:208`.

Impact: concurrent transform and summary tasks can clear each other’s loading state incorrectly.

Recommendation: split state by operation or track active operation count.

### 5.14 Thread message sorting is repeated in hot paths

Evidence: `Thread.sortedMessages` sorts the relationship every access at `aiassistant/Models/Thread.swift:37`. Chat uses it repeatedly in a single update path at `aiassistant/Views/Chat/ChatView.swift:442` and `aiassistant/Views/Chat/ChatView.swift:448`, and message rendering reads it at `aiassistant/Views/Chat/MessageListView.swift:90`.

Impact: long threads perform repeated O(n log n) work during rendering, Ari updates, and generation.

Recommendation: cache sorted messages per render/update or query messages sorted by date.

### 5.15 Outputs and Library search filter every item in memory

Evidence: Outputs filters all queried artifacts in Swift at `aiassistant/Views/Outputs/OutputsView.swift:25`, including full content at `aiassistant/Views/Outputs/OutputsView.swift:34`. Library does the same at `aiassistant/Views/Library/LibraryView.swift:26`.

Impact: search becomes increasingly slow as saved outputs and source material grow.

Recommendation: use SwiftData predicates, debounced search, or an indexed/searchable field.

### 5.16 Save actions allow duplicate artifacts and duplicate references

Evidence: saving from chat appends a new artifact ID to `message.artifactIDs` at `aiassistant/Engines/DataModel.swift:149` every time, and inline Save is always available at `aiassistant/Views/Chat/MessageListView.swift:276`.

Impact: repeated taps create duplicate Outputs and duplicate source references.

Recommendation: disable Save after success, de-duplicate by source message/kind/content, or expose “already saved” state.

### 5.17 Artifact source links go stale when threads are deleted

Evidence: artifacts store `sourceThreadID` and `sourceMessageID` as raw UUIDs at `aiassistant/Models/Artifact.swift:64`. Thread deletion cascades messages at `aiassistant/Models/Thread.swift:18` and deletes the thread at `aiassistant/Engines/DataModel.swift:47`, but artifacts are not updated.

Impact: Outputs can contain references to deleted threads/messages, which will break future “open source chat” features.

Recommendation: either model relationships explicitly or clear source IDs when deleting a thread.

### 5.18 Tag duplicate detection is case-sensitive

Evidence: `TagEditorSheet.addTag()` rejects exact duplicates only at `aiassistant/Views/Outputs/ArtifactDetailView.swift:241`.

Impact: users can create `Work`, `work`, and `WORK` as separate tags, weakening filtering and display.

Recommendation: normalize tags for comparison while preserving display casing.

### 5.19 Debug sample-data seeding is a no-op from Settings

Evidence: the debug alert Seed action contains only a comment at `aiassistant/Views/Settings/SettingsView.swift:53`.

Impact: the visible debug control does not do what it says, slowing QA and manual testing.

Recommendation: call `SampleData.seed(in:)` or remove the button.

### 5.20 SampleData is not idempotent and ignores save failures

Evidence: `SampleData.seed(in:)` inserts new records unconditionally at `aiassistant/Preview/SampleData.swift:12`, then uses `try? context.save()` at `aiassistant/Preview/SampleData.swift:100`.

Impact: when wired up, repeated debug seeding will duplicate sample data and hide persistence errors.

Recommendation: check for existing sample records and surface save failures in debug UI.

### 5.21 URL force unwraps create avoidable launch-time crash risk

Evidence: policy URLs are force-unwrapped at `aiassistant/Models/Monetization.swift:68`, and the subscriptions URL is force-unwrapped at `aiassistant/Views/Settings/SubscriptionPaywallView.swift:17`.

Impact: constants are currently valid, but URL edits can turn a metadata typo into a runtime crash.

Recommendation: use static `URL` construction with a precondition in debug or optional fallback in release.

### 5.22 Message role fallback hides corrupted data

Evidence: an unknown `roleRaw` falls back to `.user` at `aiassistant/Models/Message.swift:56`.

Impact: corrupted or future role values can become user messages, affecting free-message limits and prompt history.

Recommendation: add `.unknown` handling or exclude invalid roles from user counts/history.

## 6. UI And UX Findings

### 6.1 Empty-state container and Start Chat button share the same identifier

Evidence: `ChatView` assigns `chat.emptyState` to the empty-state view at `aiassistant/Views/Chat/ChatView.swift:320` and `aiassistant/Views/Chat/ChatView.swift:365`, while the nested action button is created inside `AppEmptyStateView` at `aiassistant/Views/Theme/AppEmptyStateView.swift:57`. Computer Use observed both the text container and Start Chat button exposed with `chat.emptyState`.

Impact: UI tests and Computer Use can tap the wrong element, especially when trying to dismiss the keyboard by tapping the empty surface.

Recommendation: give the button a distinct identifier such as `chat.emptyState.startChat`, and reserve `chat.emptyState` for the container.

### 6.2 Compact message actions are visually below the 44pt target

Evidence: the compact message action menu label is fixed at 32pt high at `aiassistant/Views/Chat/MessageListView.swift:360`.

Impact: compact iPhone users get a small hit target for Copy/Save/Transform.

Recommendation: use `frame(minWidth:minHeight:)` with `AppTheme.minimumTapTarget`.

### 6.3 Ari action controls are below the 44pt target

Evidence: compact Ari menu is 36pt high at `aiassistant/Views/Chat/AriGuidanceBar.swift:63`, and expanded Ari action buttons are 32pt high at `aiassistant/Views/Chat/AriGuidanceBar.swift:86`.

Impact: the action strip remains hard to hit while typing or scrolling.

Recommendation: enforce 44pt minimum hit targets while keeping visual chrome compact.

### 6.4 Expanded mode chips are below the 44pt target

Evidence: `ModeChip` uses only 7pt vertical padding at `aiassistant/Views/Chat/ModeChipBar.swift:131` with no min-height frame.

Impact: empty-chat iPhone mode selection can be crowded and less reliable for touch.

Recommendation: add `frame(minHeight: AppTheme.minimumTapTarget)` to chips.

### 6.5 Output filter chips are below the 44pt target

Evidence: `FilterChip` uses 6pt vertical padding at `aiassistant/Views/Outputs/OutputsView.swift:294` and no minimum hit frame.

Impact: filtering saved outputs is harder for touch and motor accessibility.

Recommendation: apply the shared minimum tap target.

### 6.6 Upgrade teaser text can compress too aggressively

Evidence: the teaser title is forced to one line at `aiassistant/Views/Chat/ChatView.swift:806`, with `minimumScaleFactor(0.82)` at `aiassistant/Views/Chat/ChatView.swift:810`.

Impact: at larger Dynamic Type sizes or narrow widths, the banner can become hard to read instead of wrapping or restructuring.

Recommendation: use adaptive layout or hide secondary text before shrinking essential text.

### 6.7 Output Studio source preview is not expandable

Evidence: source text is capped with `.lineLimit(5)` at `aiassistant/Views/Chat/OutputStudioSheet.swift:29`.

Impact: users cannot inspect whether they are transforming the correct source without cancelling and returning to chat.

Recommendation: add expand/collapse or a read-only detail sheet.

### 6.8 Output Studio cannot regenerate after a result exists

Evidence: the toolbar switches to Save when `result != nil` at `aiassistant/Views/Chat/OutputStudioSheet.swift:80`; Generate is only available in the `else` branch at `aiassistant/Views/Chat/OutputStudioSheet.swift:83`.

Impact: users must dismiss and reopen the sheet to change transform settings and regenerate.

Recommendation: keep Generate/Regenerate available after a result or reset result when inputs change.

### 6.9 Rows truncate important content without richer accessibility summaries

Evidence: output rows cap title/content at `aiassistant/Views/Outputs/OutputsView.swift:236` and `aiassistant/Views/Outputs/OutputsView.swift:248`; library rows cap title/content at `aiassistant/Views/Library/LibraryView.swift:214` and `aiassistant/Views/Library/LibraryView.swift:228`.

Impact: sighted users and assistive technologies get little context for similarly named long items.

Recommendation: add subtitles/metadata in accessibility labels and consider secondary preview expansion.

### 6.10 macOS sidebar target height is smaller than surrounding chat controls

Evidence: macOS sidebar tab buttons use a fixed 34pt height at `aiassistant/Views/RootTabView.swift:127`.

Impact: the sidebar feels denser than the rest of the app and is less forgiving for pointer/trackpad users.

Recommendation: increase to at least 40pt and preserve readable spacing.

### 6.11 Paywall plan cards use 26pt radii inconsistent with the rest of the app

Evidence: subscription cards use `cornerRadius: 26` at `aiassistant/Views/Settings/SubscriptionPaywallView.swift:351` while the shared card radius is 8 at `aiassistant/Views/Theme/AppTheme.swift:75`.

Impact: paywall styling diverges from the app’s utilitarian card system and can read as an unrelated surface.

Recommendation: use shared radius tokens unless there is a product-specific reason.

### 6.12 The app hides transformed output creation behind the Outputs tab

Evidence: transforms create a new artifact at `aiassistant/Engines/DataModel.swift:198`, but the current artifact detail does not present the new item at `aiassistant/Views/Outputs/ArtifactDetailView.swift:183`.

Impact: user feedback is weak: the operation completes but the result is not in the current view.

Recommendation: show an inline success affordance or navigate to the created artifact.

## 7. Accessibility Findings

### 7.1 Many content views use fixed system font sizes

Evidence: flashcards use fixed fonts at `aiassistant/Views/Outputs/ArtifactDetailView.swift:497`, quiz text uses fixed fonts at `aiassistant/Views/Outputs/ArtifactDetailView.swift:594`, and styled text uses fixed fonts at `aiassistant/Views/Outputs/ArtifactDetailView.swift:1031`.

Impact: Larger Text support is incomplete in high-value output views.

Recommendation: replace fixed sizes with semantic text styles or `@ScaledMetric`.

### 7.2 Artifact animations are not gated by Reduce Motion

Evidence: flashcard and quiz navigation call `withAnimation` at `aiassistant/Views/Outputs/ArtifactDetailView.swift:337`, `aiassistant/Views/Outputs/ArtifactDetailView.swift:358`, `aiassistant/Views/Outputs/ArtifactDetailView.swift:609`, and `aiassistant/Views/Outputs/ArtifactDetailView.swift:667`.

Impact: users who enabled Reduce Motion still receive spring/move/scale animations.

Recommendation: inject `@Environment(\.accessibilityReduceMotion)` and pass `nil` or opacity-only transitions when enabled.

### 7.3 Ari guidance bar animation ignores Reduce Motion

Evidence: `AriGuidanceBar` animates action count changes at `aiassistant/Views/Chat/AriGuidanceBar.swift:29`.

Impact: the bottom composer-adjacent chrome can animate even when the user asks for reduced motion.

Recommendation: gate the animation the same way `ComposerBar` and `MessageListView` do.

### 7.4 Streaming replies can spam VoiceOver with changing full text

Evidence: `MessageListView` scrolls on every streaming text change at `aiassistant/Views/Chat/MessageListView.swift:152`, and `StreamingBubble` exposes the full changing text as its accessibility label at `aiassistant/Views/Chat/MessageListView.swift:488`.

Impact: VoiceOver can repeatedly re-announce partial replies, making chat unusable during generation.

Recommendation: expose “Ari is responding” during streaming, then announce completion once.

### 7.5 Saved message bubbles expose entire message text as the accessibility label

Evidence: message bubbles set `"\(roleName): \(message.text)"` at `aiassistant/Views/Chat/MessageListView.swift:265`.

Impact: long assistant responses become extremely verbose and difficult to navigate by VoiceOver.

Recommendation: provide concise labels plus custom actions for copy/save/transform; leave full text selectable/readable inside the element.

### 7.6 Thread pinning is swipe-only

Evidence: pin/unpin is only exposed through `swipeActions` at `aiassistant/Views/Chat/ThreadListSheet.swift:114`.

Impact: users relying on keyboard, Voice Control, or some assistive workflows may not discover pinning.

Recommendation: add a trailing button/menu or `.accessibilityAction(named:)` for Pin/Unpin.

### 7.7 macOS search clear button is icon-only without an accessibility label

Evidence: `MacSearchField` uses an image-only button at `aiassistant/Views/Theme/MacContentHeader.swift:95`; it has `.help("Clear search")` at `aiassistant/Views/Theme/MacContentHeader.swift:103`, but no explicit accessibility label.

Impact: assistive technologies may expose the SF Symbol name or no useful label.

Recommendation: use `Button("Clear search", systemImage: "xmark.circle.fill")` with `.labelStyle(.iconOnly)`.

### 7.8 Quiz option rows lack selected/correct accessibility state

Evidence: `QuizOptionRow` renders selection and correctness through color/icon at `aiassistant/Views/Outputs/ArtifactDetailView.swift:804`, but the button has no accessibility value or selected trait at `aiassistant/Views/Outputs/ArtifactDetailView.swift:849`.

Impact: VoiceOver users may not know which answer is selected or whether a revealed answer is correct.

Recommendation: add labels/values such as “Selected”, “Correct answer”, and “Incorrect selection”.

### 7.9 Checklist bullets expose unlabeled circle buttons

Evidence: `BulletRow` uses an image-only button for check state at `aiassistant/Views/Outputs/ArtifactDetailView.swift:974`, with no accessibility label/value before `.buttonStyle(.plain)` at `aiassistant/Views/Outputs/ArtifactDetailView.swift:983`.

Impact: VoiceOver may announce only the symbol, not the checklist item or checked state.

Recommendation: label each checkbox with the item text and expose checked/unchecked state.

### 7.10 Flashcards use fixed height that can fail Larger Text

Evidence: `FlashcardView` forces a 220pt card height at `aiassistant/Views/Outputs/ArtifactDetailView.swift:471`, while the card content uses fixed font size at `aiassistant/Views/Outputs/ArtifactDetailView.swift:497`.

Impact: long card text or larger text settings can overflow or become visually cramped.

Recommendation: use adaptive min-height plus scroll/expand behavior for long flashcard content.

### 7.11 Quiz progress is color-only

Evidence: progress state is encoded in `progressColor(for:)` at `aiassistant/Views/Outputs/ArtifactDetailView.swift:704` and rendered as small bars at `aiassistant/Views/Outputs/ArtifactDetailView.swift:576`.

Impact: users with Differentiate Without Color enabled cannot infer answered/current/correct state from the progress bar alone.

Recommendation: add text, icons, or accessibility labels per segment.

### 7.12 Ari action identifiers include user-facing labels with spaces/punctuation

Evidence: Ari action identifiers interpolate `action.label` at `aiassistant/Views/Chat/AriGuidanceBar.swift:56` and `aiassistant/Views/Chat/AriGuidanceBar.swift:98`.

Impact: automation identifiers change when copy changes and can contain punctuation such as `What's next?`.

Recommendation: identify by enum case or stable slug, not display text.

## 8. Persistence, CloudKit, And Configuration Findings

### 8.1 CloudKit health only checks account status

Evidence: `refreshCloudKitHealth()` checks `CKContainer.accountStatus()` at `aiassistant/Views/Settings/SettingsView.swift:215`, while the actual persistence fallback is decided in `AIAssistantApp` at `aiassistant/aiassistantApp.swift:52`.

Impact: debug UI can say CloudKit is available even when the app is using the local fallback store.

Recommendation: pass actual container mode into Settings and display both account status and persistence mode.

### 8.2 StoreKit README file name is wrong

Evidence: README tells developers to use `aiassistant.storekit` at `README.md:34` and `README.md:62`, but the project references `ai.storekit` at `aiassistant.xcodeproj/project.pbxproj:34`.

Impact: local StoreKit setup instructions are wrong, slowing purchase QA.

Recommendation: update README or rename the StoreKit file.

### 8.3 README free tier limit disagrees with code and tests

Evidence: README says 10 messages/day at `README.md:45`, but code sets 3 at `aiassistant/Models/Monetization.swift:78` and tests assert 3 at `aiassistantTests/aiassistantTests.swift:71`.

Impact: product, support, and QA expectations diverge from actual gating behavior.

Recommendation: update README or change the monetization constant and tests intentionally.

### 8.4 StoreKit app policies are empty

Evidence: `ai.storekit` has empty `eula`, `policyText`, and `policyURL` at `ai.storekit:3` and `ai.storekit:7`.

Impact: local purchase QA does not mirror production legal/policy presentation, even though the app presents legal links at `aiassistant/Views/Settings/SubscriptionPaywallView.swift:228`.

Recommendation: populate StoreKit config policy fields or document why they intentionally differ.

### 8.5 StoreKit notes are bundled into app resources

Evidence: `StoreKitSchemaNotes.md` is included in Resources at `aiassistant.xcodeproj/project.pbxproj:248`.

Impact: developer-only notes are shipped in the app bundle.

Recommendation: remove notes from target resources.

## 9. Architecture And Maintainability Findings

### 9.1 ChatView owns too many responsibilities

Evidence: `ChatView` imports UI, SwiftData, file types, PDFKit, Vision, and ImageIO at `aiassistant/Views/Chat/ChatView.swift:7` and `aiassistant/Views/Chat/ChatView.swift:10`, and also implements import/OCR/PDF parsing at `aiassistant/Views/Chat/ChatView.swift:606`.

Impact: keyboard layout, file import, quota gating, and generation state are tightly coupled, increasing regression risk.

Recommendation: move attachment extraction/quota handling into focused services or small coordinators.

### 9.2 ArtifactDetailView mixes detail UI, parsers, games, and transforms

Evidence: the file includes artifact actions at `aiassistant/Views/Outputs/ArtifactDetailView.swift:85`, tag editing at `aiassistant/Views/Outputs/ArtifactDetailView.swift:196`, flashcard parsing at `aiassistant/Views/Outputs/ArtifactDetailView.swift:380`, quiz parsing at `aiassistant/Views/Outputs/ArtifactDetailView.swift:724`, and checklist parsing at `aiassistant/Views/Outputs/ArtifactDetailView.swift:909`.

Impact: output rendering bugs are hard to isolate and test.

Recommendation: split artifact renderers/parsers into separate files with parser unit tests.

### 9.3 Guided-generation schemas are unused

Evidence: `ArtifactSchemas.swift` says the Codable schemas are for guided generation at `aiassistant/Engines/ArtifactSchemas.swift:4`, but transforms use plain string prompts at `aiassistant/Engines/AssistantEngine.swift:282` and no schema types are referenced outside their declaration.

Impact: quiz/flashcard/checklist parsers must guess from text, causing fragile rendering.

Recommendation: either wire schemas into Foundation Models guided generation or remove the dead schema layer.

### 9.4 DataModel stores unused Output Studio state

Evidence: `DataModel` declares `isOutputStudioPresented` at `aiassistant/Engines/DataModel.swift:24`, while actual presentation state lives in `ChatView` at `aiassistant/Views/Chat/ChatView.swift:28`.

Impact: duplicate state invites future presentation bugs and makes ownership unclear.

Recommendation: remove the unused property or centralize presentation through it.

### 9.5 Message normalization rewrites user/model text with regexes before display

Evidence: `normalizedDisplayText` strips markdown and changes punctuation spacing at `aiassistant/Views/Chat/MessageListView.swift:10`, `aiassistant/Views/Chat/MessageListView.swift:21`, and `aiassistant/Views/Chat/MessageListView.swift:36`.

Impact: code snippets, markdown, URLs, citations, or exact text may be displayed differently from what was generated or copied.

Recommendation: render markdown with a proper parser or limit normalization to known safe cases.

### 9.6 Library and Outputs duplicate list/search patterns

Evidence: Outputs implements local filtering at `aiassistant/Views/Outputs/OutputsView.swift:25`; Library implements similar filtering at `aiassistant/Views/Library/LibraryView.swift:26`.

Impact: bug fixes to search empty states, performance, and accessibility must be repeated.

Recommendation: extract a shared search/list pattern only if behavior remains aligned.

## 10. Test Coverage Findings

### 10.1 Launch UI test does not use the app’s UI-test flags

Evidence: `aiassistantUITestsLaunchTests.testLaunch()` launches the app with no arguments at `aiassistantUITests/aiassistantUITestsLaunchTests.swift:22`.

Impact: launch screenshots can hit onboarding or real stores instead of deterministic app state.

Recommendation: use `-ui-testing` or explicitly validate onboarding if that is the intended launch surface.

### 10.2 StoreKit and entitlement flows are not exercised by UI tests

Evidence: normal app startup skips `subscriptionStore.start()` under UI testing at `aiassistant/aiassistantApp.swift:85`, while UI tests always pass `-ui-testing` at `aiassistantUITests/aiassistantUITests.swift:121`.

Impact: purchase restore, entitlement propagation, and premium gating bugs can pass UI tests.

Recommendation: add a separate StoreKit UI/integration suite with local StoreKit config and deterministic entitlements.

### 10.3 Compact layout tests can pass without validating compact layout

Evidence: compact chrome tests branch to a fallback regular-layout assertion if `chat.mode.compactMenu` is absent at `aiassistantUITests/aiassistantUITests.swift:52`, and mode/action tests do the same at `aiassistantUITests/aiassistantUITests.swift:84`.

Impact: a simulator/window size regression can make the compact test pass while not testing compact behavior.

Recommendation: force an iPhone compact destination and fail if compact controls do not appear in the compact-specific tests.

### 10.4 UI tests do not assert keyboard overlap geometry

Evidence: `testComposerFocusSendAndReplyVisibility` verifies existence of reply, composer, and message list at `aiassistantUITests/aiassistantUITests.swift:35`, but not frames or keyboard-safe position.

Impact: keyboard overlap can regress while tests still pass.

Recommendation: compare composer/message frame positions before and after focus, or add screenshot-based assertions.

### 10.5 UI tests do not verify software keyboard mode

Evidence: UI tests type into the field at `aiassistantUITests/aiassistantUITests.swift:28`, but no assertion checks software keyboard presence or hardware-keyboard state.

Impact: tests can pass in a hardware-keyboard environment that does not reproduce the compact iPhone software keyboard problem.

Recommendation: configure simulator keyboard state or include manual/device QA for software keyboard overlap.

### 10.6 Parser-heavy artifact views have little unit coverage

Evidence: tests cover message normalization at `aiassistantTests/aiassistantTests.swift:43`, but flashcard, quiz, and checklist parsers live in view code at `aiassistant/Views/Outputs/ArtifactDetailView.swift:380`, `aiassistant/Views/Outputs/ArtifactDetailView.swift:724`, and `aiassistant/Views/Outputs/ArtifactDetailView.swift:909` without direct tests.

Impact: generated output formatting changes can silently break artifact rendering.

Recommendation: move parsers into testable pure functions and add fixtures for expected model outputs and malformed input.

## 11. Verification Results And Residual Risk

### 11.1 Current automated verification passed

Result: XcodeBuildMCP simulator test run on iPhone 17 passed 15/15 tests with no warnings or errors. This reduces immediate risk of compiler/test breakage, but it does not cover the High issues in §4.1 through §4.9.

### 11.2 Manual Computer Use snapshot confirmed main chat controls are exposed

Result: the macOS app accessibility tree exposed sidebar tabs, chat toolbar buttons, mode options, upgrade teaser, composer, attach, and send controls. It also revealed the duplicate `chat.emptyState` identifier described in §6.1.

### 11.3 High-risk areas still need manual device verification

Must test on device or exact simulator setups:

- §4.4 and §10.4: final free-message send with software keyboard visible.
- §4.5: cancel during active streaming and verify late stream text does not reappear.
- §4.3: purchase, restore, lifetime purchase, and immediate use of file upload/Output Studio/Library summary.
- §4.6 and §8.1: CloudKit unavailable, no iCloud account, and fallback store state.
- §7.1 through §7.11: Larger Text, VoiceOver, Voice Control, Reduce Motion, Differentiate Without Color.

## 12. Prioritized Remediation Plan

### 12.1 Release-blocking fixes

1. Gate UI-test launch flags behind debug/test-only compilation (§4.1).
2. Replace generated error strings with typed failures and transient UI (§4.2, §4.8).
3. Unify entitlement state across paywall and feature gates (§4.3).
4. Defer the message-limit paywall until generation completes (§4.4).
5. Add generation IDs/cancellation guards for streaming (§4.5).
6. Add explicit paywall product-load error/empty state (§4.9).

### 12.2 Chat and keyboard hardening

1. Fix duplicate empty-state identifiers (§6.1).
2. Add geometry-based keyboard UI tests (§10.4).
3. Enforce compact hit targets for mode chips, actions, and Ari controls (§6.2-§6.5).
4. Reduce VoiceOver verbosity during streaming and long messages (§7.4, §7.5).

### 12.3 Data and performance cleanup

1. Move quota counting to bounded SwiftData predicates (§5.1, §5.2).
2. Cap attachment extraction by file size and prompt budget (§5.7).
3. Cache or query sorted messages instead of sorting repeatedly (§5.14).
4. Move artifact parsers into testable units and add fixtures (§10.6).

### 12.4 Documentation and config cleanup

1. Fix README StoreKit filename and free-limit drift (§8.2, §8.3).
2. Remove developer notes from app resources (§8.5).
3. Populate or intentionally document empty StoreKit policy fields (§8.4).
