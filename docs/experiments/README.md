# Feasibility experiment registry

Experiments answer risky compatibility questions without becoming production
dependencies. Each experiment receives a dated Markdown record containing:

- hypothesis and non-goals;
- exact Mac model, architecture, macOS build, and toolchain;
- framework/class/selector inputs where relevant;
- read-only safety boundary;
- procedure and captured evidence;
- outcome: supported, unsupported, ambiguous, or needs more devices;
- follow-up milestone and production-integration blockers.

Allowed early topics include private Bluetooth fields, multipart battery,
spatial/audio state, link quality, private HID, `system_profiler`, XPC crash
containment, Universal 2, macOS 15/26/27, and twelve-column grid interaction.

Experiment code must live outside the application production path or behind an
explicit development-only build condition. A successful probe does not by itself
promote a field into the stable product.

