#[=======================================================================[.rst:
TorchlightHelpers
-----------------

Shared CMake helper functions for Torchlight modules.

Functions
^^^^^^^^^

.. command:: torchlight_add_module

  Define a Torchlight library module::

    torchlight_add_module(<Name>
        [PUBLIC_DEPENDS  <dep>...]
        [PRIVATE_DEPENDS <dep>...]
    )

  Expects the following layout::

    <name>/
      CMakeLists.txt          ← resolves own deps, calls torchlight_add_module()
                                 and torchlight_generate_headers()
      src/
        CMakeLists.txt        ← populates target sources via target_sources()
        *.h *.hpp *.cpp       ← all source + header files (flat or in subdirs)
      tests/
        CMakeLists.txt        ← test target (only added when TORCHLIGHT_BUILD_TESTS)

  The existing ``include/`` directories in the source tree are NOT used.
  Public headers are generated into the build tree by
  ``torchlight_generate_headers()``.

.. command:: torchlight_generate_headers

  Generate a Qt-style public include tree from source headers::

    torchlight_generate_headers(<target>
        MODULE_DIR <tModuleDir>
        HEADERS    <src_path>[=<pub_path>] ...
        ALIASES    <AliasName>=<header_path> ...
    )

  **HEADERS** entries:
    - Plain name (e.g. ``bimap.h``): copied from ``src/<name>`` into the
      module include root with the same basename.
    - ``src_path=pub_path`` (e.g. ``eigen/rotation.h=Eigen/rotation.h``):
      copies ``src/<src_path>`` to ``<MODULE_DIR>/<pub_path>``.

  **ALIASES** entries (always ``=``-separated):
    - ``Bimap=bimap.h`` creates a convenience header ``<MODULE_DIR>/Bimap``
      containing ``#include "bimap.h"``.
    - For subdirectories: ``Eigen/Types=Eigen/eigen_types.h``.

  Build tree:  forwarding ``#include`` pointing back to the source tree
               (no copy — changes are picked up immediately).
  Install tree: actual header content is copied (self-contained).

#]=======================================================================]

include_guard(GLOBAL)

include(GenerateExportHeader)

# Default install directory for CMake configs — can be overridden by the
# superbuild or by a standalone module build.
if(NOT DEFINED TORCHLIGHT_INSTALL_CMAKE_DIR)
    set(TORCHLIGHT_INSTALL_CMAKE_DIR
        "${CMAKE_INSTALL_LIBDIR}/cmake/Torchlight")
endif()

# ─── torchlight_add_module ────────────────────────────────────────────────────

