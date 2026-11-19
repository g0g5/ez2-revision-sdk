include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/SDKLibraries.cmake")

# Rebuilt SDK targets take precedence over local and cached prebuilt libraries.
function(revision_link_libraries target)
    foreach(lib IN LISTS ARGN)
        if(TARGET "${lib}")
            target_link_libraries(${target} PRIVATE "${lib}")
        elseif(EXISTS "${REVISION_SRC}/lib/public/${lib}.lib")
            target_link_libraries(${target} PRIVATE "${REVISION_SRC}/lib/public/${lib}.lib")
        elseif(EXISTS "${REVISION_SRC}/lib/common/${lib}.lib")
            target_link_libraries(${target} PRIVATE "${REVISION_SRC}/lib/common/${lib}.lib")
        elseif(DEFINED revision_prebuilt_${lib})
            revision_fetch_sdk_library("${lib}" library)
            target_link_libraries(${target} PRIVATE "${library}")
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
        $<$<CONFIG:Release,Publish>:NDEBUG>)
    target_compile_options(${target} PRIVATE
        "$<$<COMPILE_LANGUAGE:C,CXX>:/W4;/GF;/Gy;/fp:fast;/arch:SSE2;/Zc:forScope;/Zc:threadSafeInit-;/wd4316;/wd4838;/wd4456;/wd4457;/wd4458;/wd4459>"
        "$<$<AND:$<COMPILE_LANGUAGE:C,CXX>,$<NOT:$<CONFIG:Publish>>>:/Z7>"
        "$<$<COMPILE_LANGUAGE:CXX>:/GR>"
        "$<$<AND:$<COMPILE_LANGUAGE:C,CXX>,$<CONFIG:Release,Publish>>:/O2;/Ob2;/Oi;/Ot;/Oy->")
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
        target_link_options(${target} PRIVATE $<$<NOT:$<CONFIG:Publish>>:/DEBUG> /SAFESEH:NO /INCREMENTAL:NO
            /NODEFAULTLIB:libc /NODEFAULTLIB:libcd
            "$<IF:$<CONFIG:Debug>,/NODEFAULTLIB:libcmt,/NODEFAULTLIB:libcmtd>"
            "$<$<CONFIG:Release,Publish>:/OPT:REF;/OPT:NOICF>")
    endif()
    if(ARGV1 STREQUAL "COPY_PDB" AND NOT CMAKE_BUILD_TYPE STREQUAL "Publish")
        add_custom_command(TARGET ${target} POST_BUILD
            COMMAND "${CMAKE_COMMAND}" -E copy_if_different "$<TARGET_PDB_FILE:${target}>" "$<TARGET_FILE_DIR:${target}>"
            VERBATIM)
    endif()
endfunction()

function(revision_add_target name type)
    set(target "${name}")
    if(ARGC GREATER 2)
        set(target "${ARGV2}")
    endif()
    set(revision_sources)
    set(revision_definitions)
    set(revision_includes)
    set(revision_libraries)
    set(revision_no_pch)
    include("${REVISION_ROOT}/cmake/targets/${name}.cmake")
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

function(revision_add_runtime_target name type destination)
    cmake_parse_arguments(PARSE_ARGV 3 runtime "" "OUTPUT_NAME" "RUNTIME_DEPENDENCIES")
    if(NOT DEFINED runtime_OUTPUT_NAME)
        set(runtime_OUTPUT_NAME "${name}")
    endif()
    set(binary "${name}_binary")
    set(staging "${CMAKE_CURRENT_BINARY_DIR}/bin/${name}")
    revision_add_target(${name} ${type} ${binary})
    set_target_properties(${binary} PROPERTIES
        OUTPUT_NAME "${runtime_OUTPUT_NAME}"
        ARCHIVE_OUTPUT_NAME "${name}"
        DEFINE_SYMBOL "${name}_EXPORTS"
        RUNTIME_OUTPUT_DIRECTORY "${staging}"
        PDB_OUTPUT_DIRECTORY "${staging}"
        PDB_NAME "${runtime_OUTPUT_NAME}")
    if(NOT CMAKE_BUILD_TYPE STREQUAL "Publish")
        # Declare the linker's PDB so Ninja can regenerate it if it is missing.
        add_custom_command(TARGET ${binary} POST_BUILD
            BYPRODUCTS "${staging}/${runtime_OUTPUT_NAME}.pdb"
            COMMAND "${CMAKE_COMMAND}" -E true
            VERBATIM)
    endif()
    # Publish dependencies even when Ninja reuses the linked client. A POST_BUILD
    # copy on the dependency alone would miss other mods and deleted output files.
    set(publish_dependencies)
    foreach(dependency IN LISTS runtime_RUNTIME_DEPENDENCIES)
        list(APPEND publish_dependencies
            COMMAND "${CMAKE_COMMAND}"
                "-DBINARY=$<TARGET_FILE:${dependency}>"
                "-DPDB=$<$<NOT:$<CONFIG:Publish>>:$<TARGET_PDB_FILE:${dependency}>>"
                "-DDESTINATION=${destination}"
                "-DLOCK=${REVISION_ROOT}/build/publish-locks/${name}-${dependency}.lock"
                -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/PublishRuntime.cmake")
    endforeach()
    # Each requested build publishes its artifacts, including an incremental no-op link.
    add_custom_target(${name}
        ${publish_dependencies}
        COMMAND "${CMAKE_COMMAND}"
            "-DBINARY=$<TARGET_FILE:${binary}>"
            "-DPDB=$<$<NOT:$<CONFIG:Publish>>:$<TARGET_PDB_FILE:${binary}>>"
            "-DDESTINATION=${destination}" "-DLOCK=${REVISION_ROOT}/build/publish-locks/${name}.lock"
            -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/PublishRuntime.cmake"
        DEPENDS ${binary} ${runtime_RUNTIME_DEPENDENCIES}
        COMMENT "Publish ${name} (${CMAKE_BUILD_TYPE})"
        VERBATIM)
endfunction()
