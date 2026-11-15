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
- -Configuration Release|Debug selects the configuration (default Release).
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
  See README_EXPANDED_STEAM.md before changing Steamworks headers or libraries.
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
tools and their linker PDBs are linked into the selected build tree. Each
requested build publishes the selected binaries and PDBs to `sp/game/bin` for
tools or `sp/game/mod_<game>/bin` for game DLLs, even when Ninja can reuse the
linked files. To install an E:Z mod, copy its complete mod directory, including
the published bin files and required game content, to Steam/SteamApps/sourcemods.
The EZ2 content directory must be supplied separately.

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

Install Source SDK Base 2013 Singleplayer (Steam App ID 243730) and Python 3.11
or later. The shader build uses Valve's shadercompile.exe and the matching DLLs
in the installed SDK's bin directory. The generator uses the Python standard
library. Run this command to build EZ2 shaders.

```powershell
./build.ps1 -Game EZ2 -Group shaders
```

The shaders and everything groups resolve the compiler in this order.

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

Set the interpreter with -DPython3_EXECUTABLE=<absolute path> in
-CMakeArguments when needed. To clear a compiler path saved by an older build,
pass '-UREVISION_SHADERCOMPILE_EXECUTABLE' once in -CMakeArguments. Python and
the SDK compiler are required only when configuring shaders or everything.

Shader DLLs go to the selected mod's bin directory and shader bytecode to its
shaders/fxc directory. Shader intermediates remain in the build tree. The
stdshader_dx9_*.txt files are checked-in inputs; update them when adding or
removing shader combinations.

## VALIDATION

Build the affected targets in Debug and Release. Run the mod under
`steamapps/sourcemods` to verify gameplay changes.

GamepadUI is not part of this repository's build: only the existing game hooks
are compiled. Bring your own implementation and CMake target if you need that
integration. The shader groups stay opt-in because their Valve tooling is not
redistributable.