function(torchlight_add_module _name)
    cmake_parse_arguments(PARSE_ARGV 1 _arg
        ""
        "MODULE_DIR"
        "PUBLIC_DEPENDS;PRIVATE_DEPENDS"
    )

    if(NOT _arg_MODULE_DIR)
        set(_arg_MODULE_DIR "t${_name}")
    endif()

    # ── Library target ───────────────────────────────────────────────────
    add_library(${_name})
    add_library(${TORCHLIGHT_NAMESPACE}::${_name} ALIAS ${_name})

    # Library output name: tCore, tMath, etc.
    # Auto-export all symbols on Windows until public APIs are annotated
    # with the generated export macro (e.g. Core_EXPORT).
    set_target_properties(${_name} PROPERTIES
        OUTPUT_NAME              "t${_name}"
        WINDOWS_EXPORT_ALL_SYMBOLS ON
    )

    # ── Sources (delegated to src/CMakeLists.txt) ────────────────────────
    add_subdirectory(src)

    # ── Include directories ──────────────────────────────────────────────
    # BUILD:   generated include tree in the build dir  (PUBLIC)
    # INSTALL: flat install prefix
    #
    # src/ is NOT added to -I.  Internal code uses <tModule/header.h>
    # through the generated forwarding headers, exactly like client code.
    # This avoids project headers (e.g. math.h) shadowing system headers.
    target_include_directories(${_name}
        PUBLIC
            $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    )

    # ── DLL export / import header (replaces hand-written *exports.h) ────
    #    Generates <tModule/module_export.h> in the build include tree.
    #    Consumers get the correct dllimport automatically.
    string(TOLOWER "${_name}" _lower)
    set(_export_header "${CMAKE_CURRENT_BINARY_DIR}/include/${_arg_MODULE_DIR}/${_lower}_export.h")
    generate_export_header(${_name}
        EXPORT_FILE_NAME  "${_export_header}"
        EXPORT_MACRO_NAME "${_name}_EXPORT"
    )

    # Install the generated export header alongside the other public headers
    install(FILES "${_export_header}"
        DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/${_arg_MODULE_DIR}"
    )

    # ── Link dependencies ────────────────────────────────────────────────
    if(_arg_PUBLIC_DEPENDS)
        target_link_libraries(${_name} PUBLIC ${_arg_PUBLIC_DEPENDS})
    endif()
    if(_arg_PRIVATE_DEPENDS)
        target_link_libraries(${_name} PRIVATE ${_arg_PRIVATE_DEPENDS})
    endif()

    # ── Install: target + export set ─────────────────────────────────────
    install(TARGETS ${_name}
        EXPORT ${_name}Targets
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    )

    install(EXPORT ${_name}Targets
        NAMESPACE ${TORCHLIGHT_NAMESPACE}::
        DESTINATION ${TORCHLIGHT_INSTALL_CMAKE_DIR}
    )

    # ── Tests ────────────────────────────────────────────────────────────
    if(TORCHLIGHT_BUILD_TESTS AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests")
        add_subdirectory(tests)
    endif()
endfunction()

# ─── torchlight_generate_headers ─────────────────────────────────────────────
#
# Generates two parallel include trees:
#
#   Build tree   (${CMAKE_CURRENT_BINARY_DIR}/include/<MODULE_DIR>/)
#     *.h / *.hpp   — thin forwarding headers (#include "../../src/real.h")
#     CamelCase     — alias (#include "header.h")
#
#   Install tree (${CMAKE_CURRENT_BINARY_DIR}/_install_headers/<MODULE_DIR>/)
#     *.h / *.hpp   — actual header content (configure_file COPYONLY)
#     CamelCase     — alias (#include "header.h")
#
# The install tree is what gets shipped via `cmake --install`.
# ─────────────────────────────────────────────────────────────────────────────

function(torchlight_generate_headers _target)
    cmake_parse_arguments(PARSE_ARGV 1 _arg
        ""
        "MODULE_DIR"
        "HEADERS;ALIASES"
    )

    set(_src_dir     "${CMAKE_CURRENT_SOURCE_DIR}/src")
    set(_build_inc   "${CMAKE_CURRENT_BINARY_DIR}/include/${_arg_MODULE_DIR}")
    set(_install_inc "${CMAKE_CURRENT_BINARY_DIR}/_install_headers/${_arg_MODULE_DIR}")

    # ── Process HEADERS ──────────────────────────────────────────────────
    foreach(_spec IN LISTS _arg_HEADERS)
        # "src_rel=pub_rel"  or  just "filename"
        if(_spec MATCHES "^([^=]+)=(.+)$")
            set(_src_rel "${CMAKE_MATCH_1}")
            set(_pub_rel "${CMAKE_MATCH_2}")
        else()
            set(_src_rel "${_spec}")
            get_filename_component(_pub_rel "${_spec}" NAME)
        endif()

        set(_src_file "${_src_dir}/${_src_rel}")

        # ── Build tree: forwarding #include ──────────────────────────
        set(_build_file "${_build_inc}/${_pub_rel}")
        get_filename_component(_build_parent "${_build_file}" DIRECTORY)
        file(RELATIVE_PATH _fwd "${_build_parent}" "${_src_file}")
        file(MAKE_DIRECTORY "${_build_parent}")
        file(WRITE "${_build_file}" "#include \"${_fwd}\"\n")

        # ── Install tree: copy actual content ────────────────────────
        set(_install_file "${_install_inc}/${_pub_rel}")
        get_filename_component(_install_parent "${_install_file}" DIRECTORY)
        file(MAKE_DIRECTORY "${_install_parent}")
        configure_file("${_src_file}" "${_install_file}" COPYONLY)
    endforeach()

    # ── Process ALIASES ──────────────────────────────────────────────────
    foreach(_spec IN LISTS _arg_ALIASES)
        if(NOT _spec MATCHES "^([^=]+)=(.+)$")
            message(FATAL_ERROR
                "torchlight_generate_headers: ALIAS must use "
                "'AliasName=header_path' format, got: ${_spec}")
        endif()
        set(_alias_rel  "${CMAKE_MATCH_1}")
        set(_header_rel "${CMAKE_MATCH_2}")

        # Compute the #include path from the alias to its target header.
        # If they share a directory, just use the filename; otherwise use
        # a relative path.
        get_filename_component(_alias_dir  "${_alias_rel}"  DIRECTORY)
        get_filename_component(_header_dir "${_header_rel}" DIRECTORY)

        if(_alias_dir STREQUAL _header_dir)
            get_filename_component(_inc_path "${_header_rel}" NAME)
        else()
            file(RELATIVE_PATH _inc_path
                "${_build_inc}/${_alias_dir}"
                "${_build_inc}/${_header_rel}")
        endif()

        set(_content "#include \"${_inc_path}\"\n")

        # Write alias into both trees (identical content).
        foreach(_base IN ITEMS "${_build_inc}" "${_install_inc}")
            set(_out "${_base}/${_alias_rel}")
            get_filename_component(_out_dir "${_out}" DIRECTORY)
            file(MAKE_DIRECTORY "${_out_dir}")
            file(WRITE "${_out}" "${_content}")
        endforeach()
    endforeach()

    # ── Install the self-contained tree ──────────────────────────────────
    install(DIRECTORY "${_install_inc}/"
        DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/${_arg_MODULE_DIR}"
    )
endfunction()

# ─── torchlight_install_module_config ────────────────────────────────────────
#
# Each module calls this to install its own <Module>Config.cmake alongside the
# top-level TorchlightConfig.cmake.  The top-level config discovers these by
# globbing, so the root CMakeLists.txt never mentions specific modules.
#
# Usage:
#   torchlight_install_module_config(<ModuleName>
#       CONFIG_FILE <path/to/ModuleConfig.cmake>
#   )
# ─────────────────────────────────────────────────────────────────────────────

function(torchlight_install_module_config _name)
    cmake_parse_arguments(PARSE_ARGV 1 _arg "" "CONFIG_FILE" "")

    if(NOT _arg_CONFIG_FILE)
        message(FATAL_ERROR "torchlight_install_module_config: CONFIG_FILE is required")
    endif()

    install(FILES "${_arg_CONFIG_FILE}"
        DESTINATION "${TORCHLIGHT_INSTALL_CMAKE_DIR}"
    )
endfunction()
