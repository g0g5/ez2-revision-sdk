# Half-Life 2: Revision

Source code repository of Half-Life 2: Revision, currently identical to Entropy Zero 2's SP with minor fixes and migrated to CMake.

## Build

Requirements: Windows, PowerShell 7, and Visual Studio 2022 or 2026 with the Desktop C++ workload (including its bundled CMake and Ninja). Keep the x86 ABI.

```powershell
./build.ps1                  # EZ2, Release
./build.ps1 -Game All        # HL2, Episodic, EZ1, EZ2
./build.ps1 -Group tools     # map and asset tools
```

Game DLLs go to `sp/game/mod_<game>/bin`, tools to `sp/game/bin`.

## Original READMEs

- [docs/building.md](docs/building.md) — build options, shaders and CI notes
- [docs/entropy-zero.md](docs/entropy-zero.md) — Entropy : Zero credits
- [docs/mapbase.md](docs/mapbase.md) — Mapbase v8.0 notes, attribution and external content
- [README_EXPANDED_STEAM.md](README_EXPANDED_STEAM.md) — Steamworks, Steam Input and Steam Deck integration
- [LICENSE](LICENSE) and [thirdpartylegalnotices.txt](thirdpartylegalnotices.txt) — Source 1 SDK license and third-party notices
