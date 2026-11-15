# Explicit source inventory and target-specific settings. Edit this file when adding sources.
set(revision_sources
    "${REVISION_SRC}/public/tier0/pointeroverride.asm"
    "${REVISION_SRC}/utils/height2normal/height2normal.cpp"
)

set(revision_definitions
    "_HAS_ITERATOR_DEBUGGING=0"
    "_WIN32"
    "_CONSOLE"
    "_ALLOW_RUNTIME_LIBRARY_MISMATCH"
    "_ALLOW_ITERATOR_DEBUG_LEVEL_MISMATCH"
    "_ALLOW_MSC_VER_MISMATCH"
)

set(revision_includes
    "${REVISION_SRC}/common"
    "${REVISION_SRC}/public"
    "${REVISION_SRC}/public/tier0"
    "${REVISION_SRC}/public/tier1"
    "${REVISION_SRC}/utils/common"
)

set(revision_libraries
    "tier0"
    "tier1"
    "vstdlib"
    "bitmap"
    "mathlib"
    "tier2"
    "shell32"
    "user32"
    "advapi32"
    "gdi32"
    "comdlg32"
    "ole32"
)
