include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/LuxShaders.cmake")

# Include is inert. Call revision_add_shaders(game) only for the shaders/everything
# selection: missing external tools deliberately fail that selection at configure
# time, without preventing a game/maptools-only configuration.
#
# Inputs: absolute REVISION_SRC / REVISION_ROOT, revision_target_defaults(target),
# revision_link_libraries(target ...). Sources and dependencies are explicit.
# Cache inputs: REVISION_SHADERCOMPILE_EXECUTABLE, Python3_EXECUTABLE.
# shadercompile.exe needs its matching SDK DLLs beside it.
#
# Targets: shaders (aggregate), shaders_<game>, game_shader_dx9_<game>,
# revision_shader_headers, revision_shader_bytecode (shared by all games).
# Add shaders / shaders_<game> to the caller's default/everything build as needed.
# EZ1/EZ2 use the same Mapbase material DLL and bytecode, just a different output
# directory; only HL2 and EPISODIC have stdshader outputs in this repository.

function(_revision_shader_pipeline game_dir)
    if(TARGET revision_shader_bytecode)
        return()
    endif()
    if(NOT WIN32 OR NOT MSVC OR NOT CMAKE_SIZEOF_VOID_P EQUAL 4)
        message(FATAL_ERROR "Revision shaders require Windows MSVC x86 (32-bit).")
    endif()
    foreach(_root IN ITEMS REVISION_SRC REVISION_ROOT)
        if(NOT IS_ABSOLUTE "${${_root}}")
            message(FATAL_ERROR "${_root} must be an absolute path for shader builds.")
        endif()
    endforeach()

    find_package(Python3 3.11 REQUIRED COMPONENTS Interpreter)
    set(_shader_dir "${REVISION_SRC}/materialsystem/stdshaders")
    set(_helper_dir "${CMAKE_CURRENT_FUNCTION_LIST_DIR}")
    set(_base "${CMAKE_CURRENT_BINARY_DIR}/revision-shaders")
    set(_finder "${_helper_dir}/FindShaderCompiler.py")
    set(_prep "${_helper_dir}/ShaderPrep.py")
    set(_runner "${_helper_dir}/RunShaderBuild.cmake")
    set(_local_config "${REVISION_ROOT}/.shader.env.local")
    # Reconfigure when the local override is created, edited, or removed.
    file(GLOB _local_config_entry CONFIGURE_DEPENDS "${_local_config}")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        "${_finder}" "${_prep}" ${_local_config_entry})
    set(REVISION_SHADERCOMPILE_EXECUTABLE "" CACHE FILEPATH
        "Optional override for the detected Valve shadercompile.exe")
    set(_sdk_dlls shadercompile_dll.dll tier0.dll vstdlib.dll filesystem_stdio.dll mysql_wrapper.dll)
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${_finder}"
            --config "${_local_config}" "--compiler=${REVISION_SHADERCOMPILE_EXECUTABLE}"
            --required-dlls ${_sdk_dlls}
        RESULT_VARIABLE _result OUTPUT_VARIABLE _compiler ERROR_VARIABLE _origin
        OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_STRIP_TRAILING_WHITESPACE ENCODING UTF-8)
    if(NOT _result STREQUAL "0")
        message(FATAL_ERROR "Shader compiler discovery failed (${_result}).\n${_origin}")
    endif()
    message(STATUS "Valve shader compiler: ${_compiler} (${_origin})")
    get_filename_component(_compiler_dir "${_compiler}" DIRECTORY)
    set(_sdk_runtime ${_sdk_dlls})
    list(TRANSFORM _sdk_runtime PREPEND "${_compiler_dir}/")

    # Broad input dependencies intentionally include all quoted HLSL includes,
    # including inactive preprocessor branches. New/removed files reconfigure.
    file(GLOB _inputs CONFIGURE_DEPENDS
        "${_shader_dir}/*.fxc" "${_shader_dir}/*.h"
        "${_shader_dir}/*.vsh" "${_shader_dir}/*.psh")
    set(_all_headers)
    set(_all_vcs)
    set(_all_stamps)
    foreach(_model IN ITEMS 20b 30)
        set(_project "stdshader_dx9_${_model}")
        set(_list "${_shader_dir}/${_project}.txt")
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_list}")
        execute_process(COMMAND "${Python3_EXECUTABLE}" "${_prep}" list "${_list}" "${_model}"
            RESULT_VARIABLE _result OUTPUT_VARIABLE _expanded ERROR_VARIABLE _error)
        if(NOT _result STREQUAL "0")
            message(FATAL_ERROR "Cannot expand ${_list} (${_result}): ${_error}")
        endif()
        string(REPLACE "\r" "" _expanded "${_expanded}")
        string(STRIP "${_expanded}" _expanded)
        string(REPLACE "\n" ";" _entries "${_expanded}")
        set(_work "${_base}/$<CONFIG>/${_model}")
        set(_headers)
        set(_vcs)
        set(_names)
        foreach(_entry IN LISTS _entries)
            string(REGEX REPLACE "^.*-----" "" _name "${_entry}")
            if(_name IN_LIST _names)
                message(FATAL_ERROR "Duplicate shader output ${_name} in ${_list}")
            endif()
            list(APPEND _names "${_name}")
            list(APPEND _headers "${_work}/fxctmp9/${_name}.inc")
            list(APPEND _vcs "${_work}/shaders/fxc/${_name}.vcs")
        endforeach()
        if(_model STREQUAL "30")
            set(_proxy "${REVISION_SRC}/dx10sdk/Utilities/dx9_30/dx_proxy.dll")
            set(_dx_version pc09.30)
            set(_dx_dll "${REVISION_SRC}/devtools/bin/d3dx9_33.dll")
        else()
            set(_proxy "${REVISION_SRC}/dx9sdk/utilities/dx_proxy.dll")
            set(_dx_version pc09.00)
            set(_dx_dll "")
        endif()
        set(_runtime "${_compiler}" ${_sdk_runtime} "${_proxy}")
        if(_dx_dll)
            list(APPEND _runtime "${_dx_dll}")
        endif()
        foreach(_file IN LISTS _runtime)
            if(NOT EXISTS "${_file}")
                message(FATAL_ERROR "Missing shader compiler dependency: ${_file}")
            endif()
        endforeach()
        set(_manifest "${_base}/${_project}.cmake")
        # Bracket quoting keeps Windows paths, spaces and semicolon lists intact.
        set(_content "")
        foreach(_var IN ITEMS Python3_EXECUTABLE _prep _compiler _list _model
                _inputs _names _runtime _dx_version game_dir)
            string(APPEND _content "set(${_var} [==[${${_var}}]==])\n")
        endforeach()
        file(CONFIGURE OUTPUT "${_manifest}" CONTENT "${_content}" @ONLY)
        set(_stamp "${_work}/prepared.stamp")
        add_custom_command(OUTPUT "${_stamp}" ${_headers}
            BYPRODUCTS "${_work}/filelist.txt" "${_work}/uniquefilestocopy.txt"
            COMMAND "${CMAKE_COMMAND}" "-DMANIFEST=${_manifest}" "-DWORK_DIR=${_work}"
                -DMODE=PREPARE -P "${_runner}"
            DEPENDS ${_inputs} "${_list}" "${_prep}" "${_runner}" "${_manifest}"
            COMMENT "Generate shader combo headers and ${_model} worklist"
            VERBATIM)
        add_custom_command(OUTPUT ${_vcs}
            COMMAND "${CMAKE_COMMAND}" "-DMANIFEST=${_manifest}" "-DWORK_DIR=${_work}"
                -DMODE=COMPILE -P "${_runner}"
            # Each Valve invocation uses the available cores. Run models in sequence.
            DEPENDS "${_stamp}" ${_headers} ${_runtime} "${game_dir}/gameinfo.txt"
                ${_all_vcs} "${_manifest}" "${_runner}"
            COMMENT "Compile Valve shader bytecode (model ${_model})"
            VERBATIM)
        list(APPEND _all_stamps "${_stamp}")
        list(APPEND _all_headers ${_headers})
        list(APPEND _all_vcs ${_vcs})
    endforeach()
    add_custom_target(revision_shader_headers DEPENDS ${_all_stamps} ${_all_headers})
    add_custom_target(revision_shader_bytecode DEPENDS ${_all_vcs})
    add_dependencies(revision_shader_bytecode revision_shader_headers)
    set_property(GLOBAL PROPERTY REVISION_SHADER_GENERATED_BASE "${_base}")
    set_property(GLOBAL PROPERTY REVISION_SHADER_VCS_FILES "${_all_vcs}")
