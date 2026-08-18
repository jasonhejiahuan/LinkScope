# Milestone 4 — Advanced Dashboard System

**Status:** deferred, not cancelled. Grid-interaction feasibility probes are allowed now.

## Restored scope

- Arbitrary named dashboards.
- Twelve-column snap grid with keyboard-accessible placement.
- Widget drag, resize, duplicate, delete, and undo.
- Widget inspector and source/format configuration.
- Current-value, status, time-series, raw-table, timeline, and provider-health widgets.
- Custom layouts and versioned dashboard import/export.
- Portable layouts between Full and Lite, retaining unavailable-source placeholders.

## Foundation preserved in M0/M1

- Dashboard documents and widget placements are versioned from M0.
- Every widget refers to a stable `WidgetSourceID`, not a provider object or view type.
- Observation history and future diagnostic sampling use the same parameter identity.
- Unknown widget types/fields survive import/export for forward compatibility.
- The initial inspector is a consumer of generic observations, not a temporary
  storage schema masquerading as a dashboard model.

## Acceptance criteria

- Layout changes support undo and survive restart.
- Keyboard-only users can add, move, resize, configure, and remove a widget.
- Importing a Full layout into Lite preserves unsupported widgets as explained
  placeholders rather than deleting them.
- Time-series widgets query indexed history and decimate off the main actor.
- A 50-widget reference dashboard remains responsive without causing an idle
  provider sampling loop.

