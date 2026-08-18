# Provider architecture

Each provider has a stable identifier, localized display name key, declared
capabilities, permission/status snapshot, and an async stream of `ProviderEvent`.

```text
Public framework callback
        |
        v
AccessoryProvider event stream
        |
        v
ObservationHub
  - normalize availability
  - resolve identity
  - coalesce exact duplicates
  - persist event and encrypted payload
  - publish immutable UI snapshot
```

Providers never receive a database handle or UI state. The hub owns lifecycle and
cancellation. A failure in one provider becomes provider status data and does not
stop the remaining provider tasks.

## Contract rules

- `start()` performs at most one bounded initial read and installs callbacks.
- `events` is cancellation-aware and finishes when the provider stops.
- Reconnect/restart may repeat current values; the hub coalesces exact duplicates.
- Unsupported and denied are emitted explicitly.
- A provider may expose a sampling capability for M2, but cannot self-schedule it
  while idle.
- Raw paths are stable within a provider and never derived from localized labels.

## Public v1 boundaries

CoreBluetooth cannot enumerate every arbitrary connected BLE device. IORegistry
ancestry may establish identity only when the relationship is verifiable. Provider
status communicates these boundaries rather than overstating what the API proves.

