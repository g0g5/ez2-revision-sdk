include_guard(GLOBAL)

# Include is inert. Call revision_add_shaders(game) only for the shaders/everything
# selection: missing external tools deliberately fail that selection at configure
# time, without preventing a game/maptools-only configuration.
#
# Inputs: absolute REVISION_SRC / REVISION_ROOT, revision_target_defaults(target),
# revision_link_libraries(target ...). Sources and dependencies are explicit.
# Cache inputs: REVISION_SHADERCOMPILE_EXECUTABLE, REVISION_SHADER_PERL_EXECUTABLE.
# Native Windows Perl is required: Git/MSYS/Cygwin Perl rewrites Valve's Windows
# paths while fxc_prep.pl runs. shadercompile.exe needs its matching DLLs beside it.
#
# Targets: shaders (aggregate), shaders_<game>, game_shader_dx9_<game>,
# revision_shader_headers, revision_shader_bytecode (shared by all games).
# Add shaders / shaders_<game> to the caller's default/everything build as needed.
# EZ1/EZ2 use the same Mapbase material DLL and bytecode, just a different output
# directory; only HL2 and EPISODIC have stdshader outputs in this repository.

function(_revision_shader_tools)
    if(NOT WIN32 OR NOT MSVC OR NOT CMAKE_SIZEOF_VOID_P EQUAL 4)
        message(FATAL_ERROR "Revision shaders require Windows MSVC x86 (32-bit).")
    endif()
    foreach(_root IN ITEMS REVISION_SRC REVISION_ROOT)
        if(NOT IS_ABSOLUTE "${${_root}}")
            message(FATAL_ERROR "${_root} must be an absolute path for shader builds.")
        endif()
    endforeach()

    set(REVISION_SHADERCOMPILE_EXECUTABLE "" CACHE FILEPATH
        "Valve shadercompile.exe from Source SDK Base 2013 Singleplayer/bin")
    if(NOT REVISION_SHADERCOMPILE_EXECUTABLE)
        find_program(_revision_shadercompile NAMES shadercompile.exe
            HINTS "$ENV{SDKBINDIR}")
        if(_revision_shadercompile)
            set(REVISION_SHADERCOMPILE_EXECUTABLE "${_revision_shadercompile}"
                CACHE FILEPATH "Valve shadercompile.exe" FORCE)
        endif()
    endif()
    if(NOT EXISTS "${REVISION_SHADERCOMPILE_EXECUTABLE}" OR
            IS_DIRECTORY "${REVISION_SHADERCOMPILE_EXECUTABLE}")
        message(FATAL_ERROR
            "The shaders/everything selection requires Valve shadercompile.exe, "
            "which is NOT shipped in this repository. Set "
            "-DREVISION_SHADERCOMPILE_EXECUTABLE=C:/path/to/SDK/bin/shadercompile.exe "
            "and keep its matching engine DLLs beside it.")
    endif()
    get_filename_component(_bin "${REVISION_SHADERCOMPILE_EXECUTABLE}" DIRECTORY)
    foreach(_dll IN ITEMS shadercompile_dll.dll tier0.dll vstdlib.dll)
        if(NOT EXISTS "${_bin}/${_dll}")
            message(FATAL_ERROR
                "Shader compiler runtime is incomplete: ${_bin}/${_dll} is missing. "
                "Use the matching Source SDK Base 2013 Singleplayer bin directory.")
        endif()
    endforeach()

    set(REVISION_SHADER_PERL_EXECUTABLE "" CACHE FILEPATH
        "Native Windows Perl used to generate shader combo headers and worklists")
    if(NOT REVISION_SHADER_PERL_EXECUTABLE)
        if(PERL_EXECUTABLE)
            set(_perl "${PERL_EXECUTABLE}")
        else()
            find_program(_revision_shader_perl NAMES perl.exe perl)
            set(_perl "${_revision_shader_perl}")
        endif()
        if(_perl)
            set(REVISION_SHADER_PERL_EXECUTABLE "${_perl}" CACHE FILEPATH
                "Windows-compatible Perl for shaders" FORCE)
        endif()
    endif()
    if(NOT EXISTS "${REVISION_SHADER_PERL_EXECUTABLE}" OR
            IS_DIRECTORY "${REVISION_SHADER_PERL_EXECUTABLE}")
        message(FATAL_ERROR
            "The shaders/everything selection requires Perl. Set "
            "-DREVISION_SHADER_PERL_EXECUTABLE=C:/path/to/perl.exe "
            "to native Windows Perl (for example Strawberry Perl).")
    endif()
    execute_process(COMMAND "${REVISION_SHADER_PERL_EXECUTABLE}" -e "print $^O"
        RESULT_VARIABLE _result OUTPUT_VARIABLE _os ERROR_VARIABLE _error)
    if(NOT _result EQUAL 0 OR NOT _os STREQUAL "MSWin32")
        message(FATAL_ERROR
            "Shaders need native Windows Perl (MSWin32), not Git/MSYS/Cygwin Perl. "
            "REVISION_SHADER_PERL_EXECUTABLE=${REVISION_SHADER_PERL_EXECUTABLE}; "
            "reported platform '${_os}'; ${_error}")
    endif()
    # fxc_prep.pl does not need String::CRC32; the historical checksum and ASM
    # paths are not part of this pipeline.
    execute_process(COMMAND "${REVISION_SHADER_PERL_EXECUTABLE}" -c
            "${REVISION_SRC}/devtools/bin/fxc_prep.pl"
        RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _error)
    if(NOT _result EQUAL 0)
        message(FATAL_ERROR "Shader Perl prerequisites failed: ${_out}${_error}")
    endif()
