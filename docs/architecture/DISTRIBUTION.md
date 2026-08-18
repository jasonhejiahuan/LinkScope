# Distribution and compatibility policy

## Stable Full release

```text
Universal 2 archive
        |
Developer ID signing + hardened runtime
        |
Notarization attempt
        |
Accepted -> normal Full release
```

If notarization fails, inspect the notary log and identify the exact component.
First attempt a safe packaging or compatibility correction. Then make an explicit
release decision: disable only the offending capability in stable Full, or publish
a separately labelled, signed-but-unnotarized experimental build. The latter is a
fallback channel, never the normal release.

Private providers are not silently erased to make a release pass. Incompatible
ones remain documented, capability-gated, and available for later experimental work.

## Lite release

`LinkScope Lite` is sandboxed, public-provider-only, and prepared for Mac App Store
review. It shares portable exports and dashboard documents with Full while clearly
reporting edition-unavailable providers.

## Compatibility matrix

CI and hardware tests cover both `arm64` and `x86_64` where supported. Public APIs
are tested on the minimum macOS version and current releases. Private compatibility
evidence is recorded by exact build and architecture in `PrivateCapabilities/`.

