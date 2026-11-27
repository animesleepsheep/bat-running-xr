# XR-003 candidate 0.3.0 / versionCode 4
Native animated brand intro (automatic or trigger skip), 3D lobby with imported mascot, course diorama preview, stationary select/reset practice, quality settings with local persistence, back/replay and desktop keyboard fallback. Five PackedScene routes share one persistent XR rig. Transition guard and brief fade, release-to-rearm controls, no forced player/camera movement. Native labels are English initially (default font); Traditional Chinese localization, actual six tracks, login and racing are future work. No audio added at this stage. Practice is selection/reset; the full XR001 grip laboratory remains in XR002 regression scene. XR001/002 synthetic regression + XR003 smoke + dual APK static checks required. Physical visual and controller validation pending. Debug signature remains temporary; release secrets unconfigured.

## Cloud acceptance — PASS (2026-11-27)
- Build commit dc00e6f864b6d328ffef69412e62e8f4fced113a; run https://github.com/animesleepsheep/bat-running-xr/actions/runs/45937939367; artifact https://github.com/animesleepsheep/bat-running-xr/actions/runs/45937939367/artifacts/15171840923.
- XR002_GLTF_PASS and XR002_IMPORT_PASS for Standard/Lite, XR001_SMOKE_PASS, XR002_SMOKE_PASS, XR003_SMOKE_PASS with 9 transitions. Both APK_STATIC_PASS; pair signature and versionCode 4 pass. No hotfix required.
- ZIP 59589413 bytes SHA256 56ba4298d4967ff9911c1e197fa9c3b5b80eb967f73ea217d9ce27ec5cad3a33; CRC valid.
- Quest APK 84829605 bytes SHA256 d1d9210e93677df0ec9445a15d7efee5548d0acf23229e9e2374559e71a4d41e
- Focus APK 84829605 bytes SHA256 f6e1f9840387dbce73151ef3aee503afdcbbf98b9250150ff27f3db2e213acf0
- Downloaded both APK CRC and SHA256 match; five scene remaps, native router/scripts verified in both archives.
- Physical device rendering, controller interaction, performance, and durable signing/upgrade remain pending. The course preview is a diorama, not the six playable tracks. Next XR-004 identity and cloud learning records.
