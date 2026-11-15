# Explicit source inventory and target-specific settings. Edit this file when adding sources.
set(revision_sources
    "${REVISION_SRC}/public/tier0/memoverride.cpp"
    "${REVISION_SRC}/public/tier0/pointeroverride.asm"
    "${REVISION_SRC}/utils/vtf2tga/vtf2tga.cpp"
)

set(revision_no_pch
    "${REVISION_SRC}/public/tier0/memoverride.cpp"
)

set(revision_definitions
    "RAD_TELEMETRY_DISABLED"
    "MAPBASE"
    "GAMEPADUI"
    "STEAMWORKS_VERSION=1261"
    "STEAM_INPUT"
    "WIN32"
    "_WIN32"
    "NDEBUG"
    "_WINDOWS"
    "_CRT_SECURE_NO_DEPRECATE"
    "_CRT_NONSTDC_NO_DEPRECATE"
    "_ALLOW_RUNTIME_LIBRARY_MISMATCH"
    "_ALLOW_ITERATOR_DEBUG_LEVEL_MISMATCH"
    "_ALLOW_MSC_VER_MISMATCH"
    "COMPILER_MSVC32"
    "COMPILER_MSVC"
    "EXENAME=vtf2tga"
    "_DLL_EXT=.dll"
    "DEV_BUILD"
    "FRAME_POINTER_OMISSION_DISABLED"
)

set(revision_includes
    "${REVISION_SRC}/common"
    "${REVISION_SRC}/public"
    "${REVISION_SRC}/public/tier0"
    "${REVISION_SRC}/public/tier1"
)

set(revision_libraries
    "tier0"
    "tier1"
    "vstdlib"
    "bitmap"
    "mathlib"
    "tier2"
    "vtf"
    "shell32"
    "user32"
    "advapi32"
    "gdi32"
    "comdlg32"
    "ole32"
)
