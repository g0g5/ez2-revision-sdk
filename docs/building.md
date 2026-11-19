# Building the Source SDK

## WINDOWS BUILD (CMake + Ninja)

Requirements:
- Windows and PowerShell 7 (pwsh).
- Visual Studio 2022 or 2026, with Desktop development with C++, the MSVC x86/x64
  tools, a Windows SDK, and C++ CMake tools for Windows (bundled CMake and Ninja).
- The engine and its prebuilt SDK libraries use the Windows x86 (32-bit) ABI.
  Keep this ABI even on 64-bit Windows; x64 game binaries are not compatible.

Run from the repository root in PowerShell 7:

```powershell
./build.ps1
```

This configures and builds EZ2 Release, group game. The script uses vswhere to
locate Visual Studio (including preview installations), initializes its developer
shell for an x64 host and x86 target, and uses that installation's bundled CMake
and Ninja. A pre-initialized developer terminal is not required. Environment
changes are limited to the current process and restored when the script exits.

### Build options

- -Game EZ2,EZ1,HL2,EPISODIC selects one or more games. The default is EZ2;
  -Game All selects all four games.
- -Group game|maptools|tools|shaders|everything selects the default build group.
  game builds the selected client/server DLLs; maptools builds VBSP, VVIS and
  VRAD; tools includes maptools plus the other supported utilities and example
  server plugin. everything includes game, tools and shaders. The default is game.
- -Target selects individual configured Ninja targets instead of the default
  group, for example client_ez2, server_ez2, vbsp or captioncompiler. A game's
  targets are available only when that game is selected by -Game. Shader targets
  require -Group shaders or everything.
- `-Configuration Release|Debug|Publish` selects the configuration (default Release).
  Publish uses Release optimizations and produces no PDBs. The optional
  `local_ez2_build.ps1` defaults to Publish for its build and deployment.
- -Jobs N sets parallel build jobs (default: logical processor count).
- -Clean cleans before building; it does not delete the CMake cache.
- -ConfigureOnly configures without building or cleaning.
- -BuildDirectory PATH overrides build/<games-joined-by-hyphens>/<Configuration>.
  Relative paths are resolved against the repository root.
- -CMakeArguments accepts an array of additional CMake configure arguments.
  Quote arguments containing spaces or semicolons.

### Examples (PowerShell 7)

```powershell
./build.ps1 -Game EZ2,EZ1 -Configuration Debug -Jobs 8
./build.ps1 -Game HL2 -Target client_hl2 -Clean
./build.ps1 -Group tools -Configuration Release
./build.ps1 -Game All -ConfigureOnly -BuildDirectory build/all-debug -Configuration Debug
./build.ps1 -CMakeArguments '-DREVISION_USE_PCH=OFF'
```

### Root CMake cache variables

- REVISION_GAMES: semicolon-separated game list, default EZ2; valid entries are
  EZ2, EZ1, HL2 and EPISODIC. All is a build.ps1 convenience, not a CMake value.
- REVISION_BUILD_GROUP: game (default), maptools, tools, shaders or everything.
- REVISION_USE_PCH: game DLL precompiled headers, default ON.
- REVISION_BUILD_EXPANDED_STEAM: rebuild Expanded Steam from source, default OFF.
- REVISION_STEAMWORKS_VERSION: integer Steamworks header version, default 1261.
  See [Expanded Steam](expanded-steam.md) before changing Steamworks headers or libraries.
- REVISION_DOWNLOAD_SDK_LIBRARIES: download missing Windows x86 SDK libraries,
  default ON.
- REVISION_SDK_LIBRARY_CACHE: cache shared by build trees in this checkout.
  Defaults to `build/sdk-libraries`.

For example, to pass a game list directly as a CMake cache argument:

```powershell
./build.ps1 -CMakeArguments '-DREVISION_GAMES=EZ2;EZ1', '-DREVISION_USE_PCH=OFF'
```

Prefer -Game when selecting games so the default build directory matches the
selection. Keep distinct build trees for different configurations. Game DLLs,
tools and, in Debug and Release, their linker PDBs are linked into the selected
build tree. Each requested build publishes these artifacts to `sp/game/bin` for
tools or `sp/game/mod_<game>/bin` for game DLLs, even when Ninja can reuse the
linked files. To install an E:Z mod, copy its complete mod directory, including
the published bin files and required game content, to Steam/SteamApps/sourcemods.
The EZ2 content directory must be supplied separately.

### Discord RPC runtime

All four game clients dynamically link `discord-rpc.dll`, built from the pinned
Discord RPC v3.4.0 sources in `sp/src/thirdparty/discord-rpc/`. Its RapidJSON 1.1.0
headers are vendored in `sp/src/thirdparty/rapidjson/`; neither dependency requires
a build-time download. Provenance and archive hashes are recorded in each
`README.revision.md`.

Building a client also builds the matching Windows x86 DLL and publishes it
alongside `client.dll` in `sp/game/mod_<game>/bin/`, with its PDB in Debug and
Release builds. Publishing runs even when the linker has no work, so rebuilding
the client restores a missing runtime
DLL. Copy `discord-rpc.dll` with the client when installing a mod; the prebuilt
`sp/src/lib/public/discord-rpc.lib` is superseded by the source-built import
library. Distribute `thirdpartylegalnotices-discord-rpc.txt` with these binaries,
in addition to the SDK's `LICENSE` and `thirdpartylegalnotices.txt`.

