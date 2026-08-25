# Milestone 2 — Diagnostics and Monitoring

**Status:** implemented for the public Full and Lite editions.

## Restored scope

- User-started diagnostic sessions with start/stop, purpose, source selection,
  duration, and sampling policy.
- Time-series recording for eligible parameters, including bounded RSSI sampling.
- Battery alerts, provider-health alerts, and extensible notification rules.
- Coarse background fallback checks only where provider callbacks are insufficient.
- App Intents and Shortcut actions where the edition and sandbox permit them.
- Detailed timeline filtering, comparison, aggregation, and historical analysis.
- Retention/export controls that do not silently delete the default unlimited history.

## Foundation preserved in M0/M1

- `DiagnosticSession`, `SamplingPolicy`, `RuleDefinition`, and stable parameter
  source identifiers are versioned from M0.
- Observation rows already accept session and event identifiers.
- History indexing already supports time ranges and parameter paths.
- Provider capabilities already distinguish observing from explicit sampling.

## Acceptance criteria

- Sampling starts only after a user/session/rule request and stops deterministically.
- Session recovery after sleep or provider failure records a gap rather than
  backfilling invented measurements.
- Rules preserve explicit availability semantics and have rate limits.
- Notifications and App Intents do not add an idle polling loop.
- Historical queries remain bounded and indexed on a reference database containing
  at least one million observations.

## Implemented release surface

- Explicit source selection, duration, purpose, fixed/adaptive policy models,
  bounded RSSI sampling, deterministic stop, and persisted run history.
- Sleep and application-restart gaps; no invented backfill.
- Encrypted schema-v4 run, gap, rule, and trigger records plus session/path/time
  indexes.
- Time-series charting, aggregation, comparison, raw history, and CSV export.
- Rate-limited observation and provider-health rules with opt-in notifications.
- App Intents and App Shortcuts for start, stop, status, and snapshots.
- Explicit retention preview/confirmation with unlimited history as the default.
