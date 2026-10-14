<div align="center">

# MacGlint

**A clearer view of your Mac.**

A macOS menu bar system monitor in the making — CPU, memory, processes, history, and personal alerts.

![Stage: concept](https://img.shields.io/badge/stage-concept_%26_design-64748b?style=flat-square)
![Platform: macOS](https://img.shields.io/badge/platform-macOS-2563eb?style=flat-square)
![AI-assisted project](https://img.shields.io/badge/made_with-AI_assistance-0f766e?style=flat-square)

[Русский](README.ru.md) · [Designs](docs/design/README.md) · [Roadmap](docs/ROADMAP.md) · [Suggest an idea](https://github.com/greenpandorik/macglint/issues/new/choose)

</div>

> **Personal project, built with AI assistance.** I'm building MacGlint primarily for myself: I want a system monitor that feels clear, modern, and comfortable to use every day. AI helps me explore the design, write documentation, and develop the project. I'm sharing the work publicly in case someone else finds it useful.

> **Current stage:** design and specification. There is no application code, installer, or release yet. Every interface image below is an AI-generated concept with sample data, not a screenshot of a working app.

## The idea

Open a small panel to see how your Mac is doing. Expand a metric to find the apps behind it. Look back at a slowdown, or get an alert when a problem persists.

MacGlint is being designed around a simple path: **overview → application → process → action**.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/design/air-expanded-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="docs/design/air-expanded-light.png">
  <img alt="MacGlint concept: an expanded macOS system monitor with grouped processes, a detail chart, and termination controls. Sample data." src="docs/design/air-expanded-light.png" width="1100">
</picture>

*Early design concepts use the working name **Air**. The project is now called **MacGlint**. The mockups currently show a Russian interface; supported application languages have not been decided.*

## Planned features

| Feature | What it should help you do |
|---|---|
| **Menu bar overview** | Check CPU, memory, network speed, and battery; choose which metrics stay visible. |
| **Expandable process view** | Search and sort applications, expand their processes, and inspect a selected process. |
| **Process controls** | Request normal termination or explicitly confirm a force quit for an accessible process. |
| **Light, dark, and system themes** | Keep the same readable layout in either appearance. |
| **Load history** | Revisit a slowdown with alert markers on the timeline. |
| **Personal alert rules** | Set thresholds and durations for overall load, individual apps, memory pressure, and free disk space. |
| **Quiet notifications** | Ignore brief spikes, suppress repeats, add exceptions, or pause alerts. |
| **Pinned details** | Keep the expanded view open while investigating a problem. |

These are planned capabilities, not implemented features. Alerts will never automatically terminate processes.

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

Safari is my main browser, so understanding its resource use matters to this project. Process-level monitoring is part of the plan. **Accurate CPU and memory attribution to individual tabs is still a research question.**

MacGlint will not label a process as a particular website without a verified mapping. The [Safari research note](docs/research/safari.md) records the available evidence and the checks a prototype needs to pass.

## Development

The proposed stack is **Swift, SwiftUI, and AppKit**. The first target is a personal Apple Silicon Mac; the minimum macOS version and wider hardware support are not fixed yet.

The intended data model is local: settings and bounded monitoring history stay on the Mac. AI-assisted development does not mean that process information or browsing data needs to be sent to an AI service.

| Step | Status |
|---|---|
| Visual direction and light/dark concepts | Available |
| Product specification and roadmap | Available |
| Safari tab-attribution feasibility | To investigate |
| Working native application | Not started |
| Installable release | Not available |

Build and installation instructions will be added when a working application exists. Detailed planning documents are currently in Russian.

## Explore the project

- [Product specification](docs/superpowers/specs/2026-10-14-air-design.md) — behavior, proposed architecture, and limits.
- [Roadmap](docs/ROADMAP.md) — implementation stages and acceptance criteria.
- [Design archive](docs/design/README.md) — chosen direction and earlier alternatives.
- [Safari research](docs/research/safari.md) — findings and unresolved questions.
- [Contributing](CONTRIBUTING.md) — how to share useful feedback at this stage.

Ideas and practical use cases are welcome through [GitHub Issues](https://github.com/greenpandorik/macglint/issues). This is a personal project, so priorities follow everyday use rather than a fixed release schedule.

---

Created by [Mikhail Volkov](https://github.com/greenpandorik), with AI assistance for design and development.
