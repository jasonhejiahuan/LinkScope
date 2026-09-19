# Editable App Store screenshot layouts

Two localizations, four shots each, exported as **2880 × 1800 RGB PNG without alpha**. The design uses a black stage, large silver-white type, restrained glass edging and one complete, real LinkScope Lite window per image. There are no Apple logos, device mockups, invented graphs or performance claims.

| File | Edit here |
| --- | --- |
| `copy.json` | English / Simplified Chinese headlines, subtitles, labels and type sizes |
| `template.svg` | Authoritative vector composition for PNG rendering |
| `template.html` | Editable HTML companion for reviewing the same composition in a browser |
| `render.mjs` | Image placement, rendering, output checks, provenance and contact sheet |

The sibling `captured/` directory contains these **user-supplied native app captures**:

```text
providers-en.png      providers-zh.png
dashboard-en.png      dashboard-zh.png
diagnostics-en.png    diagnostics-zh.png
permissions-en.png    permissions-zh.png
```

These PNG files replace the earlier computer-use JPEGs. `captured/native-provenance.json` maps each file to its original user-supplied filename and SHA-256. For each scene, the renderer accepts either `.jpg` or `.png`, reads the actual format, and embeds the complete original bytes with the matching `image/jpeg` or `image/png` MIME type. Keep only one file per scene: duplicate extensions stop the render rather than silently selecting a stale image.

Main-window originals measure 2798 × 1664 and use a 0.78125 scale; permission windows measure 1464 × 1280 and use a 1.0 scale. The renderer caps scaling at 1.0 and fits the full image without clipping, cropping, retouching, replacing text, changing metrics, or redrawing the UI. Native transparent window shadows are preserved during composition, then flattened for final output. Source hashes are checked again after rendering. Timeline and device-detail captures containing personal names or identifiers were excluded before composition; the renderer does not hide private information. The diagnostics scene shows an existing historical session, not evidence of a newly completed test.

From the repository root:

```sh
node Design/AppStore/2.0.0/source/render.mjs --preflight
node Design/AppStore/2.0.0/source/render.mjs
```

For one localization or shot, append `--locale en-US` or `--scene providers`. Missing source captures stop the render; no substitute content is fabricated. No browser or native app control is used by this script. It first resolves an existing `sharp` package, then the bundled Codex runtime package; it never installs dependencies. `LINKSCOPE_NODE_MODULES` may point to another existing module directory.

Outputs:

- `../exports/en-US/` and `../exports/zh-Hans/`: final-size PNGs and per-image provenance JSON.
- `generated/`: self-contained editable SVG and HTML files with the original JPEG or PNG embedded.
- `../index.html`: responsive contact sheet linking to full-size PNGs and editable sources.
- `../exports/manifest.json`: actual source format/MIME type, dimensions and placement scale, output color-channel checks and original/output SHA-256 digests.

Outputs remain **2880 × 1800, 8-bit RGB PNG without alpha** regardless of capture format. These dimensions and channels are verified automatically. All eight current exports were visually inspected on 2026-09-19. Repeat that review after changing images or copy, checking text clipping, readability, private information and truthful correspondence to the actual Lite edition. The SVG-generated PNG is authoritative if the browser's font rendering differs from the HTML companion.
