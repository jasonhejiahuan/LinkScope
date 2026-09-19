# LinkScope

Current development version: **2.0.0 (9)**. See [CHANGELOG.md](CHANGELOG.md).

LinkScope is a native macOS wireless-accessory inspector for people who want to
see what the system exposes without letting the inspector take over their Mac.
It is read-only, event-driven while idle, bilingual by default, and designed to
combine public-framework inspection, explicit diagnostics, and fully
customizable dashboards while keeping experimental providers isolated.

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
