# Architecture invariants

## Read-only by construction

`ProviderOperation` is a closed enum containing only `read`, `observe`, `sample`,
and `diagnose`. Neither the provider protocol nor its IPC envelope has a generic
write/control command. An underlying framework exposing setters does not grant
LinkScope permission to wrap them.

Explicitly out of scope:

- pairing or unpairing;
- connect or disconnect commands;
- preference/accessory configuration writes;
- firmware operations;
- HID output reports or gesture remapping;
- audio-mode modification;
- private setters or arbitrary selector invocation.

## Honest absence

Each parameter carries a `ParameterAvailability`. The following are distinct:

- `available`
- `notExposed`
- `notReported`
- `permissionDenied`
- `unsupported`
- `stale`
- `providerFailure`

The UI may summarize them, but storage and export must retain the exact state.

## Event-driven idle behavior

Provider callbacks feed an async event stream. Initial snapshots are bounded.
There is no continuous scan timer. Diagnostic sampling is explicit, scoped, and
cancelled on session end. Presentation-time staleness does not require a wakeup.

Persisted connection observations never become current connection truth after a
new launch. Connected counts and status groups require evidence from the current
provider session. API-object liveness and HID presence are stored under their own
parameter paths instead of being promoted to wireless connection claims.

## Edition isolation

Full and Lite share models and UI contracts. Lite remains sandbox-compatible and
never links private providers. Edition capability differences become provider
status/availability data rather than conditional model shapes.

## Privacy and raw fidelity

LinkScope does not redact accessible raw values from the owner's local inspector
or explicit export. It therefore encrypts raw payloads and sensitive transport
identifiers at rest. Metadata needed for normal queries remains indexable without
exposing those raw values.