endfunction()

function(_revision_shader_pipeline game_dir)
    if(TARGET revision_shader_bytecode)
        return()
    endif()
    _revision_shader_tools()
    set(_shader_dir "${REVISION_SRC}/materialsystem/stdshaders")
    set(_helper_dir "${CMAKE_CURRENT_FUNCTION_LIST_DIR}")
    set(_base "${CMAKE_CURRENT_BINARY_DIR}/revision-shaders")
    # Broad input dependencies intentionally include all quoted HLSL includes,
    # including inactive preprocessor branches. New/removed files reconfigure.
    file(GLOB _inputs CONFIGURE_DEPENDS
        "${_shader_dir}/*.fxc" "${_shader_dir}/*.h"
        "${_shader_dir}/*.vsh" "${_shader_dir}/*.psh")
    set(_scripts "${_helper_dir}/ShaderPrep.pl" "${_helper_dir}/RunShaderBuild.cmake"
        "${REVISION_SRC}/devtools/bin/fxc_prep.pl"
        "${REVISION_SRC}/devtools/bin/valve_perl_helpers.pl")
    set(_all_headers)
    set(_all_vcs)
    set(_all_stamps)
    foreach(_model IN ITEMS 20b 30)
        set(_project "stdshader_dx9_${_model}")
        set(_list "${_shader_dir}/${_project}.txt")
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_list}" ${_scripts})
        # Use Valve's expansion rules, rather than maintaining a second parser:
        # ps2x -> ps20+ps20b, vsxx -> vs11+vs20, and forced ps/vs30.
        execute_process(COMMAND "${REVISION_SHADER_PERL_EXECUTABLE}"
                "${_helper_dir}/ShaderPrep.pl" list "${REVISION_SRC}" "${_project}" "${_model}"
            WORKING_DIRECTORY "${_shader_dir}" RESULT_VARIABLE _result
            OUTPUT_VARIABLE _expanded ERROR_VARIABLE _error)
        if(NOT _result EQUAL 0)
            message(FATAL_ERROR "Cannot expand ${_list}: ${_error}")
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
            set(_proxy "${REVISION_SRC}/dx10sdk/utilities/dx9_30/dx_proxy.dll")
            set(_dx_version pc09.30)
            set(_dx_dll "${REVISION_SRC}/devtools/bin/d3dx9_33.dll")
        else()
            set(_proxy "${REVISION_SRC}/dx9sdk/utilities/dx_proxy.dll")
            set(_dx_version pc09.00)
            set(_dx_dll "")
        endif()
        get_filename_component(_compiler_dir "${REVISION_SHADERCOMPILE_EXECUTABLE}" DIRECTORY)
        set(_runtime "${REVISION_SHADERCOMPILE_EXECUTABLE}"
            "${_compiler_dir}/shadercompile_dll.dll" "${_compiler_dir}/tier0.dll"
            "${_compiler_dir}/vstdlib.dll" "${_proxy}")
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
        foreach(_var IN ITEMS REVISION_SRC REVISION_SHADER_PERL_EXECUTABLE
                REVISION_SHADERCOMPILE_EXECUTABLE _shader_dir _project _model
                _inputs _names _runtime _dx_version game_dir)
            string(APPEND _content "set(${_var} [==[${${_var}}]==])\n")
        endforeach()
        file(CONFIGURE OUTPUT "${_manifest}" CONTENT "${_content}" @ONLY)
        set(_stamp "${_work}/prepared.stamp")
        add_custom_command(OUTPUT "${_stamp}" ${_headers}
            BYPRODUCTS "${_work}/filelist.txt" "${_work}/uniquefilestocopy.txt"
            COMMAND "${CMAKE_COMMAND}" "-DMANIFEST=${_manifest}" "-DWORK_DIR=${_work}"
                -DMODE=PREPARE -P "${_helper_dir}/RunShaderBuild.cmake"
            DEPENDS ${_inputs} "${_list}" ${_scripts} "${_manifest}" ${_runtime}
            COMMENT "Generate shader combo headers and ${_model} worklist"
            VERBATIM)
        add_custom_command(OUTPUT ${_vcs}
            COMMAND "${CMAKE_COMMAND}" "-DMANIFEST=${_manifest}" "-DWORK_DIR=${_work}"
                -DMODE=COMPILE -P "${_helper_dir}/RunShaderBuild.cmake"
            # The Valve compiler can use shared scratch space in its bin
            # directory. Serialize model 30 after 20b; prep stages remain parallel.
            DEPENDS "${_stamp}" ${_headers} ${_runtime} "${game_dir}/gameinfo.txt"
                ${_all_vcs} "${_manifest}" "${_helper_dir}/RunShaderBuild.cmake"
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
    set(_game_dir "${REVISION_ROOT}/sp/game/mod_${_game}")
    # EZ2's content directory is not committed. The common bytecode compiler can
    # use either committed Mapbase gameinfo; publishing still targets mod_ez2.
    set(_compiler_game "${_game_dir}")
    if(NOT EXISTS "${_compiler_game}/gameinfo.txt")
        set(_compiler_game "${REVISION_ROOT}/sp/game/mod_hl2")
    endif()
    if(NOT EXISTS "${_compiler_game}/gameinfo.txt")
        message(FATAL_ERROR "Shader compilation needs ${_compiler_game}/gameinfo.txt")
    endif()
    _revision_shader_pipeline("${_compiler_game}")
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
    set(_published)
    foreach(_file IN LISTS _vcs)
        get_filename_component(_name "${_file}" NAME)
        set(_output "${_game_dir}/shaders/fxc/${_name}")
        add_custom_command(OUTPUT "${_output}"
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${_game_dir}/shaders/fxc"
            COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_file}" "${_output}"
            DEPENDS "${_file}" VERBATIM)
        list(APPEND _published "${_output}")
    endforeach()
    add_custom_target(shaders_${_game} DEPENDS ${_published})
    add_dependencies(shaders_${_game} ${_target} revision_shader_bytecode)
    if(NOT TARGET shaders)
        add_custom_target(shaders)
    endif()
    add_dependencies(shaders shaders_${_game})
endfunction()
