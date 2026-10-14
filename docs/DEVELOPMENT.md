# Native preview development

Requires macOS 14+, Swift 5.9+ and Apple command-line tools. Tested with Xcode 26.4 / macOS 26 on Apple Silicon; Intel and the macOS 14 minimum have not yet been runtime-tested.

```sh
swift test
./scripts/build-app.sh
open build/MacGlint.app
./scripts/make-dmg.sh
```

The scripts create a host-architecture `.app` and DMG in ignored `build/`. They use an ad-hoc signature and no signing credentials. Launch the app bundle, not the raw SwiftPM executable: notification APIs require bundle identity.

## Structure

- `MacGlintCore`: metric math, rule engine, bounded JSON history, preferences and grouping.
- `CMacGlint`: Mach/libproc, 64-bit network interface counters, IOKit battery, disk and process controls.
- `MacGlintSystem`: serial actor collector, process identity and rate baselines.
- `MacGlint`: AppKit status item, transient compact panel, independent resizable detail window, and SwiftUI views, settings and notifications.

No external runtime packages or analytics. The app does not send measurements over the network.

## Measurement and behavior

CPU uses a consistent whole-machine 0–100% scale, unlike Activity Monitor's per-core process scale. Process CPU Mach ticks are converted with the platform timebase; an integration test checks them against `getrusage`. Memory uses physical footprint per process; app totals need not equal system used memory. App grouping follows executable containment in an `.app`; generic WebKit XPCs remain separate and may serve multiple clients.

Network speed sums valid per-interface deltas from `NET_RT_IFLIST2` 64-bit counters for physical `en*` interfaces. New/reset counters have no invented rate. It is not a per-app bandwidth meter.

Sampling runs off the UI actor, about every 2 seconds while visible and 6 seconds while hidden. History keeps a point about every 10–12 seconds, at most 24 hours / 8,640 points and 500 events. Process CPU traces are in memory for two minutes. Wake resets sampling baselines and pending alert durations. Missing measurements are unavailable, not zero.

History lives in `~/Library/Application Support/MacGlint/history.json`; settings use the `app.macglint.MacGlint` defaults domain. History is saved atomically about every minute and on normal exit. Abrupt exit may lose the most recent minute. A corrupt history file is preserved once as `history.corrupt.json`. Event records may include a process name, executable path, PID and metrics; never upload this local file unredacted.

Normal termination asks a running app to quit when possible, otherwise sends SIGTERM. Force termination sends SIGKILL. Both require confirmation and recheck PID, owner and start time. No elevation, automatic termination, self-termination or PID 1 termination. There remains an unavoidable tiny check-to-signal race in PID-based Unix APIs; stale identities are rejected.

Rules are sustained thresholds with recovery hysteresis and repeat cooldown. Per-app exclusions apply to app rules, not system rules. Pausing suppresses event creation as well as notifications. OS notification permission is opt-in. Login launch is opt-in through ServiceManagement; install in Applications before enabling it.

## Known limits

- Russian UI only; selected compact Air direction, not pixel-identical to AI mockups.
- No reliable Safari tab attribution or tab close controls.
- No 7-day history, export, app bandwidth, Sparkle updates or Homebrew cask yet.
- Ad-hoc local build, not Apple notarized. OS notification delivery and login launch depend on system permissions and installation; they still need clean-machine release validation.
- No formal long-running energy or accessibility certification yet.
- The app must run to gather history and detect alerts.

## Window behavior (0.2.0)

Left click on the menu bar icon always toggles the compact panel. Opening full details dismisses the compact panel and reveals a persistent resizable window with native close/minimize controls and Processes, Memory Growth, History, Settings navigation. Right click provides both entry points plus Settings and Quit. The full window appears in the Dock while open; closing it returns to menu-bar-only operation. Reopening the application reveals the full window, providing an alternative if the menu bar is crowded.

Esc, outside clicks, or focus loss dismiss the compact panel only. The pin applies to the full window. While MacGlint is active, Cmd+0 opens the mini panel, Cmd+1 opens full details, Cmd+, opens Settings, and Cmd+F focuses process search. These are app shortcuts, not global hotkeys.

Rule editing keeps raw numeric text until validation, so invalid text cannot silently save the previous value. Only CPU/memory can be selected for app-specific rules. Saved exclusions remain editable after the app exits. Process child sorting follows the selected column.


## History insights (0.3.0)

System points retain their ~10–12 second cadence. `Episode` summaries capture the union of the top three groups by CPU and top three by memory for the current user, every ~30–36 seconds (at most six groups, 2,880 summaries, 24 hours). New alerts also carry an exact episode and a copy of the triggering rule; editing a rule later does not rewrite its historical condition. Summaries contain names, grouping keys (which may be paths), group metrics, counts and a representative process identity. All remain local.

Click/drag the history chart, use the previous/next controls, or choose Latest snapshot. An event anchors the visible time range until returning to live time. Summary timestamps are explicit because system points and app summaries have different cadences. A summary more than 18 seconds away is not substituted. Legacy archives/events lacking the optional fields still load; the UI states that their app context is unavailable. The list is a bounded top sample, not all running apps and not proof of the cause of a slowdown.

Memory growth observes every collected reading. Per group, it compares the oldest point within 600 seconds with the newest, requiring at least 60 seconds; at most 301 points per live group. Missing memory, disappearance, disjoint process identities, backwards time, wake or a gap over 30 seconds resets that group's baseline. Composition changes during the interval are labelled. The view shows positive differences of at least 1 MB; before/after values use MB to avoid hiding smaller differences through GB rounding. Comparisons are in memory only and reset on app restart. Added/removed helper processes can change a group's total; growth is not a memory-leak diagnosis.

Event actions open only an exact still-live process identity, never a recycled PID, and do not terminate anything automatically. Editing routes to the current rule; deleted rules are disabled explicitly. Pausing one rule for an hour suppresses its event creation and notifications while allowing other rules to run. Resume is available in both the card and Settings. The mute expiration persists locally; resuming starts a fresh duration measurement after the rule has been evaluated while muted.

The full hosting view does not derive a growing window minimum from lazy list content. Native window minimums and the restored frame are bounded by the visible screen; content scrolls within the window.
