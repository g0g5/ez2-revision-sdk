# Revision SDK integration

- Upstream: https://github.com/discord/discord-rpc
- Version: v3.4.0, commit `e6390c8c4190b59f1cc98bcec688e0037b84974d`.
- Source archive: https://codeload.github.com/discord/discord-rpc/tar.gz/refs/tags/v3.4.0
- Archive SHA-256: `e13427019027acd187352dacba6c65953af66fdf3c35fcf38fc40b454a9d7855`.
- Included unchanged: upstream runtime sources, public headers, LICENSE and README.md.
  Upstream build scripts, examples and bindings are omitted.

`cmake/DiscordRPC.cmake` builds a Windows x86 **shared** library with the upstream
I/O thread enabled. RapidJSON 1.1.0 headers are vendored alongside this directory;
configuration and compilation do not download either dependency. The adapter
avoids the old upstream CMake download and source-formatting steps.

The DLL uses the project's per-configuration static CRT and its own C++14 and
exception settings. `DISCORD_DYNAMIC_LIB` is propagated to clients;
`DISCORD_BUILDING_SDK` is private to the library. Its C interface is unchanged.
The existing copies of the public headers in `sp/src/public` match this version.

Each client publish target copies the matching DLL and linker PDB to its mod's
`bin/`, including incremental builds with no relink. The obsolete prebuilt
`sp/src/lib/public/discord-rpc.lib` is not used by this CMake build.

The library is deprecated upstream. Updates must pin and review both source
versions, preserve the DLL ABI, and retain the licenses. Redistribute
`thirdpartylegalnotices-discord-rpc.txt` from the repository root with binaries.
