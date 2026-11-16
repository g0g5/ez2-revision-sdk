
# SOURCE 2013 EXPANDED STEAM

https://github.com/Blixibon/source-2013-expanded-steam

---

This integrates a newer version of the Steam API for Source SDK Base 2013 Singleplayer, providing access to modern Steam features. It also comes with its own integration of Steam Deck and Steam Input support, complete with button icons being displayed on HUD hints.

Currently, directly upgrading the Steam API requires replacing `steam_api.dll` in the engine's `bin` folder. This is easy if you are responsible for a standalone Steam mod with its own engine binaries, but that isn't conventionally possible for regular mods based on stock Source SDK Base 2013.

This project comes with an optional hack which uses DLL redirection to force the client/server DLLs to integrate a `steam_api.dll` adjacent to them in the mod's own `bin` folder rather than the engine's `bin` folder. However, this sometimes conflicts with the Steam API implemented by the rest of the engine and modules like Steam Input may not work correctly. There's also not an equivalent solution for native Linux.

The instructions below assume a standalone Steam app on Windows. Build from the repository root with PowerShell 7 and `./build.ps1`; see [the build guide](building.md) for the Windows x86 toolchain requirements. The default build is EZ2 Release. `REVISION_BUILD_EXPANDED_STEAM` defaults to `OFF` (use the vendored library rather than rebuilding it), and `REVISION_STEAMWORKS_VERSION` defaults to `1261`.

---

## Instructions for integrating Expanded Steam

Follow these instructions if you just want to integrate Steam Input and Steam Deck support into your mod.

### Updating steam_api.dll

First, obtain the Steamworks SDK version matching the headers and import library your build uses. Assuming you are a Steamworks partner, this will be available through the partner.steamgames.com dashboard.

In the downloaded zip file, go to `redistributable_bin` and extract `steam_api.dll`. Move this file to your app's engine bin folder (i.e. `steamapps/common/my_steam_mod/bin`) and replace the existing `steam_api.dll`.

### Integrating Steam Input

*This step will assume you are a Steamworks partner with your own standalone app. It's not currently possible to follow this step if you are building a regular mod.*

If you just want to integrate the same controls as Half-Life 2, you will need to copy the `steamapps/common/Half-Life 2/steam_input` folder to your Steam mod's top-level folder. Then, in your app's Steamworks settings, set the Steam Input Default Configuration to "Custom Configuration (Bundled with game)" and specify the path as `steam_input\action_manifest_hl2.vdf`. You can rename `action_manifest_hl2` if you would like.

