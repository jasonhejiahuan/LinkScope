# Data and identity model

## Identity levels

```text
PhysicalAccessoryIdentity
        |
        +-- TransportIdentity (IOHID)
        +-- TransportIdentity (IOBluetooth)
        +-- TransportIdentity (CoreBluetooth)
        +-- TransportIdentity (Core Audio)
        `-- TransportIdentity (IORegistry)
                 |
                 `-- ObservationIdentity
                     = provider + transport identity + raw parameter path
```

Resolution results are `exact`, `verifiedAncestry`, `correlated(confidence)`,
`ambiguous`, or `independent`. Correlation evidence is stored so a later resolver
can improve decisions without rewriting raw history. Ambiguous observations stay
independently inspectable.

Provider-supplied evidence has ordered strength:

1. an exact provider transport identity;
2. a provider-scoped physical group or verified IORegistry ancestry;
3. vendor/product/serial correlation;
4. conservative cross-provider correlation inside an explicit domain.

The Bluetooth correlation domain requires a normalized name, a Bluetooth
protocol classification, exactly one existing physical candidate, and a
different transport kind. Two same-name IOBluetooth devices therefore remain
independent. Display name alone never merges accessories.

ConnectionProtocol is separate from the provider/API TransportKind. For example,
a Core Audio endpoint may report Bluetooth, USB, built-in, network, or virtual
protocol. Persisted history is re-resolved through the current resolver on launch
so improved evidence can consolidate older split identities.

## Live connection semantics

Persisted connection values are historical evidence. Current UI state is derived
only from observations produced after the current provider session starts:

- connected: current connection.connected=true;
- saved: currently paired/saved, without a current connected observation;
- disconnected: a current explicit disconnected observation;
- inactive: no current authoritative connection observation.

Core Audio DeviceIsAlive is stored as audio.deviceAlive; it is not proof of a
wireless connection. Non-Bluetooth HID enumeration is connection.present, not an
active wireless connection.

`CBPeripheral.identifier` is specifically not assumed to be a Bluetooth MAC
address, a globally permanent hardware ID, a cross-install ID, or proof of
equivalence with an observation from another provider.

## Observation envelope

Searchable/indexable metadata:

- local observation UUID;
- stable physical/transport keyed hashes;
- provider ID and raw parameter path;
- timestamp and monotonic ordering value;
- availability and raw value type;
- event/session/snapshot identifiers;
- sensitivity and schema version.

AES-GCM encrypted payload:

- raw value and provider-specific envelope;
- raw addresses and transport identifiers;
- account identifiers, IRKs, authentication tags, or key material if an allowed
  read-only provider ever legitimately exposes them;
- raw IORegistry dictionaries;
- private-framework and `system_profiler` payloads.

A Keychain master key derives separate encryption and HMAC keys. Keyed HMACs
support equality/history queries without exposing the identifier used to derive them.

## Forward-compatible documents

Dashboard, rule, diagnostic-session, snapshot, export, and private-capability
documents include explicit schema versions. Unknown future data is either retained
as raw JSON or rejected with a clear newer-schema error; it is never silently lost.
