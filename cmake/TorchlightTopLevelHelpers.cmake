#[=======================================================================[.rst:
TorchlightTopLevelHelpers
-------------------------

Superbuild helper functions for Torchlight top-level CMakeLists.txt.
Modelled after Qt 6's ``cmake/QtTopLevelHelpers.cmake``.

Functions
^^^^^^^^^

.. command:: torchlight_find_modules

  Discover submodule directories in the source tree::

    torchlight_find_modules(<out_var>)

  Populates ``<out_var>`` with a list of directory names that contain both
  a ``CMakeLists.txt`` and a ``.cmake.conf`` file.  Directories that are
  not Torchlight modules (cmake, doc, ref, etc.) are excluded.

.. command:: torchlight_sort_module_dependencies

  Topologically sort modules according to their declared dependencies::

    torchlight_sort_module_dependencies(<module_list> <out_sorted>
        [SKIP_MODULES <mod>...]
    )

  Reads each module's ``.cmake.conf`` to obtain ``TORCHLIGHT_MODULE_DEPS``,
  then performs a topological sort so that every module is built after all
  its dependencies.  Sets global properties
  ``TORCHLIGHT_DEPS_FOR_<module>`` for later use.

#]=======================================================================]

include_guard(GLOBAL)

# ── Directories to exclude from module discovery ─────────────────────────────
set(_TL_NON_MODULE_DIRS
    cmake doc ref scripts tools ros applications plugins qtmodules
    externs .git .github .vscode build install
)

# ─── torchlight_find_modules ─────────────────────────────────────────────────
function(torchlight_find_modules out_module_list)
    set(_modules "")
    file(GLOB _entries LIST_DIRECTORIES true
         RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" *)
    foreach(_entry IN LISTS _entries)
        # Skip known non-module directories
        if(_entry IN_LIST _TL_NON_MODULE_DIRS)
            continue()
        endif()
        # Must be a directory with both CMakeLists.txt and .cmake.conf
        set(_dir "${CMAKE_CURRENT_SOURCE_DIR}/${_entry}")
        if(IS_DIRECTORY "${_dir}"
           AND EXISTS "${_dir}/CMakeLists.txt"
           AND EXISTS "${_dir}/.cmake.conf")
            list(APPEND _modules "${_entry}")
        endif()
    endforeach()
    message(DEBUG "torchlight_find_modules: ${_modules}")
    set(${out_module_list} "${_modules}" PARENT_SCOPE)
endfunction()

# ─── torchlight_sort_module_dependencies ─────────────────────────────────────
#
# Topological sort (Kahn's algorithm) of modules according to .cmake.conf deps.
#
# Sets global properties:
#   TORCHLIGHT_DEPS_FOR_<module>  — direct dependencies of <module>
# ─────────────────────────────────────────────────────────────────────────────
function(torchlight_sort_module_dependencies _modules_in _out_sorted)
    cmake_parse_arguments(_arg "" "" "SKIP_MODULES" ${ARGN})

    # ── Phase 1: Collect dependency info ─────────────────────────────────
    foreach(_mod IN LISTS _modules_in)
        set(TORCHLIGHT_MODULE_DEPS "")
        include("${CMAKE_CURRENT_SOURCE_DIR}/${_mod}/.cmake.conf")
        set(_deps_${_mod} "${TORCHLIGHT_MODULE_DEPS}")
        set_property(GLOBAL PROPERTY TORCHLIGHT_DEPS_FOR_${_mod}
                     "${TORCHLIGHT_MODULE_DEPS}")
    endforeach()

    # ── Phase 2: Build in-degree map ─────────────────────────────────────
    foreach(_mod IN LISTS _modules_in)
        set(_in_degree_${_mod} 0)
    endforeach()
    foreach(_mod IN LISTS _modules_in)
        foreach(_dep IN LISTS _deps_${_mod})
            if(_dep IN_LIST _modules_in AND NOT _dep IN_LIST _arg_SKIP_MODULES)
                math(EXPR _in_degree_${_mod} "${_in_degree_${_mod}} + 1")
            endif()
        endforeach()
    endforeach()

    # ── Phase 3: Kahn's algorithm ────────────────────────────────────────
    set(_queue "")
    foreach(_mod IN LISTS _modules_in)
        if(_in_degree_${_mod} EQUAL 0)
            list(APPEND _queue "${_mod}")
        endif()
    endforeach()
    # Sort the initial queue for deterministic ordering
    list(SORT _queue)

    set(_sorted "")
    while(_queue)
        list(POP_FRONT _queue _current)
        list(APPEND _sorted "${_current}")

        # Reduce in-degree for modules that depend on _current
        foreach(_mod IN LISTS _modules_in)
            if(_mod IN_LIST _sorted)
                continue()
            endif()
            if(_current IN_LIST _deps_${_mod})
                math(EXPR _in_degree_${_mod} "${_in_degree_${_mod}} - 1")
                if(_in_degree_${_mod} EQUAL 0)
                    list(APPEND _queue "${_mod}")
                    # Keep queue sorted for determinism
                    list(SORT _queue)
                endif()
            endif()
        endforeach()
    endwhile()

    # Sanity check: all modules should be in _sorted
    list(LENGTH _sorted _sorted_len)
    list(LENGTH _modules_in _input_len)
    if(NOT _sorted_len EQUAL _input_len)
        message(FATAL_ERROR
            "torchlight_sort_module_dependencies: Cyclic dependency detected!\n"
            "  Input:  ${_modules_in}\n"
            "  Sorted: ${_sorted}")
    endif()

    set(${_out_sorted} "${_sorted}" PARENT_SCOPE)
endfunction()
