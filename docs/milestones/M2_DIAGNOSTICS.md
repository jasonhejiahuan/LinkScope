# Milestone 2 — Diagnostics and Monitoring

**Status:** deferred, not cancelled.

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

