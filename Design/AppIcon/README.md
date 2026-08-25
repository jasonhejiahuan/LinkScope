# LinkScope app icon source

The production icon is assembled in Icon Composer from the SVG layers in this
directory. Its geometry is traced from the supplied 465 × 432 LinkScope crop:
a central scope ring, a short left orbit, a long right/bottom orbit, and two
source nodes. Both orbit SVGs are dash segments of the exact same circle
(`cx=236`, `cy=220`, `r=170`), and the scope ring shares that center. Every
layer preserves the original coordinate system. The white reference background
is not part of the artwork.

Layer order, back to front:

1. `01-left-orbit.svg` — short left observation arc
2. `02-long-orbit.svg` — long right/bottom arc with the reference fade
3. `03-nodes.svg` — top and lower-left source nodes
4. `04-scope-ring.svg` — central scope ring

The artwork uses the reference image's 465 × 432 view box. Keep the SVGs as the
editable source even after `LinkScope.icon` is exported. The combined
`LinkScope-geometry-preview.svg` exists only for geometry QA and is not imported
as an Icon Composer layer.

Color intent:

- medium blue for the two orbits
- lighter blue for the top source node
- saturated blue for the lower node and scope ring

The earlier offset-aperture concept was rejected and is not used by the icon.
These SVGs are the production source of truth.
