# Major and Medium Bug Audit

Snapshot date: 2026-06-04

Build status: Bitrig build succeeded with no diagnostics. `xcodebuild test` was attempted on iPhone 17 / iOS 26.5; it built the test runner but hung during simulator test launch with repeated `DebuggerVersionStore.StoreError` messages, so the stuck `xcodebuild` process was stopped.

Fix status: All findings in this report were addressed on 2026-06-04. Verification after the fix: Bitrig build succeeded, and `xcodebuild test -project aiassistant.xcodeproj -scheme aiassistant -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:aiassistantTests` passed 9/9 unit tests.

## 1. Executive Summary

1. **[High] Failed AI generations consume the free daily quota** - §2.1 - `aiassistant/Engines/DataModel.swift:68`, `aiassistant/Views/Chat/ChatView.swift:552`
2. **[High] Chat cancellation can persist a cancelled user message and still count it against the user** - §2.2 - `aiassistant/Engines/DataModel.swift:96`, `aiassistant/Views/Chat/ChatView.swift:639`
3. **[Medium] Outputs can show stale empty or filtered state after data changes elsewhere** - §3.1 - `aiassistant/Views/Outputs/OutputsView.swift:18`, `aiassistant/Views/Outputs/OutputsView.swift:155`
4. **[Medium] Library can show stale empty or search results after data changes outside its add sheet** - §3.2 - `aiassistant/Views/Library/LibraryView.swift:19`, `aiassistant/Views/Library/LibraryView.swift:146`
5. **[Medium] Navigation destinations depend on filtered in-memory arrays, so valid records can appear unavailable** - §3.3 - `aiassistant/Views/Outputs/OutputsView.swift:104`, `aiassistant/Views/Library/LibraryView.swift:85`
6. **[Medium] Long-running transforms and summaries are not actually cancelled at the model-session level** - §4.1 - `aiassistant/Views/Chat/OutputStudioSheet.swift:130`, `aiassistant/Engines/AssistantEngine.swift:340`
7. **[Medium] Foundation Models availability is not checked before starting requests** - §5.1 - `aiassistant/Engines/AssistantEngine.swift:155`, `aiassistant/Engines/AssistantEngine.swift:239`
8. **[Medium] Quiz parsing can make generated quizzes unanswerable when the correct-answer line is verbose** - §6.1 - `aiassistant/Views/Outputs/ArtifactDetailView.swift:851`

## 2. Monetization / Quota Bugs

### 2.1 Failed AI generations consume the free daily quota
- **Location:** `aiassistant/Engines/DataModel.swift:68-105`, `aiassistant/Views/Chat/ChatView.swift:552-565`, `aiassistant/Views/Chat/ChatView.swift:639-647`
- **What:** `sendMessage` inserts a user `Message` before generation, marks it `.failed` when generation fails, and `ChatView` counts all user messages for the daily limit regardless of `statusRaw`.
- **Why:** A free user can lose all 3 daily messages to unavailable Foundation Models, transient model errors, or other failed generations without receiving assistant replies.
- **Action:** Count only completed user turns, or use a separate quota ledger that is committed after a successful assistant response. If failed user bubbles should remain visible, exclude `statusRaw == failed` and probably `cancelled` from the quota fetch.
- **Severity:** High

### 2.2 Chat cancellation can persist a cancelled user message and still count it against the user
- **Location:** `aiassistant/Engines/DataModel.swift:96-99`, `aiassistant/Views/Chat/ChatView.swift:612-618`, `aiassistant/Views/Chat/ChatView.swift:639-647`
- **What:** Cancelling generation marks the already-inserted user message as `.cancelled`, then the daily quota query still counts it because it filters only `roleRaw == "user"`.
- **Why:** A user who taps Stop or navigates away after sending can consume quota without receiving a usable answer.
- **Action:** Treat cancellation as a non-billable/non-quota event unless product requirements explicitly say otherwise. Either delete cancelled user turns or exclude cancelled status from the daily count.
- **Severity:** High

## 3. Stale Data / Navigation Bugs

### 3.1 Outputs can show stale empty or filtered state after data changes elsewhere
- **Location:** `aiassistant/Views/Outputs/OutputsView.swift:18-19`, `aiassistant/Views/Outputs/OutputsView.swift:47-50`, `aiassistant/Views/Outputs/OutputsView.swift:155-157`, `aiassistant/Views/Outputs/OutputsView.swift:190-194`
- **What:** `OutputsView` stores fetched artifacts in `@State` and refreshes only on appear, search, and filter changes.
- **Why:** If the Outputs tab has already been created, saving an output from Chat or Output Studio may not update the tab until it reappears or the user changes filters/search. The empty state is especially risky because it depends on stale `totalArtifactCount`.
- **Action:** Prefer `@Query` for the base artifact collection, or observe model changes and refresh whenever the view becomes active or the backing data changes.
- **Severity:** Medium

