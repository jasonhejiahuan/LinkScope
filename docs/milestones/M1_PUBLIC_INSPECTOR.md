# Milestone 1 — Public Inspector / v1 Core

**Release role:** required for v1.

## Public provider set

- CoreHID/IOHID event surfaces for input accessories and property changes.
- IOBluetooth paired/connected classic-device snapshots and notifications.
- CoreBluetooth authorization, state, discovery events, and legitimate peripheral
  UUID observations without treating UUIDs as hardware addresses.
- Core Audio device enumeration and property listeners.
- Game Controller connection, battery, and profile observations.
- Public IOKit/IORegistry inspection using bounded, allowlisted traversal.
- Workspace, power, thermal, login, sleep, and wake events.

Where a framework cannot enumerate arbitrary devices, the provider reports that
limitation explicitly instead of manufacturing a result.

## Initial UI

- Native menu-bar status with concise health and connected-device counts.
- Main sidebar device list with stable selection, search, persistent sorting, and
  grouping by current connection state or connection protocol.
- Device inspector with summary, transport identities, raw parameter table, and
  explicit availability explanations.
- Provider status view showing running, permission, unsupported, and failure states.
- Basic event/observation timeline.
- In-memory and persisted snapshots plus complete JSON export.
- English and Simplified Chinese language switch in a dedicated Settings scene.

The UI consumes generic observations. It must not bind the persistence schema to
today's panels or prevent later dashboard widgets from using the same sources.

## Energy policy

- Subscribe once to system/provider callbacks.
- Perform one bounded initial snapshot when a provider starts.
- Do not run a repeating scan or timer while idle.
- Mark callback-derived values stale based on timestamps at presentation time;
  do not wake the process merely to flip a label.
- Sampling is a later explicit diagnostic-session behavior.

## Acceptance criteria

- A Mac with no optional accessories still presents provider health and built-in
  devices without crashing or displaying invented values.
- Permission denial remains visible and does not disable unrelated providers.
- Disconnect/reconnect updates arrive from callbacks and persist in the timeline.
- Raw rows show distinct text for not exposed, not reported, permission denied,
  unsupported, stale, and provider failure.
- `CBPeripheral.identifier` is labelled as a CoreBluetooth-scoped identifier and
  never displayed or indexed as a MAC address.
- Dashboard-closed idle testing shows no LinkScope-created repeating scan loop.
- Saved Bluetooth devices are labelled saved/not connected and are never included
  in the connected count without current-session connection evidence.
- Multiple endpoints supported by verified physical-group, ancestry, or
  conservative cross-provider evidence appear under one physical accessory while
  ambiguous same-name devices remain independently inspectable.
- Full and Lite exported snapshots share one schema and import into either edition.

## v1 exit condition

Milestones 0 and 1 together form the first useful public release. M2 begins only
after hardware smoke tests and storage/identity stability checks pass.
