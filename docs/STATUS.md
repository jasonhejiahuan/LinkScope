# Implementation status

Last verified: 2026-08-17 on the current Apple-silicon development Mac with
Xcode 27 beta, Swift 6.4, and the macOS 27 SDK.

## Milestone status

| Milestone | Current state | Notes |
| --- | --- | --- |
| M0 Foundation | Implemented foundation | Dual targets, models, identity resolver, encrypted SQLite/migrations, import/export, test-local deterministic providers, capability contracts, and tests are present |
| M1 Public Inspector | Implemented initial v1 | Seven public providers, evidence-based device consolidation, live connection states, protocol grouping, persistent sorting, menu bar, inspector, timeline, snapshots, complete JSON export/import, Settings, and English/Chinese UI are present |
| M2 Diagnostics | Foundation only | Session, sampling, rule, event, and source models are preserved; sampling/alerts/App Intents remain deferred |
| M3 Private Providers | Manifest foundation only | Versioned empty manifests and isolation rules are present; no production target links or loads a private framework |
| M4 Advanced Dashboard | Foundation only | Versioned dashboard/widget/grid/source models are present; the interactive twelve-column editor remains deferred |

“Foundation only” means deferred, not cancelled.

## Verification evidence

- `swift test` passes 26 Swift Testing tests: 20 core/identity/connection/hub
  tests, four persistence tests, and two public-provider contract tests.
- Both `LinkScope` and `LinkScope Lite` Debug schemes build as native `.app`
  bundles at version 0.1.3 build 4 with the local shared Swift package.
- Both bundles launch through `script/build_and_run.sh --verify`.
- The Lite bundle has its distinct bundle ID and build-time sandbox/Bluetooth/file
  entitlements. The unsigned local verification build does not claim App Store
  signing or sandbox-runtime proof.
- A local 10-second post-start check remained at 4647 observation rows with
  point-in-time process CPU at 0.0% before and after, providing narrow evidence
  that the idle implementation does not run a recurring observation loop. This
  is not the reference-machine Instruments gate.
- On the current Mac, current-session SQL metadata showed 15 physical HID
  accessories with up to six HID transports consolidated under one physical
  accessory, plus one cross-provider physical accessory. The UI showed 26 paired
  devices as Saved / Not Connected instead of counting them as connected.
- A 0.1.2 hardware smoke run showed only the Magic Trackpad as Connected and
  J-4ANC as Saved / Not Connected. The public system report exposed a separate
  class-zero BLE baseband alias; LinkScope retains that raw fact without
  promoting it to an active user-facing connection. The address-shaped Core
  Audio endpoint and saved Bluetooth identity are consolidated through a
  normalized cross-provider identifier.
- `otool` inspection found no `BluetoothManager`, `BluetoothServices`,
  `BluetoothAudio`, or other private-framework linkage in Lite.

## Still requiring later evidence

- Hardware matrix runs on Magic Mouse/Trackpad, Bluetooth audio, controller,
  Intel, minimum macOS 15, permission-denied, sleep/wake, and reconnect cases.
- Reference-machine Release/Universal 2 Energy Log, wakeup, memory, and CPU capture.
- Developer ID signing, notarization, and Mac App Store Lite packaging with the
  user's production identities/profiles.
- XPC crash-containment and private capability probes before M3 integration.
- M2 diagnostics/automation and M4 advanced dashboard interaction.
