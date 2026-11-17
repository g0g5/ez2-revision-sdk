## Overview
Revision SDK builds the C++ game DLLs, DirectX 9 shaders, and map tools for Entropy: Zero on Source SDK 2013 Singleplayer, with Mapbase v8.0, Expanded Steam, and LUX shaders for EZ2.

## Tech Stack

- Language: C++ (Source Engine 2013 style, pre-C++11 idiom) and HLSL, with build helpers in PowerShell and Python
- Runtime / Framework: Source Engine 2013 singleplayer (`client.dll`, `server.dll`, VGUI2, VScript/Squirrel)
- Key Dependencies: Windows x86 SDK libraries, Steamworks, vendored protobuf 2.3.0 and Squirrel, and source-built Discord RPC v3.4.0 with vendored RapidJSON
- Package Manager: none. Build with PowerShell 7, CMake, Ninja, and MSVC x86 from Visual Studio 2022 or 2026 with Desktop development with C++ and CMake tools.

## Structural Map

```
revision-sdk/
|- LICENSE                        # Valve SOURCE 1 SDK License
|- README.md                      # Short project overview, minimal build guide, links to docs/
|- docs/                          # Build, Entropy Zero, Mapbase, LUX, and Expanded Steam documentation
|- CMakeLists.txt                 # Game selection and build groups
|- build.ps1                      # Discovers VS, initializes x86 tools, configures and builds with Ninja
|- check.ps1                      # Incremental object compilation for changed C/C++ files
|- scripts/                       # Shared PowerShell build driver and object target discovery
|- cmake/                         # SDK target setup, library resolution, and runtime publishing
|  |- Shaders.cmake               # Legacy shader pipeline and dispatch to LUX
|  |- LuxShaders.cmake            # EZ2 LUX shader DLL and bytecode build
|  \- targets/                    # Explicit source inventories for game DLLs, libraries, and tools
\- sp/                            # The only engine branch in this repo (singleplayer)
   |- game/                       # Runtime content and build output root, one directory per game target
   |  |- mod_ez1/                 # EZ1 install unit: gameinfo.txt, cfg/, resource/, scripts/, bin/ (build output)
   |  |- mod_hl2/                 # Mapbase content target: maps/, materials/, scripts/, shaders/
   |  |- mod_episodic/            # Episodic content target
   |  |- mod_ez2/                 # Published EZ2 binaries and shader bytecode, with runtime content supplied separately
   |  \- ep2/ episodic/ hl2/ lostcoast/   # Stock HL2 content targets
   \- src/                        # All engine, game and tool source code
      |- devtools/bin/            # DirectX runtime used by the shader compiler
      |- public/                  # Shared SDK headers and implementations: entities, networking, BSP, math
      |- tier1/ common/ mathlib/ raytrace/   # Shared engine support code
      |- game/
      |  |- client/               # Client-side: c_* entities, HUD, CInput, render proxies, effects
      |  |  |- hl2/ episodic/ hl2mp/          # Game-specific client code
      |  |  \- mapbase/ ez2/ ezu/ Human_Error/ game_controls/   # Mod-specific client code
      |  |- server/               # Authoritative simulation: AI, NPCs, physics, entities, navigation
      |  |  |- hl2/ episodic/ hl2mp/ mod/   # Game-specific server code
      |  |  \- mapbase/ ez1/ ez2/ Human_Error/   # Mod-specific server code
      |  |- shared/               # Code compiled into both client and server, including hl2/ episodic/ hl2mp/ econ/ mapbase/ ez2/
      |  \- gamepadui/            # Only igamepadui.h; the implementation comes from entropy-zero/HL2-GamepadUI
      |- materialsystem/
      |  |- lux/                  # EZ2 LUX shader library and shader sources
      |  |- stdshaders/           # Legacy SDK_ shaders and Mapbase compatibility passes for LUX
      |  \- shaderapidx9/         # DirectX 9 shader API code
      |- vgui2/                   # VGUI2 UI framework: src/, vgui_controls/, include/, chromehtml/
      |- vscript/                 # VScript bindings plus vendored squirrel/ (ships its own CMake/Makefile, unrelated to the game build)
      |- responserules/runtime/   # New Response System runtime library
      |- expanded_steam/          # Expanded Steam integration (in_steaminput.cpp)
      |- fgdlib/                  # FGD parsing library used by editor and map tools
      |- utils/                   # Map and asset toolchain: vbsp/ vvis/ vrad(+launcher)/ vmpi/ glview/ vtf2tga/ captioncompiler/ vice/ ...
      |- thirdparty/protobuf-2.3.0/   # Vendored protobuf for networking and GC protocols
      |- lib/public/ lib/common/  # Locations for locally supplied prebuilt x86 SDK libraries
      |- gcsdk/                   # protoc.exe and Steam GC support
      \- dx9sdk/ dx10sdk/         # D3D SDK shader helper utilities
```

## Commands

```powershell
# Run from the repository root in PowerShell 7. After each batch of C/C++ edits, check the changed sources and headers.
./check.ps1 -Game EZ2 -Files sp/src/game/server/ai_basenpc_movement.cpp,sp/src/game/server/ai_basenpc.h

# Link the affected DLL. The default builds both EZ2 DLLs in Release, and -Game All builds HL2, Episodic, EZ1, and EZ2.
./build.ps1 -Game EZ2 -Target server_ez2
./build.ps1
./build.ps1 -Game All

# Build the map and asset tools.
./build.ps1 -Group tools

# Build the EZ2 LUX shader DLL and bytecode.
./build.ps1 -Game EZ2 -Group shaders

# If the local helper is present, use it to build and deploy the four EZ2 DLLs to an installed mod.
./local_ez2_build.ps1
```

## Workflows

- [build-and-check-game-code.md](.agents/workflows/build-and-check-game-code.md) - Build and check game code.
- [build-shaders.md](.agents/workflows/build-shaders.md) - Build shaders.
- [deploy-game-binaries.md](.agents/workflows/deploy-game-binaries.md) - Deploy and distribute game binaries.

## Notes

[No content yet.]
