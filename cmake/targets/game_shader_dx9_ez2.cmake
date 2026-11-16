set(lux_dir "${REVISION_SRC}/materialsystem/lux")
set(revision_sources
    shaderlib/ProxyShaderAPI.cpp
    shaderlib/ProxyShaderShadow.cpp
    shaderlib/ShaderSpew.cpp
    shaderlib/VCSHotReload.cpp
    shaderlib/baseshader.cpp
    shaderlib/shaderdll.cpp
    shaderlib/shaderlib_cvar.cpp
    stdshaders/BaseVSShader.cpp
    stdshaders/cpp_convars.cpp
    stdshaders/cpp_floatx.cpp
    stdshaders/shadersource/Bloom.cpp
    stdshaders/shadersource/BlurFilters.cpp
    stdshaders/shadersource/Cable.cpp
    stdshaders/shadersource/Cloud.cpp
    stdshaders/shadersource/Core.cpp
    stdshaders/shadersource/CustomShader.cpp
    stdshaders/shadersource/DebugLuxels.cpp
    stdshaders/shadersource/DebugStubs.cpp
    stdshaders/shadersource/DebugTextureView.cpp
    stdshaders/shadersource/DecalModulate.cpp
    stdshaders/shadersource/EnginePost.cpp
    stdshaders/shadersource/EyeRefract.cpp
    stdshaders/shadersource/LightmappedGeneric.cpp
    stdshaders/shadersource/LightmappedGeneric_Decal.cpp
    stdshaders/shadersource/LightmappedReflective.cpp
    stdshaders/shadersource/Modulate.cpp
    stdshaders/shadersource/Refract.cpp
    stdshaders/shadersource/RevisionFallbacks.cpp
    stdshaders/shadersource/Screenspace_General.cpp
    stdshaders/shadersource/ShatteredGlass.cpp
    stdshaders/shadersource/Sky_Complex.cpp
    stdshaders/shadersource/Sky_Equirectangular.cpp
    stdshaders/shadersource/Sky_Simple.cpp
    stdshaders/shadersource/Sprite.cpp
    stdshaders/shadersource/Spritecard.cpp
    stdshaders/shadersource/Teeth.cpp
    stdshaders/shadersource/UnlitGeneric.cpp
    stdshaders/shadersource/UnlitTwoTexture.cpp
    stdshaders/shadersource/VertexLitGeneric.cpp
    stdshaders/shadersource/Water.cpp
    stdshaders/shadersource/WorldVertexTransition.cpp
    stdshaders/shadersource/distancealpha/DistanceAlpha_Brush.cpp
    stdshaders/shadersource/distancealpha/DistanceAlpha_Model.cpp
    stdshaders/shadersource/distancealpha/DistanceAlpha_Unlit.cpp
    stdshaders/shadersource/recreations/Black.cpp
    stdshaders/shadersource/recreations/Infected.cpp
    stdshaders/shadersource/renderpasses/Cloak.cpp
    stdshaders/shadersource/renderpasses/EmissiveBlend.cpp
    stdshaders/shadersource/renderpasses/FleshInterior.cpp
    stdshaders/shadersource/renderpasses/MeshOutline.cpp
    stdshaders/shadersource/renderpasses/RimLightPass.cpp
    stdshaders/shadersource/renderpasses/SSAODrawNormalPass.cpp
    stdshaders/shadersource/renderpasses/SheenPass.cpp
    stdshaders/shadersource/triplanar/Triplanar_brush.cpp
    stdshaders/shadersource/triplanar/Triplanar_displacement.cpp
    stdshaders/shadersource/triplanar/Triplanar_model.cpp)
list(TRANSFORM revision_sources PREPEND "${lux_dir}/")
set(compat_sources depthwrite.cpp eyeglint_dx9.cpp MonitorScreen_dx9.cpp
    windowimposter_dx90.cpp worldtwotextureblend.cpp)
list(TRANSFORM compat_sources PREPEND "${REVISION_SRC}/materialsystem/stdshaders/")
list(APPEND revision_sources ${compat_sources} "${REVISION_SRC}/public/tier0/memoverride.cpp")

set(revision_includes "${lux_dir}" "${lux_dir}/shaderlib" "${lux_dir}/stdshaders")
set(revision_definitions
    WIN32 _WIN32 _WINDOWS _USRDLL COMPILER_MSVC COMPILER_MSVC32
    _CRT_SECURE_NO_DEPRECATE _CRT_NONSTDC_NO_DEPRECATE
    _ALLOW_RUNTIME_LIBRARY_MISMATCH _ALLOW_ITERATOR_DEBUG_LEVEL_MISMATCH
    _ALLOW_MSC_VER_MISMATCH _DLL_EXT=.dll RAD_TELEMETRY_DISABLED
    DEV_BUILD FRAME_POINTER_OMISSION_DISABLED
    MAPBASE PARALLAX_CORRECTED_CUBEMAPS REVISION_LUX
    STDSHADER_DX9_DLL_EXPORT FAST_MATERIALVAR_ACCESS GAME_SHADER_DLL USE_ACTUAL_DX
    DLLNAME=game_shader_dx9)
set(revision_libraries mathlib tier2 tier1 tier0 vstdlib version winmm)
