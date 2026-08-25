# LinkScope AI debugging policy

## Build configuration priority

- Use the `Debug` configuration for local command-line builds, investigation,
  reproduction, and AI-assisted debugging unless the task explicitly requires
  a release or archive build.
- `Debug` builds are visibly named `LinkScope DEBUG` and `LinkScope Lite DEBUG`.
- `Release` remains the configuration for profiling, archiving, distribution,
  and any result that may be shared outside the local debugging context.
- Never infer the cause of a failure when runtime evidence can be collected.
  First inspect the real process output, unified log, crash report, exit status,
  build products, entitlements, and relevant state transitions.

## Versioning ownership

- Define `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` only on the
  `LinkScope` project build configurations. Debug and Release must resolve from
  those shared project-level values.
- The `LinkScope` and `LinkScope Lite` targets must inherit both version
  settings. Do not add target-level values or duplicate the version numbers in
  either target.
- Never set a target value to `$(MARKETING_VERSION)` or
  `$(CURRENT_PROJECT_VERSION)` because that creates a self-reference. Remove
  the target override to restore inheritance.
- When advancing a release, update the project-level values once, then verify
  the resolved values and generated Info.plist for both application targets.

## Logging policy

- If the existing logs do not establish the failure, add project-relevant
  diagnostic logging to the `Debug` path and reproduce the issue again. The
  diagnostic may be detailed and may include sensitive local values when that
  is necessary to identify the faulty component, state transition, provider,
  identifier mapping, persistence record, or error path.
- Prefer structured, filterable logs with a stable subsystem and category.
  Keep the exact evidence needed to identify the source of a failure rather
  than replacing it with guesses or a generic success message.
- Debug-only sensitive logging must be guarded by the `DEBUG` compilation
  condition or an equally explicit Debug-only path. Do not copy Debug logs,
  captured log output, or local diagnostic artifacts into release assets.
- Before using or sharing Debug logs, treat them as potentially sensitive and
  redact, restrict, or delete them according to the task's privacy needs.
- Release code must follow the project's privacy policy and data boundaries:
  do not emit secrets, authentication material, raw document contents, hidden
  personal data, private endpoints, or unnecessary device identifiers. Release
  logs should be minimal, non-sensitive, and justified by an operational need.

## Verification

- After changing logging or build settings, verify the intended configuration
  from the generated app's Info.plist and build output, then run the relevant
  Debug reproduction. Do not claim a fix based only on compilation.
- Preserve the distinction between Debug evidence and Release behavior in
  reports, commits, and handoff notes.
