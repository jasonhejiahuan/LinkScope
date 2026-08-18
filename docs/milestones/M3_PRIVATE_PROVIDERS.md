# Milestone 3 — Experimental Private Providers

**Status:** deferred, not cancelled. Isolated feasibility probes are allowed now.

## Full-edition scope to restore

- `BluetoothManager.framework`
- `BluetoothServices.framework`
- `BluetoothAudio.framework`
- Private HID inspection surfaces
- Unrestricted IORegistry inspection
- Optional, bounded `system_profiler` adapter

No private provider is an in-process assumption. Production integration runs in
an isolated XPC service with crash/timeout containment and generic observation IPC.

## Runtime capability discovery

A private field is exposed only after checking, on the running OS and architecture:

1. Framework path and successful load.
2. Class existence.
3. Selector existence.
4. Exact Objective-C type encoding.
5. A read-only invocation adapter matching that encoding.
6. Safe invocation inside the isolated process.
7. Returned-value shape.
8. Semantic evidence for the tested OS build/device combination.

The versioned manifest records framework, class, selector, type encoding,
read-only status, tested builds/architectures, result format, validation state,
and semantic confidence. Unknown entries remain unavailable/experimental and are
never guessed from a similar field name.

## Early experiments

Allowed probes include framework/class inventories, selector encoding capture,
multipart battery, spatial/audio flags, audio link quality, private HID surfaces,
`system_profiler` quality, XPC crash isolation, Universal 2 behavior, and macOS
15/26/27 compatibility. See `docs/experiments/README.md`.

## Acceptance criteria

- Killing or crashing the helper cannot terminate or corrupt the main app.
- An unvalidated selector produces a capability-unavailable observation and is
  never invoked.
- Read-only enforcement exists in both manifest validation and provider IPC.
- Manifests are keyed by exact OS build evidence, not only marketing version.
- Lite does not link, bundle, load, or advertise private frameworks.
- Full's stable release attempts Developer ID signing and notarization first.

