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
