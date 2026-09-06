# Body camera overlay

`bodycam_overlay.tscn` is instanced in `experiments/player/test_scene.tscn`.
The hierarchy, material, logo atlas, labels and clock timer are editable before running the scene.

Reference: https://www.axon.com/help/axon-evidence/software/axon-evidence/inventory-and-devices/timestamp-watermark.htm
Axon places the date/time, camera model and serial number in the upper right corner.
The display uses `AXON BODY 3` and an illustrative, editable device ID, with the supplied Axon icon.
The clock follows actual system time; the default suffix is the local UTC offset (`+0400`, for example).
`use_local_time = false` selects UTC (`+0000`). This is a visual recreation, not exact device firmware emulation.

## Tuning

Open `bodycam_settings.tres` in the Inspector:

- Watermark: enable, opacity, model, device ID, local/UTC time, first-person-only mode.
- Lens: distortion, vignette, chromatic aberration.
- Sensor/image: shadow-weighted noise, noise refresh rate, saturation, contrast, exposure.
- Motion: turn-dependent smear and rolling shutter strength.
- Compression strength: subtle tonal quantization, not actual video encoding.

Effects and watermark can be enabled independently. By default they appear in both view modes.
The watermark is drawn after post-processing, keeping it crisp. Existing camera motion still supplies physical movement.
This overlay does not relocate the camera from the eyes to the chest.

`experiments/player/tests/bodycam_test.gd` checks scene composition, timezone rollover,
clock updates, view visibility and mouse input passthrough. With rendering enabled it saves
`artifacts/bodycam-preview.png`.
