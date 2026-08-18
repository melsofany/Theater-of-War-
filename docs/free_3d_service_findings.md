# Free 3D Service Findings

## SupaVoxel
- URL: https://supavoxel.com/
- Image-to-3D service with GLB/GLTF/FBX/OBJ/USDZ/STL export claims.
- Page states no credit card and 3 free models per day.
- The page describes the output as a voxel model and advertises auto-generated PBR textures.
- The public page leaves the detailed commercial-use FAQ answer collapsed; commercial rights must be verified from Terms before shipping.
- Free tier is suitable for a small proof-of-concept, not bulk generation of an entire city.

## AI3DGen
- URL: https://www.ai3dgen.com/image-to-3d-model-free
- Page states no sign-up and no credit card for the free image-to-3D generator.
- The free version is explicitly described as a basic OBJ mesh using a Lite AI model, limited daily usage, fixed geometry, and basic color mapping.
- The page promotes production-ready PBR/topology as paid features, so it is unlikely to meet the photorealistic city requirement by itself.
- The visible generator advertises roughly 50 seconds and supports an upload flow, but the free page text conflicts with broad marketing claims about GLB export; this needs a real upload/download test before integration.

## Existing Meta AI assets
- The repository contains user-provided Meta AI assets under incoming_meta_assets/.
- city_airfield.png is a top-down airport tile with black background and magenta guide/connection lines, not a clean standalone building asset. It should not be sent to image-to-3D conversion as a city-building source without first getting a suitable Meta AI asset from the user.
- No generated or newly authored image has been added.

## Initial conclusion
- A free web image-to-3D service can improve a few hero props or unit models, but it cannot transform a whole procedural city into GTA V-level photorealism from one top-down reference image.
- The most credible integration path is: use only clean Meta AI building/unit images as inputs, convert a very small number of hero assets to GLB, keep the city layout procedural, and improve the rest with licensed CC0 models/materials and better scene composition.

## Suitability of current city images

The available `city_airfield.png` and `city_village.png` files are complete top-down tiles with black margins and magenta connector guides. They are not isolated, multi-view building references. Converting them directly to GLB would likely create a distorted slab or a single fused diorama, not a reusable modern tower. Therefore the service test should use a clean Meta AI unit/vehicle image or wait for a clean building image from the user; it should not be used to fake a city asset.

## Hugging Face Spaces check

The public TripoSR Space (`stabilityai/TripoSR`) and Hunyuan3D-2.1 Space (`tencent/Hunyuan3D-2.1`) were opened directly. Both currently expose only the repository shell and report `Running on ZERO`; the interactive app is blank in the current environment. They are therefore not reliable as an immediate no-token integration endpoint. The underlying open-source models may be strong, but running them locally requires GPU memory that is not available in this sandbox, and a hosted Space would need a live GPU allocation or a user-owned endpoint.

## Poly Haven / CC0 asset service

The official Public-API repository confirms that the live API is `https://api.polyhaven.com`, free for personal and commercial use, while the assets are CC0 and need no attribution; applications using the live API must provide a small Powered by Poly Haven credit. Search results identify a directly relevant asset named `modular_urban_apartments_facade`, plus urban-street HDRIs and facade materials. In this sandbox, both the API endpoint and Poly Haven pages timed out/failed TLS, so live download cannot be completed from this environment today. The service remains the best legal asset-source integration candidate, but it cannot yet be claimed as installed in the project.

## SupaVoxel test

SupaVoxel's public page advertises no-card generation, three free models per day, and GLB export. The page also exposes an Architecture category and a clear upload area. I attempted to upload the existing Meta AI `humvee_vehicle.png` through the public generator after activating the upload area; the browser session could not locate the hidden file input, so no generation or downloadable GLB was obtained. This is a browser automation limitation, not evidence that the service is technically unavailable. The page was also not sufficient to establish an explicit commercial-use license for generated outputs; that must be confirmed from its Terms before shipping any generated asset.

## Sniper asset observation

The current `assets/sprites/units/sniper.png` is a small blurred gray top-down sprite with a large white halo. The existing Meta AI `incoming_meta_assets/infantry_topdown.png` is a much sharper transparent-style sheet containing five camouflaged top-down soldiers with rifles. It is not a dedicated sniper, but it is a valid user-supplied source that can replace the unusable silhouette by cropping one soldier and using it as the sniper sprite; no new image generation is necessary.

## Meta AI asset inventory

The provided `meta_asset_sheet.png` contains top-down military units and small strategic facilities (airfield, military base, port, village), but no clean modern tower facade or reusable urban building set. It can improve units and strategic POIs, not the missing photorealistic city architecture. The project must not pretend these map tiles are city meshes.

## Implemented free integration

The practical route that worked in this environment is **KayKit City Builder Bits**, obtained from the official GitHub repository `KayKit-Game-Assets/KayKit-City-Builder-Bits-1.0`. Its README and `LICENSE.txt` declare **CC0 1.0 Universal**. The source pack provides low-rise buildings, cars, streetlights, benches, roads, and other city props.

Godot 4.3 did not expose the text `.gltf` files as regular preload resources in this project, so the selected assets were converted locally to embedded `.glb` files using the open-source glTF Transform CLI. The game loads those GLB files through `GLTFDocument.append_from_file()` at runtime. `StreetDetails.gd` now uses detailed KayKit cars, streetlights, and benches; `PhotorealCityGenerator.gd` adds KayKit low-rise buildings around the existing procedural glass towers. No image was generated and no Generals: Zero Hour asset was used.

The runtime asset verification passed for the selected GLBs and both modified world scripts. Godot still reports renderer resource-leak diagnostics when the short verification process exits; this is a test-process cleanup warning, not a missing-resource or script parse failure.

## Visual verification

`capture/modern_city_kaykit.png` rendered successfully at 1280x720. The KayKit assets are visible in the scene: low-rise textured building forms, colored storefront details, street props, and the existing glass towers. However, the current camera framing leaves a large empty sky area and the towers still read as stylized/low-poly rather than photorealistic. This confirms the free integration is technically working, but it is an incremental asset-quality improvement, not a GTA V-level replacement for the tower facades.
