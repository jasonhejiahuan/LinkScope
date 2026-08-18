# LinkScope implementation plan

Status values used throughout this plan:

- **Required now** — part of the first public inspector release.
- **Experiment now** — isolated compatibility work that may run alongside v1,
  but cannot delay it.
- **Deferred, not cancelled** — explicitly scheduled after the public
  foundation is proven.

## Release sequence

| Milestone | Theme | Release role | Status |
| --- | --- | --- | --- |
| 0 | Foundation | Shared architecture and testable data foundation | Required now |
| 1 | Public Inspector | Useful Full/Lite v1 built only on public APIs | Required now |
| 2 | Diagnostics and Monitoring | Sessions, sampling, rules, alerts, automation | Deferred, not cancelled |
| 3 | Experimental Private Providers | Isolated, runtime-discovered Full-only surfaces | Deferred, not cancelled; probes allowed now |
| 4 | Advanced Dashboard System | Arbitrary dashboards and a twelve-column grid | Deferred, not cancelled; interaction probes allowed now |

## Product invariants across every milestone

1. Providers expose only `read`, `observe`, `sample`, and `diagnose` operations.
   Pairing, connection control, configuration writes, HID output reports,
   firmware updates, and private setters have no general interface in the app.
2. Idle behavior is callback/event driven. Recurring sampling exists only in an
   explicit diagnostic session or a documented, coarse fallback policy.
3. Missing values never become an unexplained `nil`. Availability records why a
   field is unavailable, stale, denied, unsupported, or failed.
4. A physical accessory, a transport identity, and a raw observation identity
   are distinct concepts. Display names never merge devices.
5. Query metadata remains indexable. Sensitive raw identifiers and parameter
   payloads are AES-GCM encrypted; keyed hashes provide stable local lookup keys.
6. Full and Lite share portable observation, snapshot, dashboard, and export
   schemas. Edition-specific capability gaps are represented, not erased.
7. English and Simplified Chinese ship together, with an in-app language switch.
8. Private fields are runtime discoveries backed by per-build evidence, never
   assumed contracts.

## Dependency order

```text
Milestone 0 data and provider contracts
             |
             v
Milestone 1 public inspector (v1)
             |
             v
Milestone 2 diagnostics and monitoring
             |
             v
Milestone 3 experimental private integration
             |
             v
Milestone 4 advanced dashboard interaction
```

Small M3/M4 feasibility probes may branch from M0 at any time, but their output
must be evidence or development-only code—not a production dependency.

## Detailed plans

- [Milestone 0 — Foundation](milestones/M0_FOUNDATION.md)
- [Milestone 1 — Public Inspector](milestones/M1_PUBLIC_INSPECTOR.md)
- [Milestone 2 — Diagnostics and Monitoring](milestones/M2_DIAGNOSTICS.md)
- [Milestone 3 — Experimental Private Providers](milestones/M3_PRIVATE_PROVIDERS.md)
- [Milestone 4 — Advanced Dashboard System](milestones/M4_ADVANCED_DASHBOARDS.md)
- [Architecture invariants](architecture/INVARIANTS.md)
- [Data and identity model](architecture/DATA_MODEL.md)
- [Provider architecture](architecture/PROVIDERS.md)
- [Distribution policy](architecture/DISTRIBUTION.md)
- [Acceptance matrix](ACCEPTANCE.md)