You can modify these controller configs and add custom button actions if you need to. Please see [the official Steam Input documentation on the Steamworks website](https://partner.steamgames.com/doc/features/steam_controller) for more information on how this can be done. If you add any new actions, you will need to add them to `scripts/steaminput_actionbinds.txt` to let Expanded Steam bind them to console commands.

### Integrating Expanded Steam

Expanded Steam has three branches available:

- **`master`** - Includes Expanded Steam + Steam Deck and Steam Input support.
- **`mapbase`** - Integrates Expanded Steam with [Mapbase](https://github.com/mapbase-source/source-sdk-2013)-specific features. For example, letting button icons appear on the Game Instructor/`env_instructor_hint`. You should use this branch if your mod is using Mapbase.
- **`updated-sdk-only`** - Integrates compatibility for building the code with updated Steam API headers and *nothing* else.

Merge the branch of your choice using Git. If you are not using any custom code, use the `2013-sp` binaries provided in the latest release. If you are using stock Mapbase code, use the `mapbase-sp` binaries provided in the latest release.

If you are aiming to integrate Steam Input and Steam Deck support, download the scripts and resources provided in the latest release. Merge all of these files with your mod's content.

The files related to Steam Input itself should work out of the box. However, for Steam Deck support, you will need to go into your `resource/clientscheme.res` file and add this to the bottom of it:

```
#base "clientscheme_steaminput.res"
```

This will mount certain Deck-specific fonts. If you have made your own modifications to `clientscheme.res`, you may need to adapt them here.

You will also need to integrate the following files from Half-Life 2 or its episodes:

- `scripts/hudlayout.res`
- `scripts/hudanimations.txt`

These files contain Deck-specific HUD changes which Expanded Steam will recognize.

#### Other Steam Input notes

* If you are using custom weapons, you will need to specify `bucket_360` and `bucket_position_360` keyvalues in their scripts for the "directional" weapon selection screen used by controllers.
* If you are using custom HUD hints which mention directional movement keys (i.e. +forward, etc.), you will need to have joystick counterparts. Expanded Steam can automatically remap HUD hint text keys based on the user's controller scheme. See `scripts/steaminput_hintremap.txt` for examples of how it does this with stock HL2 hints. You can integrate new hints through a separate file called `scripts/mod_hintremap.txt`.

---

That should be everything you need to do in order to integrate Expanded Steam and its features. If you experience any issues, please open an issue on the repository's GitHub page.

---

## Instructions for modifying Expanded Steam

Follow these instructions if you want to modify Expanded Steam's source code. This assumes you have already upgraded `steam_api.dll` as per the instructions above.

### Updating Steam API headers

Use Steamworks headers, the x86 `steam_api.lib` import library, and the x86 runtime `steam_api.dll` from a matching SDK version. Headers go in `sp/src/public/steam`; the import library goes in `sp/src/lib/public`. The runtime DLL belongs in your app's engine `bin` directory as described above. Keep these components compatible with the Expanded Steam sources and library you build or use.

Updated Steamworks headers may be subject to the Steamworks SDK Access Agreement. **Avoid committing restricted SDK files when sharing your fork.**

### Building with CMake

The root CMake cache controls the integration:

- `REVISION_BUILD_EXPANDED_STEAM=OFF` (default) links the prebuilt `expanded_steam.lib` into the game client. CMake uses a local library at `sp/src/lib/public/expanded_steam.lib` if supplied. For the default Steamworks version it can also retrieve the pinned library described in the [build guide](building.md#windows-x86-sdk-libraries). Set the option to `ON` to build Expanded Steam from source with matching Steamworks headers.
- `REVISION_STEAMWORKS_VERSION=1261` (default) is the integer header-version selector used by the source. Set it to the version expected by the headers you provide; changing this number does not download or update any SDK files.

Run in PowerShell 7 from the repository root, after preparing the matching SDK files:

```powershell
./build.ps1 -Game EZ2 -Configuration Release -CMakeArguments '-DREVISION_BUILD_EXPANDED_STEAM=ON', '-DREVISION_STEAMWORKS_VERSION=1261'
```

Use `-Game EZ2,EZ1` or `-Game All` to select multiple games. Runtime game DLLs are placed in `sp/game/mod_<game>/bin`; rebuilt static libraries and intermediate files stay in the build directory. The native Expanded Steam source inventory is `cmake/targets/expanded_steam.cmake`; update it when adding or removing sources.

The default configuration with the vendored library has been built for EZ2 Release and Debug. Rebuilding Expanded Steam from source with a different SDK requires its own build and runtime validation.

---

That should be everything you need to do in order to add Expanded Steam to your project.

---

## FAQ

### Can I leave Expanded Steam in my code even if I don't currently have an upgraded Steam API?

The updated Steam API import library requires a compatible runtime `steam_api.dll`. With `REVISION_BUILD_EXPANDED_STEAM=OFF`, the game client links the prebuilt Expanded Steam library. Keep the headers, import libraries and runtime DLLs compatible and test the integration in your app.

### Does this support [Gamepad UI?](https://github.com/Joshua-Ashton/HL2-GamepadUI)

I am planning to open my own branch for Gamepad UI which integrates Expanded Steam in the near-future.
