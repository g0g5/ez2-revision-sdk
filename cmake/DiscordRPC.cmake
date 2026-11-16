include_guard(GLOBAL)

# Build the pinned runtime sources without the legacy upstream CMake download
# and clang-format steps. Keep its C++14/exception settings out of the game DLLs.
function(revision_add_discord_rpc)
    include("${REVISION_ROOT}/cmake/targets/discord-rpc.cmake")
    add_library(discord-rpc SHARED EXCLUDE_FROM_ALL ${revision_sources})
    target_include_directories(discord-rpc
        PUBLIC "${REVISION_SRC}/thirdparty/discord-rpc/include"
        PRIVATE "${REVISION_SRC}/thirdparty/rapidjson/include")
    target_compile_definitions(discord-rpc
        PUBLIC DISCORD_DYNAMIC_LIB
        PRIVATE DISCORD_WINDOWS DISCORD_BUILDING_SDK
            $<$<CONFIG:Debug>:_HAS_ITERATOR_DEBUGGING=0>)
    target_compile_options(discord-rpc PRIVATE /EHsc /W3 $<$<CONFIG:Release>:/Z7>)
    target_link_libraries(discord-rpc PRIVATE psapi advapi32)
    target_link_options(discord-rpc PRIVATE /DEBUG /INCREMENTAL:NO)
    set(staging "${CMAKE_BINARY_DIR}/bin/discord-rpc")
    set_target_properties(discord-rpc PROPERTIES
        CXX_STANDARD 14
        CXX_STANDARD_REQUIRED YES
        CXX_EXTENSIONS NO
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        RUNTIME_OUTPUT_DIRECTORY "${staging}"
        PDB_OUTPUT_DIRECTORY "${staging}"
        PDB_NAME discord-rpc)
    add_custom_command(TARGET discord-rpc POST_BUILD
        BYPRODUCTS "${staging}/discord-rpc.pdb"
        COMMAND "${CMAKE_COMMAND}" -E true
        VERBATIM)
endfunction()

revision_add_discord_rpc()
