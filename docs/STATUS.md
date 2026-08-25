# Implementation status

Last verified: 2026-08-25 on the current Apple-silicon development Mac with
Xcode 27 beta, Swift 6.4, and the macOS 27 SDK.

## Milestone status

| Milestone | Current state | Notes |
| --- | --- | --- |
| M0 Foundation | Implemented | Dual targets, versioned models, identity resolution, encrypted SQLite migrations, import/export, capability contracts, and tests |
| M1 Public Inspector | Implemented | Seven public providers, evidence-based device consolidation, status-aware navigation, inspector, timeline, snapshots, export/import, Settings, and English/Chinese UI |
| M2 Diagnostics | Implemented | Explicit sessions, bounded sampling, gaps and restart recovery, encrypted history, charts/CSV, alerts, retention controls, App Intents, and permission management |
| M3 Private Providers | Manifest foundation only | Versioned empty manifests and isolation rules remain; production targets do not link or load private frameworks |
| M4 Advanced Dashboard | Implemented in 2.0 | Named dashboards, twelve-column editing, six widget kinds, indexed history, import/export, unknown-field preservation, and Full/Lite portability |

“Manifest foundation only” means deferred, not cancelled.

## Current verification evidence

- Version ownership remains project-level. Debug and Release settings for both
  targets resolve by inheritance to `2.0.0 (9)` without target overrides.
- The shared Swift package passes 51 tests, including encrypted dashboard CRUD,
  indexed source queries, layout collision behavior, reversible source IDs,
  future-schema round trips, diagnostics, and persistence restart behavior.
- Fresh Full and Lite Debug builds pass strict deep code-signature verification
  with the same Apple Development identity and team. Each bundle has its exact
  application identifier, Data Protection Keychain group, embedded profile,
  bundle identifier, expected display name, and Bluetooth usage description.
- Fresh Full and Lite Release builds succeed as Universal 2 (`x86_64 arm64`)
  bundles at `2.0.0 (9)` and pass strict Apple Development signature checks.
- Real signed launches of both editions complete without an automatic Keychain
  password request or Bluetooth authorization sheet. Permission requests are
  initiated from the shared post-window permission manager; previously granted
  authorization remains valid across signed rebuilds.
- Full runtime acceptance covered dashboard creation, Current Value and Time
  Series widgets, inspector edits, keyboard Undo, pointer drag and resize,
  normal Quit, and relaunch restoration.
- A Full dashboard containing a Full-only source imports into Lite as an
  explained unavailable-source widget. The dashboard and source identifier
  survive a normal Quit and signed relaunch instead of being removed.
- Dashboard history uses an indexed `(transport_identity_id, parameter_path,
  observed_at)` query, shares in-flight/cache work, decimates away from the main
  actor, and does not start a provider sampling session.
- Toolbar and search ownership is limited to the root scene. Real Full and Lite
  launches no longer reproduce the nested `NSToolbar` startup crash.

## External release evidence still required

- Hardware matrix runs on Bluetooth pointing devices, audio, controllers,
  permission-denied, Bluetooth-disabled, sleep/wake, reconnect, Intel, and the
  minimum supported macOS release.
- Reference-machine Release/Universal 2 Energy Log, wakeup, memory, CPU, and
  50-widget responsiveness capture.
- Developer ID signing, notarization, Gatekeeper assessment, and Mac App Store
  Lite packaging with the production identities and profiles.
- XPC crash containment and private capability probes before any M3 production
  integration.
