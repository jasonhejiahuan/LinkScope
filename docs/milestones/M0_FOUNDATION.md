# Milestone 0 — Foundation

**Release role:** required for v1.

## Deliverables

- Native `LinkScope` and sandboxed `LinkScope Lite` application targets.
- Shared Swift modules with strict concurrency enabled.
- `RawValue`, explicit availability, observation, identity, capability, event,
  snapshot, diagnostic, rule, dashboard, and widget source models.
- Read-only `AccessoryProvider` protocol and provider contract fixtures.
- `ObservationHub` for provider lifecycle, event coalescing, identity resolution,
  persistence, and live UI snapshots.
- Three-level identity model:
  `PhysicalAccessoryIdentity -> TransportIdentity -> ObservationIdentity`.
- SQLite WAL store with numbered migrations, searchable metadata, AES-GCM raw
  payloads, Keychain-backed master key, and keyed-HMAC identity indexes.
- Versioned JSON import/export with complete raw-value and availability fidelity.
- Capability matrix and provider health/status records.
- Test-target-only deterministic providers, fixtures, and contract/unit tests;
  production modules contain no mock-device provider.
- Versioned dashboard/rule/session schemas even though their full behavior is
  scheduled later.

## Acceptance criteria

- Full and Lite compile from the same shared modules with edition-specific flags.
- A mock provider can stream observations through the hub, resolve identities,
  persist encrypted payloads, and replay an inspectable snapshot.
- Common history queries filter by stable device key, provider, parameter path,
  availability, event/session, and time without decrypting unrelated rows.
- Database bytes and SQL-visible columns do not contain inserted sensitive raw
  identifiers or string payloads in plaintext.
- Migrations are idempotent and a newer unsupported schema fails safely.
- Export/import round-trips recursive raw values and every availability state.
- Name-only identity similarity remains `ambiguous` or `independent`.
- Provider tests prove that no control/write operation exists in the protocol.

## Exit condition

M1 work may depend on this architecture. M2–M4 may extend it but must not replace
its stable identifiers, observation envelope, or storage format.
