# Entropy Zero 2: Revision

Entropy Zero 2: Revision builds on the original EZ2 single-player code and incorporates community patches, fixes, and the LUX-Shaders project.

## Build

Requirements: Windows, PowerShell 7, and Visual Studio 2022 or 2026 with the Desktop C++ workload (including its bundled CMake and Ninja). Keep the x86 ABI.

```powershell
./build.ps1                  # EZ2, Release
./build.ps1 -Game All        # HL2, Episodic, EZ1, EZ2
./build.ps1 -Group tools     # map and asset tools
```

Game DLLs go to `sp/game/mod_<game>/bin`, tools to `sp/game/bin`.

## Documentation

- [docs/building.md](docs/building.md) — build options, shaders and CI notes
- [docs/entropy-zero.md](docs/entropy-zero.md) — Entropy : Zero credits
- [docs/mapbase.md](docs/mapbase.md) — Mapbase v8.0 notes, attribution and external content
- [LUX-Shaders](docs/lux.md) — upstream project overview and documentation
- [Expanded Steam](docs/expanded-steam.md) — Steamworks, Steam Input and Steam Deck integration
- [LICENSE](LICENSE) and [thirdpartylegalnotices.txt](thirdpartylegalnotices.txt) — Source 1 SDK license and third-party notices
