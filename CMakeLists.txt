# ══════════════════════════════════════════════════════════════════════════════
# Torchlight — Top-level Superbuild
# ══════════════════════════════════════════════════════════════════════════════

cmake_minimum_required(VERSION 3.24)

# Mark this as a superbuild so submodules can detect whether they are being
# built as part of the tree or standalone.
set(TORCHLIGHT_SUPERBUILD TRUE)

# The canonical project version lives in core/.cmake.conf
set(__tl_core_src_path "${CMAKE_CURRENT_SOURCE_DIR}/core")
include("${__tl_core_src_path}/.cmake.conf")

project(Torchlight
    VERSION     "${TORCHLIGHT_MODULE_VERSION}"
    DESCRIPTION "Multi-purpose calibration toolkit."
    LANGUAGES   CXX C
)

# Shared CMake modules
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Standard CMake modules
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)
# Shared helpers
include(TorchlightHelpers)
include(TorchlightTopLevelHelpers)
include(ECMOptionalAddSubdirectory)

# C++ standard
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Build options
option(BUILD_SHARED_LIBS      "Build shared libraries"  ON)
option(TORCHLIGHT_BUILD_TESTS "Build unit tests"        ON)

set(TORCHLIGHT_NAMESPACE "tl" CACHE STRING
    "CMake namespace for Torchlight targets")

# Install destination for all module cmake configs (shared across modules).
set(TORCHLIGHT_INSTALL_CMAKE_DIR
    "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}"
    CACHE PATH "Install dir for CMake package configs")

# Platform flags
if(MSVC)
    add_compile_definitions(_USE_MATH_DEFINES NOMINMAX)
    add_compile_options("$<$<NOT:$<CONFIG:Debug>>:/Zi>")
    add_link_options("$<$<NOT:$<CONFIG:Debug>>:/DEBUG;/OPT:REF;/OPT:ICF>")
endif()

# Test infrastructure
if(TORCHLIGHT_BUILD_TESTS)
    enable_testing()
    include(GoogleTest)
    include(TorchlightTestHelpers)
    find_package(GTest CONFIG REQUIRED)
endif()

# Bundled header-only libraries (always first)
add_subdirectory(externs)

# Discover and sort submodules
torchlight_find_modules(_tl_known_submodules)

# Allow the user or environment to select which submodules to build.
if(NOT TORCHLIGHT_BUILD_SUBMODULES)
    if(DEFINED ENV{TORCHLIGHT_BUILD_SUBMODULES})
        set(TORCHLIGHT_BUILD_SUBMODULES "$ENV{TORCHLIGHT_BUILD_SUBMODULES}")
    else()
        set(TORCHLIGHT_BUILD_SUBMODULES "${_tl_known_submodules}")
    endif()
endif()
set(TORCHLIGHT_BUILD_SUBMODULES "${TORCHLIGHT_BUILD_SUBMODULES}"
    CACHE STRING "Submodules to build")

# Validate that every requested module exists
foreach(_mod IN LISTS TORCHLIGHT_BUILD_SUBMODULES)
    if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_mod}/CMakeLists.txt")
        message(FATAL_ERROR
            "Submodule '${_mod}' not found.  Check spelling or ensure "
            "it has been checked out.")
    endif()
endforeach()

# Topological sort respecting .cmake.conf dependencies
torchlight_sort_module_dependencies(
    "${TORCHLIGHT_BUILD_SUBMODULES}" TORCHLIGHT_BUILD_SUBMODULES
)

# Check dependencies and configure submodules
foreach(_mod IN LISTS TORCHLIGHT_BUILD_SUBMODULES)
    # Check for unmet dependencies
    get_property(_deps GLOBAL PROPERTY TORCHLIGHT_DEPS_FOR_${_mod})
    foreach(_dep IN LISTS _deps)
        if(NOT _dep IN_LIST TORCHLIGHT_BUILD_SUBMODULES)
            if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_dep}/CMakeLists.txt")
                message(FATAL_ERROR
                    "Module '${_mod}' depends on '${_dep}', "
                    "but it was not found.  Use -DBUILD_${_mod}=OFF to skip.")
            endif()
            if(DEFINED BUILD_${_dep} AND NOT BUILD_${_dep})
                message(FATAL_ERROR
                    "Module '${_mod}' depends on '${_dep}', "
                    "but BUILD_${_dep} is OFF.  Use -DBUILD_${_mod}=OFF to skip.")
            endif()
        endif()
    endforeach()

    message(STATUS "Configuring submodule '${_mod}'")
    ecm_optional_add_subdirectory("${_mod}")
endforeach()

# Package configuration
configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/TorchlightConfig.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/TorchlightConfig.cmake"
    INSTALL_DESTINATION "${TORCHLIGHT_INSTALL_CMAKE_DIR}"
)

write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/TorchlightConfigVersion.cmake"
    COMPATIBILITY SameMajorVersion
)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/TorchlightConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/TorchlightConfigVersion.cmake"
    DESTINATION "${TORCHLIGHT_INSTALL_CMAKE_DIR}"
)
