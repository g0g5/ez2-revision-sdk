# Build and check game code

Use `check.ps1` for incremental C/C++ checks and `build.ps1` to verify linking with the Windows x86 toolchain.

- Run both scripts from the repository root in PowerShell 7 with the matching `-Game` selection. Use `-Configuration Debug` for Debug checks and builds. `build.ps1` finds Visual Studio and its bundled CMake and Ninja automatically.
- After each batch of C/C++ edits, pass the changed sources and headers to `check.ps1`. It compiles MSVC x86 objects for each source variant and uses Ninja's recorded includes to check one translation unit per known target for each header. In a fresh build tree, include a source that uses the header.
- Build the affected DLL targets to check linking. Agents verify code and builds, and a human validates in-game behavior. There is no unit-test or packaging target.
- Update `cmake/targets/*.cmake` when adding or removing sources. Use `client_common.cmake` or `server_common.cmake` for sources used by all four games on that side, and the per-game lists for the differences.
- Isolate mod-specific code with the existing `EZ`, `EZ1`, `EZ2`, and `MAPBASE` macros. Preserve stock HL2 and Episodic behavior when editing shared files.
- Keep the Windows x86 ABI. Incremental builds use separate trees under `build/<games>/<Configuration>/`, and rebuilt static libraries stay in the build tree. CMake publishes game DLLs and PDBs to `sp/game/mod_<game>/bin` and tools to `sp/game/bin`. Each client build publishes `discord-rpc.dll` and its PDB alongside `client.dll`.
- CMake can fetch missing prebuilt x86 SDK libraries from a pinned revision, verify their SHA-256 hashes, and cache them under `build/sdk-libraries/`. See [the build guide](../../docs/building.md#windows-x86-sdk-libraries) for offline builds.
- `REVISION_BUILD_EXPANDED_STEAM` defaults to `OFF`. Rebuilding requires matching updated Steamworks headers and `REVISION_STEAMWORKS_VERSION`. Keep the engine-side `bin/steam_api.dll` compatible with that SDK. See [Expanded Steam](../../docs/expanded-steam.md).
- `phonemeextractor` and `qc_eyes` require obsolete toolsets and MFC and are outside the supported build targets. GamepadUI comes from an external implementation. The game builds include its existing hooks.