### 3.2 Library can show stale empty or search results after data changes outside its add sheet
- **Location:** `aiassistant/Views/Library/LibraryView.swift:19-20`, `aiassistant/Views/Library/LibraryView.swift:53-56`, `aiassistant/Views/Library/LibraryView.swift:128`, `aiassistant/Views/Library/LibraryView.swift:146-148`
- **What:** `LibraryView` also stores fetched items and counts in `@State`, refreshing on appear, search, and add-sheet dismissal only.
- **Why:** Detail-level summary edits and future library mutations from intents/widgets/sync can leave the list, count, or empty state stale while the tab remains mounted.
- **Action:** Use a live query for the base library items or centralize library state in an `@Observable` model that refreshes on every mutation path.
- **Severity:** Medium

### 3.3 Navigation destinations depend on filtered in-memory arrays, so valid records can appear unavailable
- **Location:** `aiassistant/Views/Outputs/OutputsView.swift:104-112`, `aiassistant/Views/Library/LibraryView.swift:85-93`, `aiassistant/Views/Outputs/ArtifactDetailView.swift:192-200`
- **What:** Navigation resolves IDs by searching the current filtered `artifacts` or `items` arrays instead of fetching by ID from SwiftData.
- **Why:** A valid selected record can render as “unavailable” if the local array is stale or the user/filter state changes while navigation is active. The same pattern exists for transformed artifact navigation in detail.
- **Action:** Resolve destination IDs with a descriptor fetch by UUID, or pass stable model objects through navigation only when the source collection is live and unfiltered.
- **Severity:** Medium

## 4. Cancellation / Async Bugs

### 4.1 Long-running transforms and summaries are not actually cancelled at the model-session level
- **Location:** `aiassistant/Views/Chat/OutputStudioSheet.swift:130-132`, `aiassistant/Views/Library/LibraryView.swift:495-497`, `aiassistant/Views/Outputs/ArtifactDetailView.swift:203-205`, `aiassistant/Engines/AssistantEngine.swift:340-400`
- **What:** Views cancel their wrapper `Task`, but transform and summary requests create local `LanguageModelSession` instances that are not retained or explicitly stopped like chat generation is.
- **Why:** Dismissing a sheet/detail can leave expensive model work running until the request naturally returns. The UI ignores the result, but device resources and latency are still affected.
- **Action:** Track cancellable operation IDs or retained sessions for transforms/summaries, and check cancellation before and after the Foundation Models call. If the API supports explicit cancellation through session lifetime, wire it consistently with chat generation.
- **Severity:** Medium

## 5. Foundation Models Bugs

### 5.1 Foundation Models availability is not checked before starting requests
- **Location:** `aiassistant/Engines/AssistantEngine.swift:155-190`, `aiassistant/Engines/AssistantEngine.swift:239-249`, `aiassistant/Engines/AssistantEngine.swift:335-400`
- **What:** The engine creates `LanguageModelSession` and starts generation/summarization/transform requests without checking `SystemLanguageModel.default.availability`.
- **Why:** On devices where the framework exists but the model is unavailable, disabled, downloading, or unsupported, users get generic request failures after they send content instead of a clear up-front unavailable state.
- **Action:** Gate all Foundation Models entry points with an availability check and surface a specific fallback message in the UI before inserting quota-counted user messages.
- **Severity:** Medium

## 6. Generated Output Parsing Bugs

### 6.1 Quiz parsing can make generated quizzes unanswerable when the correct-answer line is verbose
- **Location:** `aiassistant/Views/Outputs/ArtifactDetailView.swift:851-857`, `aiassistant/Views/Outputs/ArtifactDetailView.swift:680-690`, `aiassistant/Views/Outputs/ArtifactDetailView.swift:715-721`
- **What:** The parser sets `correctLetter` to the first character after `Correct:` or `Answer:`. If the model emits `Correct: The answer is B` or `Answer: B) Photosynthesis`, the stored correct letter becomes `T` or `B` depending on phrasing, with no validation against available options.
- **Why:** A parsed quiz can show every selectable answer as incorrect, or display an answer letter that is not one of the options.
- **Action:** Extract the first valid `A`-`D` answer token with a regex and validate it against the parsed options. If no valid answer exists, fall back to raw text instead of interactive quiz UI.
- **Severity:** Medium

## 7. Verification

- **§2.1** - Verified that `DataModel.sendMessage` inserts the user message before generation and marks it failed on generation error; verified quota count filters only `roleRaw == "user"`.
- **§2.2** - Verified cancellation marks the inserted user message cancelled and the same quota count includes it.
- **§3.1** - Verified `OutputsView` uses `@State` arrays/counts and refreshes only on view appear, search, or filter change.
- **§3.2** - Verified `LibraryView` uses the same `@State` fetch-cache pattern.
- **§3.3** - Verified navigation destination resolution searches the current local arrays rather than fetching by selected UUID.
- **§4.1** - Verified wrapper tasks are cancelled on disappear, while transform/summary sessions are local to engine methods and have no retained cancellation hook.
- **§5.1** - Verified Foundation Models methods are entered directly under `#if canImport(FoundationModels)` without availability checks.
- **§6.1** - Verified quiz parser takes the first post-prefix character and does not validate it against answer options.