endfunction()

function(revision_add_shaders game)
    string(TOLOWER "${game}" _game)
    if(NOT _game MATCHES "^(hl2|episodic|ez1|ez2)$")
        message(FATAL_ERROR "revision_add_shaders: unsupported game '${game}'.")
    endif()
    if(TARGET shaders_${_game})
        return()
    endif()
    if(_game STREQUAL "ez2")
        revision_add_lux_shaders()
        return()
    endif()
    set(_game_dir "${REVISION_ROOT}/sp/game/mod_${_game}")
    if(NOT EXISTS "${_game_dir}/gameinfo.txt")
        message(FATAL_ERROR "Shader compilation needs ${_game_dir}/gameinfo.txt")
    endif()
    _revision_shader_pipeline("${_game_dir}")
    get_property(_base GLOBAL PROPERTY REVISION_SHADER_GENERATED_BASE)
    get_property(_vcs GLOBAL PROPERTY REVISION_SHADER_VCS_FILES)
    set(_shader_dir "${REVISION_SRC}/materialsystem/stdshaders")
    # Explicit native source set from game_shader_dx9_base + Mapbase v8.0.
    set(_sources
        BaseVSShader.cpp example_model_dx9.cpp example_model_dx9_helper.cpp
        Bloom.cpp screenspace_general.cpp
        cloak_blended_pass_helper.cpp emissive_scroll_blended_pass_helper.cpp
        flesh_interior_blended_pass_helper.cpp lightmappedgeneric_dx9.cpp
        lightmappedgeneric_dx9_helper.cpp lightmappedreflective.cpp skin_dx9_helper.cpp
        unlitgeneric_dx9.cpp vertexlitgeneric_dx9.cpp vertexlitgeneric_dx9_helper.cpp
        worldtwotextureblend.cpp worldvertextransition.cpp worldvertextransition_dx8_helper.cpp
        refract.cpp refract_dx9_helper.cpp water.cpp depthwrite.cpp splinerope.cpp
        eyes_dx9.cpp eyes_dx8_dx9_helper.cpp eyeball.cpp eyeglint_dx9.cpp
        eye_refract.cpp eye_refract_helper.cpp teeth.cpp sprite_dx9.cpp
        decalmodulate_dx9.cpp unlittwotexture_dx9.cpp MonitorScreen_dx9.cpp
        shatteredglass.cpp windowimposter_dx90.cpp engine_post_dx9.cpp
        depthoffield_dx9.cpp core_dx9.cpp)
    list(TRANSFORM _sources PREPEND "${_shader_dir}/")
    set(_target game_shader_dx9_${_game})
    add_library(${_target} SHARED EXCLUDE_FROM_ALL ${_sources}
        "${REVISION_SRC}/public/tier0/memoverride.cpp")
    revision_target_defaults(${_target} COPY_PDB)
    target_include_directories(${_target} BEFORE PRIVATE
        "${_base}/$<CONFIG>/20b/fxctmp9" "${_base}/$<CONFIG>/30/fxctmp9"
        "${_shader_dir}" "${_shader_dir}/fxctmp9" "${_shader_dir}/vshtmp9")
    target_compile_definitions(${_target} PRIVATE
        WIN32 _WIN32 _WINDOWS _USRDLL COMPILER_MSVC COMPILER_MSVC32
        _CRT_SECURE_NO_DEPRECATE _CRT_NONSTDC_NO_DEPRECATE
        _ALLOW_RUNTIME_LIBRARY_MISMATCH _ALLOW_ITERATOR_DEBUG_LEVEL_MISMATCH
        _ALLOW_MSC_VER_MISMATCH _DLL_EXT=.dll RAD_TELEMETRY_DISABLED
        DEV_BUILD FRAME_POINTER_OMISSION_DISABLED
        MAPBASE PARALLAX_CORRECTED_CUBEMAPS
        STDSHADER_DX9_DLL_EXPORT FAST_MATERIALVAR_ACCESS USE_ACTUAL_DX
        DLLNAME=game_shader_dx9)
    revision_link_libraries(${_target} mathlib shaderlib tier1 tier0 vstdlib)
    target_link_libraries(${_target} PRIVATE version winmm)
    set_target_properties(${_target} PROPERTIES PREFIX "" OUTPUT_NAME game_shader_dx9
        RUNTIME_OUTPUT_DIRECTORY "${_game_dir}/bin"
        ARCHIVE_OUTPUT_DIRECTORY "${_base}/$<CONFIG>/lib/${_game}")
    # Never race C++ compilation against generated .inc files. Legacy/example
    # inc files not in the FXC collections intentionally fall back to the
    # committed fxctmp9/vshtmp9 directories; regenerated files take precedence.
    add_dependencies(${_target} revision_shader_headers)
    revision_publish_shaders(${_game} "${_game_dir}" ${_vcs})
endfunction()

function(revision_publish_shaders _game _game_dir)
    set(_published)
    set(_linked_binary)
    if(TARGET game_shader_dx9_${_game}_binary)
        set(_linked_binary game_shader_dx9_${_game}_binary)
    endif()
    foreach(_file IN LISTS ARGN)
        get_filename_component(_name "${_file}" NAME)
        set(_output "${_game_dir}/shaders/fxc/${_name}")
        add_custom_command(OUTPUT "${_output}"
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${_game_dir}/shaders/fxc"
            COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_file}" "${_output}"
            DEPENDS "${_file}" ${_linked_binary} VERBATIM)
        list(APPEND _published "${_output}")
    endforeach()
    add_custom_target(shader_bytecode_${_game} DEPENDS ${_published})
    add_custom_target(shaders_${_game})
    add_dependencies(shaders_${_game} game_shader_dx9_${_game} shader_bytecode_${_game})
    if(NOT TARGET shaders)
        add_custom_target(shaders)
    endif()
    add_dependencies(shaders shaders_${_game})
endfunction()
