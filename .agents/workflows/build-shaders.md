# Build shaders

Use the compiler for the selected game and keep the EZ2 shader DLL and bytecode paired with the client build.

- Shader builds require Python 3.11 or later. EZ2 uses LUX's `ShaderCompile2.exe`, which CMake can download from a pinned revision and verify.
- HL2, Episodic, and EZ1 use Valve's `shadercompile.exe` and the matching Source SDK Base 2013 Singleplayer runtime DLLs. See [the build guide](../../docs/building.md#shaders-optional) for compiler setup.
- Use EZ2's client and shader DLLs from the same build with the matching `shaders/fxc/` bytecode.