The library uses its own C++14 and exception options, leaving the game's settings
unchanged. The upstream I/O thread remains enabled. The upstream library is
deprecated; its pinned C API and dynamic linking match the existing integration.

### Windows x86 SDK libraries

CMake uses libraries supplied under `sp/src/lib/public` and `sp/src/lib/common`.
On a clean checkout, the first configure downloads the missing libraries from
[Entropy Zero's pinned Source SDK revision](https://github.com/entropy-zero/source-sdk-2013/tree/4c4fea9c4f8657bd66f964570e11a1714389bc77/sp/src/lib)
and verifies each SHA-256 before caching it. For an offline build, reuse a
populated cache or supply the matching x86 libraries in those source
directories. Set `REVISION_DOWNLOAD_SDK_LIBRARIES=OFF` to disable downloads.

## SOURCE LIST MAINTENANCE

The build uses native CMake source inventories in cmake/targets/*.cmake.
client_common.cmake and server_common.cmake contain the shared source intersection
for their respective game DLLs; client_<game>.cmake and server_<game>.cmake hold
the per-game differences. When adding or removing C++ sources, update the
appropriate inventory explicitly. Put a source in a common list only when every
supported game on that side uses it, and check the affected game/configuration
combinations. Other libraries and tools have their own target inventories.

## SHADERS (OPTIONAL)

Shader builds require Python 3.11 or later. Build the EZ2 LUX shaders with the
same CMake and Ninja entry point as the game DLLs.

```powershell
./build.ps1 -Game EZ2 -Group shaders
```

### EZ2 with LUX

CMake downloads the x64 `ShaderCompile2.exe` from the pinned [LUX revision](https://github.com/LUX-Shaders-Team/LUX-Shaders/tree/c71803c9ff132003da991a6e3b12b6c8c5adafdc),
verifies its SHA-256 and caches it under `build/shader-tools/`. The compiler uses
`D3DCompiler_47.dll`. An offline build can use an existing compiler by passing
`-CMakeArguments '-DREVISION_SHADERCOMPILE2_EXECUTABLE=D:/tools/ShaderCompile2.exe'`.
The EZ2 shader build can run on a build system without a Steam SDK installation.

The sources under `sp/src/materialsystem/lux/` build against the SDK 2013 SP
interfaces. `ShaderList_All.txt`, `ShaderList_Custom.txt` and
`ShaderList_PostProcess_vs20.txt` drive the LUX bytecode. The adjacent legacy
shader tree contains `lux_compat_*.txt` for the Mapbase compatibility passes.
They build DepthWrite, EyeGlint, MonitorScreen, WindowImposter and
WorldTwoTextureBlend against LUX's shaderlib. `SDK_Eyeball` still resolves to
`Wireframe`. The other legacy names map to their LUX implementations.

The EZ2 client DLL includes the [SDK2013CE SM3 caps fix](https://github.com/Nbc66/source-sdk-2013-ce/commit/e458d3007b142dffa6d11458f379d2d8551457fb).
Use the client and shader DLLs from the same build. The private caps write and
the stock-name registration override target the Win32 retail SDK 2013 SP
`shaderapidx9.dll` (PE timestamp `0x5429D743`) and `materialsystem.dll`
(`0x5429D70F`), respectively. The loader checks the expected binary layouts.
On an unknown material-system build it registers only `LUX_*` and `SDK_*`.
An unknown shader API that reports fewer than 224 pixel constants may still
need a compatibility update for the shaders that use `c32` and above.

### HL2, Episodic and EZ1

These targets use Valve's `shadercompile.exe` and the matching DLLs from Source
SDK Base 2013 Singleplayer (Steam App ID 243730). The `shaders` and `everything`
groups resolve the legacy compiler in this order.

1. Use the absolute executable path supplied through the CMake cache variable
   REVISION_SHADERCOMPILE_EXECUTABLE.
2. Use the absolute SDK bin directory supplied through REVISION_SHADER_SDK_BIN
   in .shader.env.local at the repository root. This file is ignored by Git.
3. Look up Steam App ID 243730 in the Windows uninstall registry and then in
   the Steam library manifests. This uses read-only access as a regular
   Windows user and works with Steam closed.

For an SDK in D:/SteamLibrary, .shader.env.local looks like this.

```dotenv
REVISION_SHADER_SDK_BIN=D:/SteamLibrary/steamapps/common/Source SDK Base 2013 Singleplayer/bin
```

To clear a compiler path saved by an older build, pass
`'-UREVISION_SHADERCOMPILE_EXECUTABLE'` once in `-CMakeArguments`. The
`stdshader_dx9_*.txt` files are the legacy bytecode input lists.

Both build paths accept `-DPython3_EXECUTABLE=<absolute path>` in
`-CMakeArguments`. Shader DLLs go to the mod's `bin/` directory and bytecode to
its `shaders/fxc/` directory. Shader intermediates remain in the build tree.

## VALIDATION

Build the affected targets in Debug and Release. Run the mod under
`steamapps/sourcemods` to verify gameplay changes.

GamepadUI is not part of this repository's build: only the existing game hooks
are compiled. Bring your own implementation and CMake target if you need that
integration. The shader groups stay opt-in because their Valve tooling is not
redistributable.
