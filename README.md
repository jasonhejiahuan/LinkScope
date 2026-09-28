<p align="center">
  <img src="https://raw.githubusercontent.com/jasonhejiahuan/LinkScope/main/Design/AppIcon/exports/LinkScope-iOS-27-Default.png" width="112" height="112" alt="LinkScope — Icon Composer Design Generation 27">
</p>

<h1 align="center">LinkScope</h1>

<p align="center">
  <strong>Explore Bluetooth. Inspect your peripherals.</strong><br>
  探索蓝牙与外设
</p>

<p align="center">
  Device parameters, connection states, and diagnostics.<br>
  One native workspace for macOS.
</p>

<p align="center">
  <a href="https://www.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-15%2B-315F9A?style=flat-square&amp;labelColor=24292F" alt="macOS 15 or later"></a>
  <a href="https://www.swift.org/"><img src="https://img.shields.io/badge/Swift-6-F05138?style=flat-square&amp;labelColor=24292F" alt="Swift 6"></a>
  <a href="https://github.com/jasonhejiahuan/LinkScope/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-AGPL--3.0--only-315F9A?style=flat-square&amp;labelColor=24292F" alt="AGPL-3.0-only"></a>
  <a href="https://apps.jasonstu.cc/linkscope"><img src="https://img.shields.io/badge/LinkScope_Lite-Free-315F9A?style=flat-square&amp;labelColor=24292F" alt="LinkScope Lite is free"></a>
</p>

<p align="center">
  <a href="https://apps.jasonstu.cc/linkscope"><strong>Get LinkScope Lite</strong></a> &nbsp;·&nbsp; <a href="https://github.com/jasonhejiahuan/LinkScope/tree/main/docs">Documentation</a> &nbsp;·&nbsp; <a href="https://github.com/jasonhejiahuan/LinkScope/issues">Issues</a> &nbsp;·&nbsp; <a href="https://apps.jasonstu.cc/linkscope/privacy">Privacy</a>
</p>

<br>

<p align="center">
  <img src="https://raw.githubusercontent.com/jasonhejiahuan/LinkScope/main/Design/AppStore/2.0.0/captured/dashboard-en.png" width="960" alt="LinkScope Lite showing a custom dashboard with device readings and provider status">
</p>

<p align="center">
  <sub>System-reported data · On-demand diagnostics · Custom dashboards</sub>
</p>

---

LinkScope brings accessory parameters, availability, and observation history into a native Mac workspace. Inspect supported devices, record diagnostic sessions, and arrange readings in custom dashboards. Available data depends on your Mac, connected hardware, and permissions.

**LinkScope Lite is free on the Mac App Store.** This repository contains the shared source for the Full and Lite editions.


## Repository shape

- `LinkScope.xcodeproj` — native Full and Lite application targets.
- `Apps/` — the two thin application entry points and target entitlements.
- `Packages/LinkScopeKit` — shared models, persistence, providers, orchestration,
  UI, and tests.
- `docs/` — the authoritative milestone plan and architectural invariants.
- `PrivateCapabilities/` — versioned manifests for future runtime-discovered
  private capabilities; these are evidence records, not API promises.
- `script/build_and_run.sh` — the single local build/run/debug entry point.

## Editions

| Edition | Bundle ID | Distribution | Provider policy |
| --- | --- | --- | --- |
| LinkScope | `cc.jasonstu.linkscope` | Developer ID | Public providers now; isolated experimental providers in Milestone 3 |
| LinkScope Lite | `cc.jasonstu.linkscope.lite` | Mac App Store | Public, sandbox-compatible providers only |

The current release boundary includes Milestones 0, 1, 2, and 4: the public
inspector, explicit diagnostic sessions, bounded sampling, historical analysis,
notification rules, Shortcuts automation, and portable twelve-column
dashboards. Milestone 3 remains an isolated manifest foundation and does not
form a production dependency.

See [the implementation plan](docs/IMPLEMENTATION_PLAN.md) and
[acceptance matrix](docs/ACCEPTANCE.md). The evidence-backed boundary between
implemented, foundation-only, and deferred work is tracked in
[implementation status](docs/STATUS.md).

## Local development

Requirements:

- macOS 15 or newer
- Xcode 16 or newer (the run script also recognizes Xcode beta)
- Swift 6 toolchain

```sh
./script/build_and_run.sh
./script/build_and_run.sh --lite
./script/build_and_run.sh --verify
```

Run the shared tests and both signed Debug bundle checks with:

```sh
./script/check.sh
```

## License

Copyright (C) 2026 JASON Studio.

Unless a file states otherwise, LinkScope's original source code and associated
project materials are licensed under the **GNU Affero General Public License,
version 3 only** (`AGPL-3.0-only`). See [LICENSE](LICENSE) for the complete terms.
Third-party components retain their own licenses.

You may study, run, modify, and share the project, including for research and
commercial use, subject to the license. When distributing covered works, keep
the required notices, identify modifications, and provide the corresponding
source under the same license. If you modify the program and let users interact
with it remotely over a network, offer those users the corresponding source of
that modified version as required by section 13.

AGPL is a strong copyleft license, not a restriction on fields of use. It does
not prohibit commercial use or guarantee that nobody will misuse the software.
No permission to imply endorsement by JASON Studio or to claim that a modified
build is an official LinkScope release is granted.

The copyright holder may distribute its own official builds under separate
terms, including applicable App Store terms. This does not grant third parties
an exception from AGPL. Before including third-party contributions in official
store builds, maintainers must verify the rights needed for that distribution;
contributions do not automatically transfer copyright.
