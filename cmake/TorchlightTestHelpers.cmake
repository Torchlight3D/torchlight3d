# ── torchlight_add_test ──────────────────────────────────────────────────────
#
# Helper function to configure test executables with proper runtime environment.
# Automatically sets up PATH/LD_LIBRARY_PATH for DLL discovery and enables
# GoogleTest discovery.
#
# Usage:
#   torchlight_add_test(<target>
#       SOURCES <file>...
#       LINK_LIBRARIES <lib>...
#   )
# ─────────────────────────────────────────────────────────────────────────────

function(torchlight_add_test target_name)
    cmake_parse_arguments(PARSE_ARGV 1 _arg
        ""
        ""
        "SOURCES;LINK_LIBRARIES"
    )

    add_executable(${target_name})
    
    if(_arg_SOURCES)
        target_sources(${target_name} PRIVATE ${_arg_SOURCES})
    endif()
    
    if(_arg_LINK_LIBRARIES)
        target_link_libraries(${target_name} PRIVATE ${_arg_LINK_LIBRARIES})
    endif()

    # ── Runtime DLL path setup for Windows ───────────────────────────────
    if(WIN32)
        # Collect all runtime directories needed for test execution
        set(_runtime_paths "")
        
        # Add module binary directories
        list(APPEND _runtime_paths
            "${CMAKE_BINARY_DIR}/core"
            "${CMAKE_BINARY_DIR}/math"
            "${CMAKE_BINARY_DIR}/motion"
            "${CMAKE_BINARY_DIR}/vision"
        )
        
        # Add vcpkg runtime directory
        if(VCPKG_INSTALLED_DIR)
            list(APPEND _runtime_paths
                "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/bin"
            )
        endif()
        
        # Add FetchContent/ExternalProject binary directories
        if(EXISTS "${CMAKE_BINARY_DIR}/_deps")
            file(GLOB _dep_build_dirs LIST_DIRECTORIES true
                 "${CMAKE_BINARY_DIR}/_deps/*-build")
            list(APPEND _runtime_paths ${_dep_build_dirs})
        endif()
        
        # Convert to CMake paths (forward slashes) and build a PATH string
        set(_native_paths "")
        foreach(_p IN LISTS _runtime_paths)
            file(TO_CMAKE_PATH "${_p}" _cmake_p)
            list(APPEND _native_paths "${_cmake_p}")
        endforeach()
        list(JOIN _native_paths ";" _path_string)
        set(_env_path "${_path_string};C:/Windows/System32")
        string(REPLACE ";" "\\;" _env_path_escaped "${_env_path}")

        # Use a test executor so both discovery and execution see the same PATH
        set_property(TARGET ${target_name} PROPERTY CROSSCOMPILING_EMULATOR
            "${CMAKE_COMMAND}"
            "-E"
            "env"
            "PATH=${_env_path_escaped}"
        )

        cmake_policy(PUSH)
        cmake_policy(SET CMP0178 NEW)
        gtest_discover_tests(${target_name}
            DISCOVERY_TIMEOUT 30
        )
        cmake_policy(POP)
    else()
        # GoogleTest discovery without custom environment
        cmake_policy(PUSH)
        cmake_policy(SET CMP0178 NEW)
        gtest_discover_tests(${target_name}
            DISCOVERY_TIMEOUT 30
        )
        cmake_policy(POP)
    endif()
endfunction()
