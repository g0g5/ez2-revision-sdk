# Deploy and distribute game binaries

Use the optional local helper for an installed EZ2 mod and include the required notices when distributing binaries.

- If present, the Git-ignored `local_ez2_build.ps1` builds and copies `client.dll`, `server.dll`, `game_shader_dx9.dll`, and `discord-rpc.dll` into an installed mod's `bin/`. Use `-GameDirectory` to select the installation.
- For shader changes, also install the matching bytecode from `sp/game/mod_ez2/shaders/fxc/`.
- The Source 1 SDK license permits free redistribution. Ship `LICENSE` and `thirdpartylegalnotices.txt`, plus `thirdpartylegalnotices-discord-rpc.txt` when distributing Discord RPC. Keep new contributions compatible with the SDK license and exclude GPL-like copyleft code.
