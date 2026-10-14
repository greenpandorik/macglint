# MacGlint Native App Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkboxes for tracking.

**Goal:** Build and run a useful native menu bar app with real metrics, process controls, history, personal rules, themes, and a local installation bundle.
**Architecture:** Pure Swift core owns metric arithmetic, alert state and bounded history. A small Darwin C bridge collects system/process facts; SwiftUI and AppKit present a main-actor store. No external runtime dependencies or service.
**Tech Stack:** Swift Package Manager, SwiftUI, AppKit, Charts, UserNotifications, IOKit, libproc; macOS 14+, Apple Silicon first.
**Spec:** docs/superpowers/specs/2026-10-14-air-design.md

## Global Constraints

- Data stays local. No automatic process termination. Verify PID, start time, UID immediately before a requested action.
- CPU uses 0–100% of total machine capacity in every view and rule.
- Missing observations stay missing; reset rate baselines and pending alerts across sleep/gaps.
- Safari tab attribution is not established; show truthful process names and unknown association.
- This iteration keeps 24h of system history and 2 minutes of process samples; 7-day aggregation is deferred, visibly documented.
- No Developer ID identity is available locally. Build an ad-hoc-signed local app and DMG; do not represent it as notarized or publish a public installer.
- User explicitly asked to proceed with implementation after the published design. Execute inline without another design permission step; use the dedicated checkout on feat/native-app (the chat itself is attached to a non-Git reference directory).

## Review Focus

- Counter resets and long sampling gaps must not become huge CPU/network spikes (Task 1).
- PID reuse, other-user ownership, and the monitor's own PID must not receive signals (Task 2).
- Alert duration, hysteresis, missing input, pause and app exceptions must avoid false repeats (Task 1).
- Corrupt history/settings and stale processes must leave a usable UI, without fabricated zeros or destructive actions (Tasks 1, 3).
- Menu-bar-only lifecycle, permission denial, window pinning and release bundle launch must work outside a terminal (Task 3).

### Task 1: Core metrics, rules and history

**Files:** Package.swift; Sources/MacGlintCore/{Models,AlertEngine,HistoryStore}.swift; Tests/MacGlintTests/CoreTests.swift.
**Interfaces:** MetricSnapshot, ProcessIdentity, ProcessSample, AlertRule, AlertEvent are Codable value types. AlertEngine.evaluate(snapshot:processes:rules:excludedApps:paused:uptime:) returns [AlertEvent]. HistoryStore persists bounded system snapshots/events, never routine process dumps.
- [ ] Write tests for duration/recovery/cooldown, missing/gapped measurements, paused/excluded rules, counter reset, stale identity and bounded persistence.
- [ ] Run swift test; observe failure before implementation.
- [ ] Implement arithmetic and alert state transitions; persistence is atomic and bounded to 24 hours/500 events, with backup of corrupt input.
- [ ] Run swift test; expect all tests pass. Commit.

### Task 2: Real macOS sampling and guarded termination

**Files:** Sources/CMacGlint/include/MacGlintSystem.h, Sources/CMacGlint/MacGlintSystem.c; Sources/MacGlintSystem/SystemSampler.swift; Tests/MacGlintTests/SystemTests.swift.
**Interfaces:** SystemSampler.sample() returns SystemReading with MetricSnapshot and [ProcessSample]. ProcessController.terminate(identity:force:) throws on stale or forbidden targets.
- [ ] Write integration tests against self metrics and a spawned /bin/sleep child; reject altered start time, protected PID and different owner.
- [ ] Run swift test; observe missing-feature failures.
- [ ] Implement CPU, memory pressure/usage, network, battery, disk and process snapshots with monotonic deltas; normalize to logical core capacity.
- [ ] Run swift test; verify only owned disposable child is signalled. Commit.

### Task 3: Native UI, notifications and local app packaging

**Files:** Sources/MacGlint/{Main,AppStore,RootView,ProcessView,HistoryView,SettingsView,Components}.swift; Resources/Info.plist; scripts/build-app.sh; scripts/make-dmg.sh; .github/workflows/build.yml.
**Interfaces:** AppStore owns user settings and view state; background sampler updates main actor, HistoryStore and AlertEngine. Native panel lifecycle managed by app delegate. Build script outputs build/MacGlint.app.
- [ ] Write tests for settings validation/persistence and process grouping, including unknown Safari content; observe failures.
- [ ] Implement settings and grouping; run suite.
- [ ] Implement menu bar, compact/expanded modes, themes, process selection and guarded confirmation, history charts/event navigation, editable rules and notification permission status.
- [ ] Implement app bundle and DMG packaging with ad-hoc signature; add build/test CI without signing secrets.
- [ ] Run swift test and release build, validate bundle/signature, launch and inspect both themes and interactions through native UI.
- [ ] Conduct fresh whole-branch review, fix important findings, update honest README/status, commit and push; deliver app and DMG locally.
