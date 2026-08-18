# Private capability manifests

These manifests reserve the runtime-discovery format for Milestone 3. They do
not cause LinkScope or LinkScope Lite to load a private framework, and an empty
manifest is intentional: unknown capabilities remain unavailable until an
isolated feasibility probe records exact build, architecture, selector encoding,
invocation adapter, returned-value format, and semantic evidence.

Rules:

- never infer a capability from a class or selector name;
- never mark a selector validated without a read-only isolated invocation;
- use exact macOS build evidence in `testedBuilds`;
- keep Lite completely disconnected from this directory at build and runtime;
- preserve unsuccessful and ambiguous probes in `docs/experiments/`.

