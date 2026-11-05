# The Quiet Sands

A standalone Godot 4.7 desktop project. Open `project.godot` in Godot 4.7 and press F6 or F5. The scene starts directly in the desert. All geometry, grain textures, and sounds are generated locally; no addons, asset downloads, or files from the enclosing project are required.

## Controls

| Control | Action |
| --- | --- |
| WASD / arrow keys | Walk relative to the camera |
| Shift | Run |
| Space | Jump |
| Ctrl / C, held | Slide; downhill slopes build momentum |
| Mouse | Orbit camera |
| Mouse wheel | Adjust camera distance |
| Escape | Release mouse |
| Left click | Capture mouse again |

## World

The world spans X/Z −1024 to +1024, with about 217 units of relief. Nineteen individually placed, curved dune formations establish the large shapes; smaller surface variations connect them. The starting overlook is at (−616, −696). The oasis is at (0, −140), the natural arch at (560, 460), and the sandstone spires at (−550, 630). Six ruin groups and fifteen outcrops use the requested placements. Thirteen individually varied palms surround the oasis.

`scenes/quiet_sands.tscn` is the entry scene. Landmark scenes are reusable independently. `scripts/world.gd` assembles the landscape, lighting, atmosphere, and original synthesized audio at runtime. The editor scene tree is intentionally small before running. A native baked heightfield avoids repeating the expensive dune sculpting calculation on each launch. After editing the dune composition in `terrain.gd`, regenerate it with `godot --headless --path . --script res://validation/bake_terrain.gd`.

## Sand and interaction

The sand combines contrast-shaped diffuse light, Gaussian grain normals, four slope/wind ripple fields, broad Blinn–Phong highlights, Fresnel edges, and camera/light-dependent glitter. World coordinates, domain warping, and decorrelated texture samples reduce repetition. Analytic derivative filtering, mipmapped anisotropic grain sampling, distance attenuation, MSAA, and TAA control fine detail. The `materials/sand.tres` shader exposes colors and every major effect strength. `layer_view` enables cumulative material studies; zero is the integrated material.

A 513 × 513 heightfield is split into 256 visible chunks. Nine 16-unit patches around the traveler replace the coarse surface with 0.25-unit geometry. Footprints, landing impacts, and sliding change those vertices and matching heightfield collision. Depressions have raised sand rims and a restrained cyan response. Geometry relaxes with a 110-second time constant; glow fades faster. Nearby patch updates reuse cached baseline geometry and normals. Disturbed patches survive travel away and back during the session. History is bounded and old, inactive patches are eventually reclaimed; tracks are not saved between launches.

The traveler has a procedural cloak, animated boots and scarf, slope movement, momentum-based sliding, a collision-aware orbit camera, and sand particles. The oasis has a shallow, walkable pool, Fresnel color, wave normals, shoreline coloration, and up to eight expanding interaction ripples. Palm fronds and crest sand move with the wind. No UI, quests, menus, or music are included.

## Validation

The project is exercised with the locally installed Godot 4.7.2 official build. Graphical captures use Forward+ through Vulkan on an AMD Radeon Pro 555X. Headless checks alone do not validate shaders; `validation/capture.gd` renders the materials on the GPU.

```sh
godot --headless --path . --script res://validation/traversal.gd -- --validate
godot --path . --script res://validation/capture.gd -- --capture
```

`validation/results.json` records the most recent movement, placement, deformation, settling, persistence, and collision checks. `captures/` contains rendered opening, dune, oasis, mountain, ruin, sand-layer, overhead, grazing-angle, footprint, and sliding-trail images. These are engine captures, not concept art. Rendering can take longer on the first launch while the driver compiles pipelines.

Validation is limited to the local macOS/Godot/GPU combination. Windows and Linux builds, controllers, and other GPU drivers have not been tested. The scarf uses procedural animation, not cloth physics. Sand interaction is localized deformation with settling, not a granular fluid simulation. Water uses shallow-water color rather than scene-depth refraction.

See `REFERENCES.md` for the technical sources and attribution.
