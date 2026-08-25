# Acceptance matrix

## Functional v1 gates

| Area | Evidence required |
| --- | --- |
| Dual editions | Full and Lite schemes build; Lite has sandbox entitlement and no private linkage |
| Models | Recursive raw values and every availability state round-trip in tests |
| Identity | Name-only matches do not merge; CoreBluetooth UUID limitations are visible |
| Persistence | Migrations pass; sensitive payload is encrypted; indexed queries avoid bulk decryption |
| Providers | Each public provider survives absent hardware/permission and reports its status |
| UI | Menu bar, device list, inspector, raw view, provider status, timeline, snapshot/export work |
| Localization | English and Simplified Chinese switch from Settings without data loss |
| Energy | Idle providers use callbacks; no recurring scanning timer exists |
| Read-only | Static review and protocol tests find no general write/control surface |
| Diagnostics | Sampling requires an explicit session, stops deterministically, and records sleep/provider gaps |
| Rules | Availability is preserved; notifications require authorization and enforce a repeat interval |
| Automation | App Intents expose start/stop/status/snapshot without adding idle polling |
| Retention | Unlimited is the default; deletion shows an exact preview and requires confirmation |

## Reference-machine performance gate

Performance numbers are acceptance targets only on a recorded reference setup:

- exact Mac model and architecture;
- exact macOS build;
- Release/Universal 2 configuration;
- Bluetooth enabled;
- defined connected-device fixture;
- main window closed;
- fixed measurement duration;
- Instruments Energy Log and Time Profiler evidence.

Initial targets on that configuration:

- median idle CPU below 0.2%;
- resident memory below 100 MB;
- fewer than one LinkScope-attributable wakeup per minute.

Other Macs record comparative values rather than being judged as deterministic
copies of the reference machine. The universal invariant is no unnecessary
recurring polling while idle.

## Hardware test matrix

- Built-in trackpad/keyboard where present.
- Magic Mouse or Magic Trackpad.
- BLE accessory visible only through CoreBluetooth service knowledge.
- Bluetooth audio output/input.
- Game controller when available.
- Permission denied, Bluetooth disabled, sleep/wake, disconnect/reconnect.
- Apple silicon and Intel smoke tests.

Policy and mock tests prove software behavior only; they are not labelled as
proof of every physical accessory or production distribution path.
