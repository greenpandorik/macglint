<div align="center">

# MacGlint

**A clearer view of your Mac.**

A native macOS menu bar system monitor — CPU, memory, processes, history, and personal alerts.

![Stage: local preview](https://img.shields.io/badge/stage-local_preview-64748b?style=flat-square)
![Platform: macOS](https://img.shields.io/badge/platform-macOS-2563eb?style=flat-square)
![AI-assisted project](https://img.shields.io/badge/made_with-AI_assistance-0f766e?style=flat-square)

[Русский](README.ru.md) · [Feature guide (RU)](docs/FEATURES.md) · [Installation](docs/INSTALLATION.md) · [Designs](docs/design/README.md) · [Roadmap](docs/ROADMAP.md) · [Suggest an idea](https://github.com/greenpandorik/macglint/issues/new/choose)

</div>

> **Personal project, built with AI assistance.** I'm building MacGlint primarily for myself: I want a system monitor that feels clear, modern, and comfortable to use every day. AI helps me explore the design, write documentation, and develop the project. I'm sharing the work publicly in case someone else finds it useful.

> **Current stage: working native preview (0.4.0).** The app builds and runs locally. Public Apple-notarized downloads are not available yet. Interface images below are the original AI-generated design concepts with sample data; they are not screenshots of the current app.

## Installation status

There is **no published GitHub Release yet**. The ready-made local 0.4.0 DMG is for Apple Silicon and can be shared for testing, but it is ad-hoc signed and not Apple-notarized: macOS may block a downloaded copy. Running a ready-made DMG does not require Xcode. See the [installation guide (RU)](docs/INSTALLATION.md) for drag-to-Applications steps, updates and the public-release checklist.

For now, the reproducible route is to build the preview yourself. Successful [GitHub Actions runs](https://github.com/greenpandorik/macglint/actions/workflows/build.yml) also provide temporary test DMGs with 14-day retention. They are not a stable release channel. Homebrew and in-app updates are not available yet.

## Build the preview

Requires **macOS 14+**, Xcode command-line tools with Swift 5.9+, and Git. Tested locally on Apple Silicon with macOS 26 / Xcode 26.4. The current interface is Russian.

```sh
git clone https://github.com/greenpandorik/macglint.git
cd macglint
./scripts/build-app.sh
open build/MacGlint.app
```

To make a drag-to-Applications installer, run `./scripts/make-dmg.sh`. It creates a DMG in `build/` for your Mac's architecture. Both scripts produce a **local ad-hoc signed build**, not an Apple-notarized release. Do not disable Gatekeeper to install a downloaded build.

Signed GitHub Releases and Homebrew installation are next steps. See [installation details](docs/INSTALLATION.md).

## The idea

Click the menu bar icon for a compact panel. Choose **Open full window** for a separate, resizable window with Processes, Memory Growth, History, and Settings. Closing that window keeps monitoring active. Click a compact metric to open the relevant process sort. Look back at a slowdown, or get an alert when a problem persists.

MacGlint is being designed around a simple path: **overview → application → process → action**.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/design/air-expanded-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="docs/design/air-expanded-light.png">
  <img alt="MacGlint concept: an expanded macOS system monitor with grouped processes, a detail chart, and termination controls. Sample data." src="docs/design/air-expanded-light.png" width="1100">
</picture>

*Early design concepts use the working name **Air**. The project is now called **MacGlint**. The mockups currently show a Russian interface; the native preview currently uses Russian.*

## Available in the native preview

| Feature | What you can do |
|---|---|
| **Menu bar overview** | CPU, used memory and pressure, upload/download speed, battery/power, free disk and the top CPU group. Choose CPU, memory and download speed for the menu bar itself. |
| **Expandable process view** | Search and sort applications, expand their processes, and inspect a selected process. |
| **Process controls** | Request normal termination or explicitly confirm a force quit for an accessible process. |
| **Light, dark, and system themes** | Keep the same readable layout in either appearance. |
| **Detailed history** | Select a moment on the graph to see system metrics and the recorded top CPU/memory groups. |
| **Memory growth** | Compare current process-group memory with up to ten minutes of continuous observations. |
| **Alert cards** | Inspect the event snapshot and original threshold; edit or pause its rule, or open a still-running process. |
| **Personal alert rules** | Set thresholds and durations for overall load, individual apps, memory pressure, and free disk space. |
| **Quiet notifications** | Ignore brief spikes, suppress repeats, add exceptions, or pause alerts. |
| **Window controls** | Pin the full window, return to the mini panel, close the window while monitoring continues, or explicitly quit. |
| **Settings and startup** | General, Notifications and About panes; optional launch at login after installing in Applications. |
| **Local data** | Bounded history and settings remain on the Mac; clear history with confirmation. No measurement uploads or analytics. |

Alerts never automatically terminate processes. History is bounded to 24 hours; selected-process CPU traces cover up to two minutes while the app is running. Rules support CPU and memory for an app, plus CPU, memory, memory pressure, and free disk space for the whole Mac. Per-app exclusions suppress that app’s rules; they do not silence whole-Mac rules.

Historical app summaries start with version 0.3.0 and are captured roughly every 30 seconds, plus exactly when an alert fires. Old data remains readable without invented app details. Memory-growth comparisons need at least a minute, reset across missing data/restarts, and do not diagnose memory leaks. [Details and limits](docs/DEVELOPMENT.md#history-insights-030).

## Using the app

- **Processes:** search by name or PID, filter your own processes, sort CPU/memory, expand groups, inspect the executable path and a two-minute CPU trace. Both normal and forced termination require confirmation and a fresh identity check.
- **History:** 15-minute, one-hour and 24-hour views for CPU, memory, memory pressure, download speed and free disk; click the graph, step between samples, or select an alert. Historical summaries contain up to six groups, not every process.
- **Memory Growth:** searchable rows show before/after memory and the actual comparison duration. At least one minute is required; comparisons cover up to ten minutes in the current session and show increases of 1 MB or more. Process-composition changes are labelled.
- **Alerts:** choose a threshold, required duration and repeat interval. Pause all rules or one rule for an hour, resume early, or exclude selected apps. Pauses suppress both event creation and notifications; disabling notification banners alone still records events. A delivered notification opens its event.
- **Appearance:** light/dark/system themes, compact navigation and flat history/growth rows. Live summary metrics appear on Processes; history shows the selected moment separately.

App shortcuts: **⌘0** mini panel, **⌘1** full window, **⌘,** Settings, **⌘F** process search, **⌘W** close window, **⌘M** minimize, **⌘Q** quit; **Esc** dismisses the mini panel or cancels the rule editor. These are not global hotkeys. [Complete feature guide and limits (RU)](docs/FEATURES.md).

## Not implemented yet

Verified Safari-tab attribution or tab controls; per-app network bandwidth; GPU/temperature/fan monitoring; seven-day history/export; automatic memory-leak diagnosis; context-aware quiet mode such as “while Figma is open”; English UI; Homebrew; automatic updates. Intel and the macOS 14 minimum still need runtime validation. Monitoring must be running to collect data.

## Design previews

<details>
<summary><strong>Compact menu bar overview</strong></summary>

![Compact light concept](docs/design/air-compact-light.png)

</details>

<details>
<summary><strong>Expanded view — light</strong></summary>

![Expanded light concept](docs/design/air-expanded-light.png)

</details>

<details>
<summary><strong>Expanded view — dark</strong></summary>

![Expanded dark concept](docs/design/air-expanded-dark.png)

</details>

## A note about Safari

Safari is my main browser, so understanding its resource use matters to this project. Accessible Safari and generic WebKit processes are monitored. **Accurate CPU and memory attribution to individual tabs is still a research question.**

MacGlint will not label a process as a particular website without a verified mapping. The [Safari research note](docs/research/safari.md) records the available evidence and the checks a prototype needs to pass.

## Development

Built with **Swift, SwiftUI, AppKit, and small native C collectors**. No third-party runtime packages. CPU is normalized to the whole Mac (0–100%); process memory is physical footprint. Network speed uses 64-bit counters for physical `en*` interfaces, avoiding double counting VPN tunnels. Generic WebKit processes are kept separate.

The data model is local: settings and bounded monitoring history stay on the Mac. AI-assisted development does not mean that process information or browsing data needs to be sent to an AI service.

| Step | Status |
|---|---|
| Visual direction and light/dark concepts | Available |
| Product specification and roadmap | Available |
| Safari tab-attribution feasibility | To investigate |
| Working native application | Local preview available |
| App / DMG build scripts | Available (ad-hoc signed) |
| Apple-notarized public release | Pending signing, notarization, clean-Mac validation and release publication |

Run `swift test` for metric, alert, history, preference, and guarded process-control checks. Tests only terminate a child process they create. GitHub Actions builds the app and DMG as test artifacts. See [development and limitations](docs/DEVELOPMENT.md). Detailed planning documents are in Russian.

## Explore the project

- [Product specification](docs/superpowers/specs/2026-10-14-air-design.md) — behavior, proposed architecture, and limits.
- [Roadmap](docs/ROADMAP.md) — implementation stages and acceptance criteria.
- [Installation guide](docs/INSTALLATION.md) — current options, DMG installation, updates and release checklist.
- [Feature guide (RU)](docs/FEATURES.md) — every current feature, shortcuts and measurement limits.
- [Design archive](docs/design/README.md) — chosen direction and earlier alternatives.
- [Safari research](docs/research/safari.md) — findings and unresolved questions.
- [Contributing](CONTRIBUTING.md) — how to share useful feedback at this stage.

Ideas and practical use cases are welcome through [GitHub Issues](https://github.com/greenpandorik/macglint/issues). This is a personal project, so priorities follow everyday use rather than a fixed release schedule.

---

Created by [Mikhail Volkov](https://github.com/greenpandorik), with AI assistance for design and development.
