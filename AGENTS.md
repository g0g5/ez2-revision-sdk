## Overview
Revision SDK is the Source SDK 2013 Singleplayer branch behind the Entropy: Zero (EZ1/EZ2) mods, carrying Mapbase v8.0 features plus the Expanded Steam integration; work here means writing C++ game code and shaders that compile into `client.dll` / `server.dll`.

## Tech Stack

- Language: C++ (Source Engine 2013 style, pre-C++11 idiom), HLSL and Valve `SDK_` shaders, PowerShell and Perl build helpers
- Runtime / Framework: Source Engine 2013 singleplayer (`client.dll`, `server.dll`, VGUI2, VScript/Squirrel)
- Key Dependencies: Steamworks SDK (`sp/src/lib/public/steam_api.lib`, prebuilt), vendored protobuf 2.3.0, vendored Squirrel, Discord RPC
- Package Manager: none; native CMake + Ninja, Windows MSVC x86 (VS 2022/2026 Desktop C++ and CMake tools), PowerShell 7

## Structural Map

```
revision-sdk/
|- LICENSE                        # Valve SOURCE 1 SDK License; free distribution only, ship it with thirdpartylegalnotices.txt
|- README.md                      # Short project overview, minimal build guide, links to docs/
|- docs/                          # Split README content: building.md, entropy-zero.md, mapbase.md
|- README_EXPANDED_STEAM.md       # Steamworks / Steam Input / Steam Deck integration notes
|- CMakeLists.txt                 # Game selection and build groups
|- build.ps1                      # Discovers VS, initializes x86 tools, configures and builds with Ninja
|- cmake/                         # SourceSDK.cmake compiler/link settings; Shaders.cmake shader pipeline
|  \- targets/                    # Explicit source inventories; client/server_common.cmake shared sources
|- .github/workflows/             # Windows CMake game/tool builds
\- sp/                            # The only engine branch in this repo (singleplayer)
   |- game/                       # Runtime content and build output root, one directory per game target
   |  |- mod_ez1/                 # EZ1 install unit: gameinfo.txt, cfg/, resource/, scripts/, bin/ (build output)
   |  |- mod_hl2/                 # Mapbase content target: maps/, materials/, scripts/, shaders/
   |  |- mod_episodic/            # Episodic content target
   |  |- mod_ez2/                 # EZ2 DLL/PDB output only; gameinfo and content are not committed
   |  \- ep2/ episodic/ hl2/ lostcoast/   # Stock HL2 content targets
   \- src/                        # All engine, game and tool source code
      |- devtools/bin/            # Valve Perl shader helpers
      |- public/                  # Shared SDK headers and implementations: entities, networking, BSP, math
      |- tier0/ tier1/ vstdlib/ common/ mathlib/ raytrace/   # Engine support libraries shared by everything
      |- game/
      |  |- client/               # Client-side: c_* entities, HUD, CInput, render proxies, effects
      |  |  |- hl2/ episodic/ hl2mp/ mod/     # Game-specific client code
      |  |  \- mapbase/ ez2/ ezu/ Human_Error/ game_controls/   # Mod-specific client code
      |  |- server/               # Authoritative simulation: AI, NPCs, physics, entities, navigation
      |  |  \- hl2/ episodic/ hl2mp/ mod/     # Server code, plus mod-specific mapbase/ ez1/ ez2/ Human_Error/
      |  |- shared/               # Code compiled into both client and server, including hl2/ episodic/ hl2mp/ econ/ mapbase/ ez2/
      |  \- gamepadui/            # Only igamepadui.h; the implementation comes from entropy-zero/HL2-GamepadUI
      |- materialsystem/          # stdshaders/ (SDK_ shader sources) and shaderapidx9/
      |- vgui2/                   # VGUI2 UI framework: src/, vgui_controls/, include/, chromehtml/
      |- vscript/                 # VScript bindings plus vendored squirrel/ (ships its own CMake/Makefile, unrelated to the game build)
      |- responserules/runtime/   # New Response System runtime library
      |- expanded_steam/          # Expanded Steam integration (in_steaminput.cpp)
      |- fgdlib/                  # FGD parsing library used by editor and map tools
      |- utils/                   # Map and asset toolchain: vbsp/ vvis/ vrad(+launcher)/ vmpi/ glview/ vtf2tga/ captioncompiler/ vice/ ...
      |- thirdparty/protobuf-2.3.0/   # Vendored protobuf for networking and GC protocols
      |- lib/public/              # Prebuilt import libraries: steam_api.lib, expanded_steam.lib, discord-rpc.lib, libz, libprotobuf
      |- gcsdk/                   # protoc.exe and Steam GC support
      \- dx9sdk/ dx10sdk/         # D3D SDK shader helper utilities
```

## Commands

Run from the repository root with PowerShell 7. `build.ps1` finds VS and its bundled CMake/Ninja automatically.

```powershell
./build.ps1                                      # EZ2 Release, incremental
./build.ps1 -Configuration Debug
./build.ps1 -Game All                            # HL2, Episodic, EZ1, EZ2
./build.ps1 -Group tools                         # Map tools and asset tools
./build.ps1 -Target client_ez2                   # One DLL and its dependencies
```

- Verification is compilation plus an in-game smoke test. There is no unit-test or packaging target; run the mod under `steamapps/sourcemods` to validate gameplay.
- Add sources to `cmake/targets/*.cmake`; shared client/server sources belong in the corresponding `*_common.cmake`. Build artifacts and caches live under `build/`, game DLLs/PDBs under `sp/game/mod_<game>/bin`, tools under `sp/game/bin`.
- Keep x86: the engine ABI and vendored libraries are 32-bit. Static SDK libraries are rebuilt in the build tree, not over the vendored `.lib` files.
- `phonemeextractor` and `qc_eyes` require obsolete toolsets/MFC and are not build targets. GamepadUI implementation is external; this repository builds only its existing game hooks.
- `REVISION_BUILD_EXPANDED_STEAM` defaults to `OFF`; rebuilding needs matching updated Steamworks headers, `REVISION_STEAMWORKS_VERSION`, and the engine-side `bin/steam_api.dll`. See `README_EXPANDED_STEAM.md`.
- `-Group shaders` / `everything` needs external Valve `shadercompile.exe` with its runtime DLLs and native Windows Perl. See `cmake/Shaders.cmake` and `docs/building.md` for cache paths.
- Mod-specific code is isolated by preprocessor macros (`EZ`, `EZ1`, `EZ2`, `MAPBASE`); keep stock `hl2/` and `episodic/` paths intact when touching shared files.
- This is a derivative of Source SDK 2013 / Mapbase v8.0. `LICENSE` allows free redistribution only and requires shipping `thirdpartylegalnotices.txt`; do not introduce GPL-like copyleft code.

## Workflows
[No content yet.]

## Notes
[No content yet.]
