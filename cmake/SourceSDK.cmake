include_guard(GLOBAL)

# Source-built SDK libraries take precedence over the vendored engine import libraries.
function(revision_link_libraries target)
    foreach(lib IN LISTS ARGN)
        if(TARGET "${lib}")
            target_link_libraries(${target} PRIVATE "${lib}")
        elseif(EXISTS "${REVISION_SRC}/lib/public/${lib}.lib")
            target_link_libraries(${target} PRIVATE "${REVISION_SRC}/lib/public/${lib}.lib")
        elseif(EXISTS "${REVISION_SRC}/lib/common/${lib}.lib")
            target_link_libraries(${target} PRIVATE "${REVISION_SRC}/lib/common/${lib}.lib")
        else()
            target_link_libraries(${target} PRIVATE "${lib}.lib")
        endif()
    endforeach()
endfunction()

function(revision_target_defaults target)
    target_include_directories(${target} PRIVATE "${REVISION_SRC}/common" "${REVISION_SRC}/public"
        "${REVISION_SRC}/public/tier0" "${REVISION_SRC}/public/tier1")
    target_compile_definitions(${target} PRIVATE
        $<$<CONFIG:Debug>:_DEBUG;DEBUG;_HAS_ITERATOR_DEBUGGING=0>
        $<$<CONFIG:Release>:NDEBUG>)
    target_compile_options(${target} PRIVATE
        "$<$<COMPILE_LANGUAGE:C,CXX>:/W4;/Z7;/GF;/Gy;/fp:fast;/arch:SSE2;/Zc:forScope;/Zc:threadSafeInit-;/wd4316;/wd4838;/wd4456;/wd4457;/wd4458;/wd4459>"
        "$<$<COMPILE_LANGUAGE:CXX>:/GR>"
        "$<$<AND:$<COMPILE_LANGUAGE:C,CXX>,$<CONFIG:Release>>:/O2;/Ob2;/Oi;/Ot;/Oy->")
    if(REVISION_WARNINGS_AS_ERRORS)
        target_compile_options(${target} PRIVATE "$<$<COMPILE_LANGUAGE:C,CXX>:/WX>")
    endif()
    set_target_properties(${target} PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        ARCHIVE_OUTPUT_NAME "${target}"
        RUNTIME_OUTPUT_DIRECTORY "${REVISION_ROOT}/sp/game/bin"
        PDB_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/pdb/${target}")
    get_target_property(type ${target} TYPE)
    if(NOT type STREQUAL "STATIC_LIBRARY")
        target_link_options(${target} PRIVATE /DEBUG /SAFESEH:NO /INCREMENTAL:NO
            /NODEFAULTLIB:libc /NODEFAULTLIB:libcd
            "$<IF:$<CONFIG:Debug>,/NODEFAULTLIB:libcmt,/NODEFAULTLIB:libcmtd>"
            "$<$<CONFIG:Release>:/OPT:REF;/OPT:ICF>")
        # Runtime DLLs and their linker PDBs stay together, as in the SDK output layout.
        add_custom_command(TARGET ${target} POST_BUILD
            COMMAND "${CMAKE_COMMAND}" -E copy_if_different "$<TARGET_PDB_FILE:${target}>" "$<TARGET_FILE_DIR:${target}>"
            VERBATIM)
    endif()
endfunction()

function(revision_add_target target type)
    set(revision_sources)
    set(revision_definitions)
    set(revision_includes)
    set(revision_libraries)
    set(revision_no_pch)
    include("${REVISION_ROOT}/cmake/targets/${target}.cmake")
    if(type STREQUAL "EXECUTABLE")
        add_executable(${target} EXCLUDE_FROM_ALL ${revision_sources})
    else()
        add_library(${target} ${type} EXCLUDE_FROM_ALL ${revision_sources})
    endif()
    # Configuration and Steamworks version are controlled centrally, not frozen in inventories.
    list(REMOVE_ITEM revision_definitions NDEBUG)
    list(FILTER revision_definitions EXCLUDE REGEX "^STEAMWORKS_VERSION=")
    list(APPEND revision_definitions "STEAMWORKS_VERSION=${REVISION_STEAMWORKS_VERSION}")
    target_compile_definitions(${target} PRIVATE ${revision_definitions})
    target_include_directories(${target} PRIVATE ${revision_includes})
    foreach(source IN LISTS revision_sources)
        if(source MATCHES "\\.c$")
            set_source_files_properties("${source}" PROPERTIES LANGUAGE CXX)
        endif()
    endforeach()
    # This translation unit undefines the SDK's CRT guards before its first include.
    # CMake's forced PCH include would run before those directives.
    if(target MATCHES "^server_")
        list(APPEND revision_no_pch "${REVISION_SRC}/game/server/ai_behavior_lead.cpp")
    endif()
    if(revision_no_pch)
        set_source_files_properties(${revision_no_pch} PROPERTIES SKIP_PRECOMPILE_HEADERS ON)
    endif()
    revision_target_defaults(${target})
    revision_link_libraries(${target} ${revision_libraries})
endfunction()
