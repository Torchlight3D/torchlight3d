# ECMOptionalAddSubdirectory
# --------------------------
# Adopted from KDE's Extra CMake Modules (ECM), used by Qt 6's superbuild.
#
# ::
#
#   ecm_optional_add_subdirectory(<dir>)
#
# Behaves like add_subdirectory(), but:
#   - Does nothing if the directory does not exist
#   - Creates a BUILD_<dir> cache option so users can skip individual modules
#   - Respects DISABLE_ALL_OPTIONAL_SUBDIRECTORIES to default everything off
#
# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2007 Alexander Neundorf <neundorf@kde.org>

function(ecm_optional_add_subdirectory _dir)
    get_filename_component(_full_path "${_dir}" ABSOLUTE)
    if(EXISTS "${_full_path}/CMakeLists.txt")
        if(DISABLE_ALL_OPTIONAL_SUBDIRECTORIES)
            set(_default_value FALSE)
        else()
            set(_default_value TRUE)
        endif()
        if(DISABLE_ALL_OPTIONAL_SUBDIRS AND NOT DEFINED BUILD_${_dir})
            set(_default_value FALSE)
        endif()
        option(BUILD_${_dir} "Build submodule ${_dir}" ${_default_value})
        if(BUILD_${_dir})
            add_subdirectory("${_dir}")
        endif()
    endif()
endfunction()
