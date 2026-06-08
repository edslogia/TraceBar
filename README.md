# TraceBar

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub Sponsors](https://img.shields.io/badge/Sponsor-%241%2B-pink?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/edslogia)

A macOS **menu bar** app that shows real-time mini charts for CPU, GPU, RAM, and network. No Dock icon: it lives in the top bar next to the clock and other system indicators.

## Table of contents

- [What you can do](#what-you-can-do)
- [Metrics](#metrics)
- [Requirements](#requirements)
- [Build and installation](#build-and-installation)
- [Usage](#usage)
- [Shortcuts and menu](#shortcuts-and-menu)
- [Persistence](#persistence)
- [Project structure](#project-structure)
- [Support this project](#support-this-project)
- [License](#license)

## What you can do

| Action | Where | Result |
|--------|-------|--------|
| View live usage | Menu bar | Four sparklines (38×18 px): CPU, GPU, RAM, and network |
| See exact value | Hover over a mini chart | Instant tooltip with percentage or network speed |
| Expand a metric | Click a mini chart | Floating panel with large chart and animated value |
| Change chart style | Expanded panel (line/bars icon) | Toggle between **line** and **bars** per metric |
| Switch metric in panel | Horizontal swipe or arrows on hover | Navigate CPU → GPU → RAM → Network (carousel) |
| Keep panel visible | Pin button in panel | Panel stays open when clicking outside |
| Quit the app | Right-click on the bar or ⌘Q | **Quit** menu or keyboard shortcut |

The app samples the system **every second** and keeps a history of **30 samples** (last 30 s) to draw the curves.

## Metrics

| Metric | What it shows | In the bar | In the panel |
|--------|---------------|------------|--------------|
| **CPU** | Aggregate processor usage | Green sparkline + `%` tooltip | Expanded chart + value |
| **GPU** | GPU usage (IOKit) | Orange sparkline + `%` tooltip | Same |
| **RAM** | Memory in use vs total | Blue sparkline + `%` tooltip | Same |
| **Network** | Network traffic | Two series: ↓ download (blue) and ↑ upload (orange) | Speed in Mbps and readable units |

Values are normalized to `[0, 1]` for drawing; human-readable formatting (percentages, MB/s, etc.) is handled by `SystemMonitor`.

## Requirements

- macOS with Xcode (to build)
- Developer account **not** required for local install with the script below
- Standard user permissions; reads via Mach and IOKit (no external agents or third-party dependencies)

## Build and installation

Builds the app in **Release**, copies it to `/Applications/TraceBar.app`, quits a previous instance if running, and launches it.

```bash
./scripts/build-and-install.sh
```

Intermediate artifacts in `build/DerivedData/Build/Products/Release/TraceBar.app` (`build/` directory ignored by git).

Manual alternative from Xcode: open `TraceBar.xcodeproj`, scheme **TraceBar**, configuration **Release**, Product → Run or Archive.

## Usage

1. After installing, **four mini charts** appear in the menu bar.
2. **Hover** over one to see the current value without opening anything.
3. **Click** a mini chart to open the expanded panel anchored to that chart.
4. In the panel:
   - Use the chart icon to switch between line and bars (saved per metric).
   - Swipe horizontally or use the arrows (visible on hover) to view another metric.
   - Pin the panel if you want to leave it open while using other apps.
5. Click outside the panel to close it (unless pinned).

## Shortcuts and menu

| Input | Action |
|-------|--------|
| Right-click on the chart area | Context menu with **Quit** |
| ⌘Q (app active) | Quit the application |
| ⌘Q (panel visible, focus elsewhere) | Quit the application |

## Persistence

Only the **chart style** (line or bars) **per metric** is saved in `UserDefaults`. No history or panel preferences persist across sessions beyond that.

## Project structure

```
TraceBar/
├── TraceBarApp.swift             # Launch, menu bar app (no Dock)
├── Services/
│   ├── SystemMonitor.swift       # CPU/GPU/RAM/network sampling (Mach, IOKit)
│   └── StatusBarController.swift # NSStatusItem and Quit menu
└── Views/                        # SwiftUI + AppKit panels/tooltips
    ├── MenuBarMonitorView.swift  # The four mini charts
    ├── MiniGraphView.swift
    ├── ExpandedGraphView.swift   # Floating panel
    ├── GraphMetric.swift         # Domain: colors, labels, history
    └── GraphStyleStore.swift     # Persisted styles per metric

scripts/
└── build-and-install.sh          # Release build + install to /Applications
```

Stack: Swift, SwiftUI, AppKit (`NSPanel`, native tooltips). No external dependencies.

## Support this project

TraceBar is free and open source. If it saves you time or you use it daily, consider [sponsoring on GitHub](https://github.com/sponsors/edslogia) — **from $1/month**.

Your support helps keep the project maintained: bug fixes, macOS compatibility updates, and new metrics or chart styles. Every tier counts, whether it is a coffee-sized contribution or ongoing sponsorship.

| | |
|---|---|
| **Sponsor** | [github.com/sponsors/edslogia](https://github.com/sponsors/edslogia) |
| **Minimum** | $1 USD / month |
| **What you get** | A maintained menu bar monitor you can build, fork, and trust on your Mac |

You can also star the repo or open issues and pull requests — that helps too.

## License

This project is released under the [MIT License](LICENSE). You are free to use, modify, and distribute it, including for commercial purposes, as long as you include the copyright notice.

---

**Note:** This project is open source for local use and learning. It is not published on the Mac App Store.
