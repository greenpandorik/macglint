# History insights implementation plan

> Execute inline with superpowers:executing-plans; review the whole change before publishing.

**Goal:** Ship MacGlint 0.3.0 with historical app context, memory growth and actionable alert cards.
**Design:** Extend existing local history and navigation. Capture up to six user-owned app/process groups (union of top three CPU and memory) every 30 seconds, keep 24 hours, attach exact context to new alerts. Existing 10-second system history stays readable. Memory growth uses a bounded, in-memory 10-minute window with at least 60 seconds of continuous observations; missing values, restarts and sleep reset comparisons. Composition changes are labelled. No causal or memory-leak diagnosis.
**Stack:** Existing SwiftUI/AppKit/Core package, no new dependencies, macOS 14+.
**Scope source:** User-approved three features in the preceding conversation.

## Constraints and review focus
- Backward-compatible JSON and preferences; never discard old history merely because new fields are absent.
- No comparison across gaps over 30 seconds, missing readings or a restarted process group.
- No stale PID action: historical process links require the same process identity; no automatic termination.
- Bounded retention and capture cadence; real local data never enters Git.
- Old events and deleted rules have explicit unavailable states; muted rules can be resumed.

## Tasks
- [x] Add tests for episode ranking, nearest-sample gaps, archive compatibility/retention, memory baseline/gaps/restarts/composition, per-rule mute and legacy preferences. Run red.
- [x] Implement Episode, MemoryGrowthTracker, optional archive/event context and per-rule mute; run full tests.
- [x] Integrate sampling and navigation; add history selection/detail, Growth view and alert actions. Preserve draft navigation protection.
- [x] Build and check native UI with real data; use synthetic data only in tests. Check empty/legacy states, chart selection and rule navigation.
- [x] Review, bump 0.3.0, document data cadence and limitations, build and verify DMG.

Publication: commit the reviewed changes and fast-forward main, then push to the existing public origin under the user's explicit authorization.

## Verification record

- 2026-10-14: 34 tests pass (11 new). New tests were run failing before the corresponding implementation.
- Final production build, strict ad-hoc signature verification and DMG checksum verification passed. The installer is an arm64 local preview, not Apple-notarized.
- Independent review found two important issues: losing the historical chart range when selecting a point after an old event, and skipping missing memory readings between persisted samples. Fixed both with regression tests. Comparison readiness now also resets after missing data.
- Native checks on Apple Silicon / macOS 26: chart click and previous-slice navigation; legacy events without context; new event context survives restart; original-rule editing opens the correct sheet; per-rule pause and resume; exact live-process navigation; readable growth cards in light and dark themes.
- Fixed full-window sizing so a long list does not enlarge the window beyond the visible display. Restored the user's dark appearance and resumed the rule temporarily paused during QA. No real processes were terminated and no history was cleared.
- Older app details are intentionally unavailable. Growth requires at least one minute of continuous observations and is local to the current run. No Safari-tab attribution or memory-leak diagnosis is claimed.
