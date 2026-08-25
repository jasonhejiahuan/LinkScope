# Changelog

Every user-visible update advances both the marketing version and build number
for the Full and Lite targets.

## 1.3.0 (6) — 2026-08-20

### Added

- User-started, time-limited diagnostic sessions with explicit source selection,
  bounded RSSI sampling, deterministic stop, sleep gaps, and restart recovery.
- Encrypted diagnostic run, gap, alert rule, and trigger persistence with schema
  migration 4 and indexed session/time-range observation queries.
- Diagnostic history, time-series charts, comparison metrics, raw tables, and
  per-session CSV export.
- Rate-limited numeric, change, availability, and provider-health alert rules
  with explicit notification authorization.
- App Intents and App Shortcuts for starting, stopping, inspecting, and capturing
  diagnostics and snapshots.
- Explicit history-retention preview and destructive confirmation; unlimited
  retention remains the default.
- A shared Full/Lite permission manager in Settings, with post-window first-run
  setup for saved history, Bluetooth accessories, and optional notifications.

### Changed

- Bluetooth sidebar glyphs now use the standard class-of-device category when
  available instead of rendering every saved Bluetooth accessory as a radio.
- Keychain access is checked without authentication UI during launch. LinkScope
  now requests access only from the permission manager and otherwise continues
  in memory-only mode instead of prompting before the main window appears.

## 0.1.3 (4) — 2026-08-17

### Development

- Build and run scripts now honor Xcode's automatically managed Apple
  Development signing instead of overriding it with `CODE_SIGNING_ALLOWED=NO`.
  This gives both editions a stable local code identity for Keychain and
  Bluetooth permission authorization.

## 0.1.2 (3) — 2026-08-17

### Fixed

- Correlate address-shaped Core Audio UIDs with the same normalized
  IOBluetooth address, then use that high-confidence anchor to consolidate a
  rotating, non-generic Bluetooth alias such as J-4ANC.
- Preserve `bluetooth.basebandConnected` as raw inspector evidence while no
  longer treating a class-zero, BLE-only metadata link as a user-visible active
  connection. A Bluetooth Core Audio default route still establishes active
  connection evidence.
- Refresh a physical accessory's label when the same exact transport reports a
  newer non-generic system name.
- Give Connected, Saved / Not Connected, and Disconnected rows distinct status
  glyphs while retaining their protocol glyph.

### Data hygiene

- Remove the production mock-provider implementation. Deterministic providers
  now exist only inside the test target.
- Add schema migration 3 and runtime/import guards that remove only LinkScope
  development fixtures. macOS paired-device and Bluetooth preference data are
  never modified.

### Project

- Advance both targets to 0.1.2 build 3.
- Restore Xcode-generated project metadata to `LastSwiftUpdateCheck = 2700`,
  `LastUpgradeCheck = 2700`, and `CreatedOnToolsVersion = 27.0`; retain the
  intentionally selected Xcode 15-compatible project format.

## 0.1.1 (2) — 2026-08-17

### Fixed

- Consolidate sibling HID collections using provider physical-group evidence and
  verified IORegistry ancestry instead of presenting every collection as a device.
- Correlate a unique Bluetooth accessory across IOBluetooth, Bluetooth-backed
  Core Audio, and Bluetooth HID transports while keeping ambiguous same-name
  devices independent.
- Rebuild persisted observations through the current identity resolver so
  improved grouping applies to existing history.
- Count a device as connected only from current-session connection evidence.
- Treat Core Audio DeviceIsAlive as audio-object liveness, not accessory
  connection state.
- Treat non-Bluetooth HID enumeration as presence rather than a wireless
  connection.

### Added

- Persistent device-list grouping by connection status, connection protocol, or
  no grouping.
- Persistent sorting by name, connection status, protocol, or update time.
- Explicit Connected, Saved / Not Connected, Disconnected, and
  Inactive / Historical states in the sidebar and inspector.
- Bluetooth, USB, built-in, network, virtual, controller, system, and unknown
  protocol labels in English and Simplified Chinese.

### Project

- Keep the project in the readable Xcode 15 project format (objectVersion 60),
  which remains supported by the current Xcode 27 toolchain.

## 0.1.0 (1) — 2026-08-17

- Initial Milestone 0 foundation and Milestone 1 public inspector build.
