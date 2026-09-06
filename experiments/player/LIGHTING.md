# Corridor lighting

The scene uses eight downward SpotLight3D sources with 0.045 m light size,
plus eight weaker upward ceiling fill sources with shadows to keep upper walls
lit without light leaking through room partitions. SDFGI is explicitly disabled.
72 degree cones and 7 m range. Shadows use an 8192 atlas, four equally
subdivided quadrants, 32-bit depth and Ultra soft filtering in project.godot.
The desktop renderer is Forward+ with TAA and MSAA. These project settings
also affect other scenes and increase GPU cost; frame rate is not benchmarked.

The scene Environment uses filmic tone mapping, restrained glow, full-resolution
high-quality SSAO/SSIL and SSR. SSR/SSIL only use visible screen data, so they
cannot replace baked indirect illumination. Bodycam grain, colour quantization
and motion smear were reduced to preserve lighting detail.

SDFGI was visually evaluated and removed because the current thin-wall greybox
produced blotchy indirect lighting. No lightmaps have been baked. Static meshes
are marked for GI. Materials and meshes remain prototype assets: this is an
improved real-time lighting profile, not a photorealistic asset conversion.

All light nodes and environment parameters are authored in test_scene.tscn.
