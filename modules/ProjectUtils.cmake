# Set of utilities for compact and concise specification of program components
# in a large project.

include(GNUInstallDirs)
include(CMakeParseArguments)

include(ParseArgsIncremental)
include(PathUtils)
include(StringUtils)

set(_project_utils_cur_dir "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL
    "Current list dir for project utils modeule.")
set(_dep_discovery_hacks "${_project_utils_cur_dir}/res/DepDiscoveryHacks.cmake")
include("${_dep_discovery_hacks}")

# Various macros for simplifying writing CMake files for projects consisting of
# multiple related subprojects ("components") with wide abilities for
# configuration for distribution-specific packaging purposes.
#
# These macros enable writing of CMakeLists meeting the following requirements:
#  * Project consists of multiple sub-projects, each can be built separately.
#  * Each sub-project allows separate building, installation and packaging.
#  * Each sub-project needs doxygen documentation, pkg config and cmake config
#    to be generated
#  * Each sub-project needs ability to configure installation paths for each
#    kind of produced files (executable, library, resource, documentation...).

set(_project_utils_default_template_dir
    "${_project_utils_cur_dir}/../templates/"
    CACHE INTERNAL "Path to default template configuration files")

set(CMAKE_GENERAL_CONFIG_FORCE_OUT_OF_SOURCE_BUILD 1
    CACHE BOOL "Whether to force out of source build")
set(CMAKE_GENERAL_CONFIG_DEFAULT_BUILD_TYPE Release
    CACHE STRING "Default build type for general_config(), options are: '' 'Debug' 'Release' 'RelWithDebInfo' 'MinSizeRel'.")
set(CMAKE_GENERAL_CONFIG_NAME "general"
    CACHE STRING "Default configuration project name")

set(_general_config_opts "FORCE_OUT_OF_SOURCE_BUILD" "DEFAULT_BUILD_TYPE" "NAME"
    "PREFIX"
    CACHE INTERNAL "List of general_config() option names.")
foreach (_var ${_general_config_opts})
    mark_as_advanced(CMAKE_GENERAL_CONFIG_${_var})
endforeach ()

# List of configurable directories. It is important that "AR" is after "LIB" and
# "DOC" is after "RES" since latter defaults to former.
set(_general_config_dirs
    "LIB" "AR" "BIN" "RES" "DOC" "INCLUDE" "CMAKE" "PKGCONFIG" "MAN"
    CACHE INTERNAL "List of directories configured by general_config()/add_component().")

set(CMAKE_ADD_COMPONENT_DEFAULT_BIN_LIB "BIN"
    CACHE INTERNAL "Path to custom pkg-config configuration file.")
set(CMAKE_ADD_COMPONENT_STATIC 1
    CACHE BOOL "Whether to perform static build of a library.")
set(CMAKE_ADD_COMPONENT_SHARED 1
    CACHE BOOL "Whether to perform build of a shared library.")
set(CMAKE_ADD_COMPONENT_TARGET_PREFIX ""
    CACHE STRING "Target name prefix.")
set(CMAKE_ADD_COMPONENT_TARGET_SUFFIX ""
    CACHE STRING "Target name suffix.")
set(CMAKE_ADD_COMPONENT_STATIC_TARGET_SUFFIX "_static"
    CACHE STRING "Static library target name suffix.")
set(CMAKE_ADD_COMPONENT_DOXYGEN 1
    CACHE BOOL "Whether to perform generation of doxygen documentation.")
set(CMAKE_ADD_COMPONENT_DOXYGEN_TARGET_SUFFIX "_doc"
    CACHE BOOL "Doxygen target suffix.")
set(CMAKE_ADD_COMPONENT_DOXYGEN_FORMATS MAN HTML
    CACHE STRING "Whether to perform generation of doxygen documentation.")
set(CMAKE_ADD_COMPONENT_GEN_CMAKE_CONFIG 1
    CACHE BOOL "Whether to perform generation/installation of CMake configuration file for libraries.")
set(CMAKE_ADD_COMPONENT_CMAKE_CONFIG_PATH
    "${_project_utils_default_template_dir}/component-config.cmake.in"
    CACHE STRING "Path to custom pkg-config configuration file.")
set(CMAKE_ADD_COMPONENT_GEN_PKG_CONFIG 1
    CACHE BOOL "Whether to perform generation/installation of pkg-configconfiguration file for libraries.")
set(CMAKE_ADD_COMPONENT_PKG_CONFIG_PATH
    "${_project_utils_default_template_dir}/component.pc.in"
    CACHE STRING "Path to custom pkg-config configuration file.")

set(_add_component_opts "STATIC" "SHARED" "DOXYGEN" "DOXYGEN_TARGET_NAME"
    "DOXYGEN_TARGET_PREFIX" "DOXYGEN_TARGET_SUFFIX" "GEN_CMAKE_CONFIG"
    "CMAKE_CONFIG_PATH" "GEN_PKG_CONFIG" "PKG_CONFIG_PATH" "TARGET_NAME"
    "STATIC_TARGET_NAME" "SHARED_TARGET_NAME" "TARGET_PREFIX" "TARGET_SUFFIX"
    "STATIC_TARGET_SUFFIX" "SHARED_TARGET_SUFFIX" "OUTPUT_NAME")
foreach (_var ${_add_component_opts})
    mark_as_advanced(CMAKE_ADD_COMPONENT_${_var})
endforeach ()

function (to_varpart _str _out)
    string(TOUPPER "${_str}" _res)
    string(REPLACE "-" "_" _res "${_res}")

    set("${_out}" "${_res}" PARENT_SCOPE)
endfunction ()

# update_config_dir(<output var> <dir name> [PROJECT <project_name>]
#   [[PROJECT_DEFAULT] <List of default variable names>]
#   [GENERAL_DEFAULT <list of general variable names>])
#
# List of dir names is maintained in _general_config_dirs variable.
function (update_config_dir _var _dir)
    set(_res)

	set(_Options)
	set(_OneValueArgs "PROJECT")
	set(_MultiValueArgs "PROJECT_DEFAULT" "GENERAL_DEFAULT")
	cmake_parse_arguments(UCD
        "${_Options}" "${_OneValueArgs}" "${_MultiValueArgs}" ${ARGN})

    foreach (_default ${_var} ${UCD_PROJECT_DEFAULT} ${UCD_UNPARSED_ARGUMENTS})
        if (DEFINED "${_default}")
            set("${_var}" "${${_default}}" PARENT_SCOPE)

            return()
        endif ()
    endforeach ()

    foreach (_default ${_var} ${UCD_GENERAL_DEFAULT})
        if (DEFINED "${_default}")
            set(_res "${${_default}}")

            break()
        endif ()
    endforeach ()

    if ("${_res}" STREQUAL "")
        # Hard-coded defaults
        if (_dir STREQUAL "LIB")
            if (DEFINED CMAKE_INSTALL_LIBDIR)
                set(_res "${CMAKE_INSTALL_LIBDIR}")
            elseif (DEFINED LIB_INSTALL_DIR)
                set(_res "${LIB_INSTALL_DIR}")
            else ()
                set(_res "lib${LIB_SUFFIX}")
            endif ()
        elseif (_dir STREQUAL "AR")
            set(_res "${CMAKE_INSTALL_LIBDIR}")
        elseif (_dir STREQUAL "BIN")
            set(_res "${CMAKE_INSTALL_BINDIR}")
        elseif (_dir STREQUAL "RES")
            if (DEFINED SHARE_INSTALL_PREFIX)
                set(_res "${SHARE_INSTALL_PREFIX}")
            else ()
                set(_res "${CMAKE_INSTALL_DATADIR}")
            endif ()
        elseif (_dir STREQUAL "DOC")
            set(_res "${CMAKE_INSTALL_DATAROOTDIR}/doc")
        elseif (_dir STREQUAL "INCLUDE")
            if (DEFINED INCLUDE_INSTALL_DIR)
                set(_res "${INCLUDE_INSTALL_DIR}")
            else ()
                set(_res "${CMAKE_INSTALL_INCLUDEDIR}")
            endif ()
        elseif (_dir STREQUAL "CMAKE")
            # Installation of actual cmake files is usually done in
            # <share_dir>/<package>/cmake, so only share prefix here
            set(_res "${CMAKE_INSTALL_DATAROOTDIR}")
        elseif (_dir STREQUAL "PKGCONFIG")
            set(_res "${CMAKE_INSTALL_LIBDIR}/pkgconfig")
        elseif (_dir STREQUAL "MAN")
            set(_res "${CMAKE_INSTALL_MANDIR}")
        endif ()
    endif ()

    # Post-processing for per-project defaults
    if (DEFINED UCD_PROJECT)
        if (_dir STREQUAL "RES")
            set(_res "${_res}/${UCD_PROJECT}")
        elseif (_dir STREQUAL "DOC")
            set(_res "${_res}/${UCD_PROJECT}")
        elseif (_dir STREQUAL "INCLUDE")
            set(_res "${_res}/${UCD_PROJECT}")
        elseif (_dir STREQUAL "CMAKE")
            set(_res "${_res}/${UCD_PROJECT}/cmake")
        endif ()
    endif ()

    set("${_var}" "${_res}" PARENT_SCOPE)
endfunction ()

# general_config(
#   DEFS_VARS <list of defs variables>)
#   LINK_FLAGS_VARS <list of CFLAGS variables>
#   FORCE_OUT_OF_SOURCE_BUILD 0/1
#   {LIB|AR|BIN|RES|DOC|INCLUDE|CMAKE|PKGCONFIG|MAN} <default path>
#
# Handles root configuration of installation paths and sets list of variables
# which should be used by projects added with add_project()
#
# PREFIX controls which cache variables subcomponents should use
# (it is set in GENERAL_PROJECT_PREFIX variable in parent scope).
function (general_config)
	set(_Options)
	set(_OneValueArgs ${_general_config_opts})
	set(_MultiValueArgs "SUBDIRS" "CFLAGS_VARS" "DEFS_VARS")
	cmake_parse_arguments(GENCFG
        "${_Options}" "${_OneValueArgs}" "${_MultiValueArgs}" ${ARGN})

    # Setting options defaults
    foreach (_opt ${_general_config_opts})
        if ((NOT DEFINED GENCFG_${_opt}) AND
            (DEFINED CMAKE_GENERAL_CONFIG_${_opt}))
            set(GENCFG_${_opt} "${CMAKE_GENERAL_CONFIG_${_opt}}")
        endif ()
    endforeach ()

    if (NOT DEFINED GENCFG_PREFIX)
        to_varpart("${GENCFG_NAME}" GENCFG_PREFIX)
    endif ()

    foreach (_part ${_general_config_dirs})
        update_config_dir(GENCFG_${_part} "${_part}")
    endforeach ()

    # Forcing out of source build
    if (GENCFG_FORCE_OUT_OF_SOURCE_BUILD)
        include(MacroOutOfSourceBuild)
        macro_ensure_out_of_source_build(
            "${GENCFG_NAME} requires an out of source build.")
    endif ()

    # Forcing build type
    if (NOT CMAKE_BUILD_TYPE)
        set(CMAKE_BUILD_TYPE Release CACHE STRING
            "Choose the type of build, options are: '' 'Debug' 'Release' 'RelWithDebInfo' 'MinSizeRel'." FORCE)
    endif ()

    # Installation paths configuration
    set(GENERAL_CONFIG_NAME   "${GENCFG_NAME}"   PARENT_SCOPE)

    set(GENERAL_CONFIG_PREFIX_${GENCFG_NAME} "${GENCFG_PREFIX}"
        CACHE INTERNAL "Variable prefix used for project ${GENCFG_NAME}")

    foreach (_part ${_general_config_dirs})
        string(TOLOWER "${_part}" _part_desc)

        set(${GENCFG_PREFIX}_INSTALL_${_part}_DIR "${GENCFG_${_part}}"
            CACHE PATH "Installation directory for ${_part_desc} files")
    endforeach ()

    foreach (_var "CFLAGS_VARS" "DEFS_VARS" "LINK_FLAGS" "FORCE_OUT_OF_SOURCE_BUILD")
        set(${GENCFG_PREFIX}_${_var} ${GENCFG_${_var}}
            CACHE STRING "Value for ${_var} for ${GENCFG_NAME} project")
    endforeach ()

    if (DEFINED GENCFG_SUBDIRS)
        foreach (_subdir ${GENCFG_SUBDIRS})
            add_subdirectory(${_subdir})
        endforeach ()
    endif ()
endfunction ()

# dep_discovery(<dep> [<list of dep components> ...])
#
# Checks various cache variable names trying to find include path(-s) and link
# library(-ies), and sets variable with predetermined names in callee's scope in
# case of success.
#
# Upon discovery, sets the following variables in the parent scope:
# * _<dep>[_<component>]_{[dep]{lib|include_dirs}|defs|cflags|link_flags}[_varname]
# TODO: integration with pkg-config
function (dep_discovery _dep)
    set(CMAKE_DEP_DISCOVERY_INCLUDE_DIR_SUFFIX
        "_INCLUDE_DIRS"
        "_INCLUDEDIRS"
        "_INCLUDE_PATH"
        "_INCLUDEPATH"
        "_INCLUDE_DIR"
        "_INCLUDEDIR"
        "_INCLUDES"
        CACHE STRING
        "List of variable suffixes used for searching for include dirs definition.")
    set(CMAKE_DEP_DISCOVERY_LIB_SUFFIX
        "_LIBRARIES"
        "_LIBS"
        "_LIBRARY"
        "_LIB"
        CACHE STRING
        "List of variable suffixes used for searching for librariess definition.")
    set(CMAKE_DEP_DISCOVERY_DEFS_SUFFIX
        "_DEFS"
        "_DEFINITIONS"
        "_LIBRARY"
        "_LIB"
        CACHE STRING
        "List of variable suffixes used for searching for definitions.")
    set(CMAKE_DEP_DISCOVERY_CFLAGS_SUFFIX
        "_CFLAGS"
        "_COMPILEFLAGS"
        "_COMPILE_FLAGS"
        "_COMPILERFLAGS"
        "_COMPILER_FLAGS"
        CACHE STRING
        "List of variable suffixes used for searching for compiler flags.")
    set(CMAKE_DEP_DISCOVERY_LINK_FLAGS_SUFFIX
        "_LDFLAGS"
        "_LINKFLAGS"
        "_LINK_FLAGS"
        "_LINKER_FLAGS"
        CACHE STRING
        "List of variable suffixes used for searching for linker flags")
    set(CMAKE_DEP_DISCOVERY_DEPINCLUDE_DIR_SUFFIX
        "_DEP_INCLUDE_DIRS"
        "_DEP_INCLUDEDIRS"
        "_DEP_INCLUDE_PATH"
        "_DEP_INCLUDEPATH"
        "_DEP_INCLUDE_DIR"
        "_DEP_INCLUDEDIR"
        "_DEP_INCLUDES"
        CACHE STRING
        "List of variable suffixes used for searching for include dirs definition.")
    set(CMAKE_DEP_DISCOVERY_DEPLIB_SUFFIX
        "_DEP_LIBRARIES"
        "_DEP_LIBS"
        "_DEP_LIBRARY"
        "_DEP_LIB"
        CACHE STRING
        "List of variable suffixes used for searching for librariess definition.")

    string(TOUPPER "${_dep}" _dep_upper)

    if (DEFINED "${${_dep}_VAR_PREFIX}")
        # We assume that this is our library, so we use appropriate variables
        foreach (_comp "" ${ARGN})
            if (NOT ("${_comp}" STREQUAL ""))
                set(_comp "_${_comp}")
            endif ()

            foreach (_item
                "include_dir:INCLUDE_DIR"
                "lib:LIBRARY"
                "defs:DEFS"
                "cflags:CFLAGS"
                "link_flags:LINK_FLAGS"
                "depinclude_dir:DEP_INCLUDE_DIRS"
                "deplib:DEP_LIBRARIES"
                )
                string(REGEX MATCH "^[^:]*" _key "${_item}")
                string(REGEX MATCH "[^:]*$" _val "${_item}")

                if (DEFINED "${${_dep}_VAR_PREFIX}${_comp}_${_val}")
                    set(_${_dep}${_comp}_${_key}
                        "${${${_dep}_VAR_PREFIX}_{_comp}_${_val}}" PARENT_SCOPE)

                    set(_${_dep}${_comp}_${_key}_varname
                        "${${_dep}_VAR_PREFIX}_${_val}" PARENT_SCOPE)
                endif ()
            endforeach ()
        endforeach ()
    else ()
        # Performing guesswork
        foreach (_entity "include_dir" "lib" "defs" "cflags" "link_flags"
            "depinclude_dir" "deplib")
            string(TOUPPER "${_entity}" _entity_upper)
            foreach (_comp "" ${ARGN})
                if (DEFINED "DEP_DISCOVERY_HACK_${_dep}_${_comp}_${_entity_upper}")
                    foreach (_var ${DEP_DISCOVERY_HACK_${_dep}_${_comp}_${_entity_upper}})
                        if (DEFINED "${_var}")
                            set(_${_dep}_${_comp}_${_entity} "${${_var}}"
                                PARENT_SCOPE)
                            set(_${_dep}_${_comp}_${_entity}_varname "${_var}"
                                PARENT_SCOPE)

                            break()
                        endif ()
                    endforeach ()
                endif ()

                if (NOT ("${_comp}" STREQUAL ""))
                    set(_comp "_${_comp}")
                endif ()

                string(TOUPPER "${_comp}" _comp_upper)

                foreach (_comp_part "${_comp}" "${_comp_upper}")
                    if (DEFINED _${_dep}${_comp}_${_entity})
                        break()
                    endif ()

                    foreach (_dep_part "${_dep}" "${_dep_upper}")
                        if (DEFINED _${_dep}${_comp}_${_entity})
                            break()
                        endif ()

                        foreach (_suffix ${CMAKE_DEP_DISCOVERY_${_entity_upper}_SUFFIX})
                            if (DEFINED "${_dep_part}${_comp_part}${_suffix}")
                                set(_${_dep}${_comp}_${_entity}
                                    "${${_dep_part}${_comp_part}${_suffix}}"
                                    PARENT_SCOPE)
                                set(_${_dep}${_comp}_${_entity}_varname
                                    "${_dep_part}${_comp_part}${_suffix}"
                                    PARENT_SCOPE)

                                break()
                            endif ()
                        endforeach ()
                    endforeach ()
                endforeach ()
            endforeach ()
        endforeach ()
    endif ()
endfunction ()

# Callback for add_component() args parser which is needed since some argument
# names are defined dynamically during the course of parsing.
function (_add_component_arg_parse_update _var _access _value _list_file _stack)
# "DOXYGEN_{|<FORMAT>_}INSTALL_DIR"
    set(COMMON_SINGLE_VARS "TARGET_NAME" "TARGET_PREFIX" "TARGET_SUFFIX" "OUTPUT_NAME"
        "DOXYGEN" "DOXYGEN_TARGET_NAME" "DOXYGEN_TARGET_PREFIX"
        "DOXYGEN_TARGET_SUFFIX" "VERSION" "LIB_DIR" "AR_DIR" "BIN_DIR" "RES_DIR"
        "DOC_DIR" "INCLUDE_DIR" "CMAKE_DIR" "PKGCONFIG_DIR" "MAN_DIR")
    set(BIN_SINGLE_VARS )
    set(LIB_SINGLE_VARS "STATIC_TARGET_NAME" "SHARED_TARGET_NAME"
        "STATIC_TARGET_SUFFIX" "SHARED_TARGET_SUFFIX" "STATIC" "SHARED"
        "GEN_CMAKE_CONFIG" "CMAKE_CONFIG_PATH" "GEN_PKG_CONFIG" "DESCRIPTION"
        "PKG_CONFIG_PATH")

    set(COMMON_MULTI_VARS "SOURCES" "HEADERS" "SOURCES_GLOB" "HEADERS_GLOB"
        "RES" "DOC" "RES_GLOB" "DOC_GLOB" "INCLUDE_DIRS" "DEPS" "INT_DEPS"
        "LIB_DEPS" "DEFS" "CFLAGS" "LINK_FLAGS" "DOXYGEN_FORMATS"
        "DOXYGEN_OPTS")
    set(BIN_MULTI_VARS)
    set(LIB_MULTI_VARS)

    split(STRINGS "${_value}" CHARS "=" VARS _key _val)

    if (("XXX_${_key}" STREQUAL "XXX_BIN") OR ("XXX_${_key}" STREQUAL "XXX_LIB"))
        set(_res_single "${_singleArgNames}")
        set(_res_multi "${_multiArgNames}")

        foreach (_type "single" "multi")
            string(TOUPPER "${_type}" _type_upper)

            foreach (_var ${COMMON_${_type_upper}_VARS}
                ${${_key}_${_type_upper}_VARS})
                list(APPEND "_res_${_type}" "${_val}_${_var}")
            endforeach ()

            set("_${_type}ArgNames" "${_res_${_type}}" PARENT_SCOPE)
        endforeach ()
    endif ()
endfunction ()

# add_component(
#   NAME <compnent_name>
#   PARENT <project_name>
#   BIN "<list of binary targets>"
#   LIB "<list of library targets>"
#   FORCE_OUT_OF_SOURCE_BUILD 0/1
#   {<BINNAME>_|<LIBNAME>_}_TARGET_NAME <target name override>
#   <LIBNAME>_{STATIC|SHARED}_TARGET_NAME <target name override>
#   {|<BINNAME>_|<LIBNAME>_}_TARGET_PREFIX <target name override>
#   {|<BINNAME>_|<LIBNAME>_}_TARGET_SUFFIX <target name override>
#   {<LIBNAME>_}{STATIC_|SHARED_}TARGET_SUFFIX <target name override>
#   {<BINNAME>|<LIBNAME>}_OUTPUT_NAME <output name override>
#   {|<BINNAME>_|<LIBNAME>_}SOURCES <list of source files>
#   {|<BINNAME>_|<LIBNAME>_}HEADERS <list of header files>
#   {|<BINNAME>_|<LIBNAME>_}SOURCES_GLOB <list of source file globbings>
#   {|<BINNAME>_|<LIBNAME>_}HEADERS_GLOB <list of header file globbings>
#   {|<BINNAME>_|<LIBNAME>_}RES <list of resource files>
#   {|<BINNAME>_|<LIBNAME>_}DOC <list of additional documentation files>
#   {|<BINNAME>_|<LIBNAME>_}INCLUDE_DIRS <list of additional include dirs>
#   {|<LIBNAME>_}STATIC 0/1
#   {|<LIBNAME>_}SHARED 0/1
#   {|<BINNAME>_|<LIBNAME>_}{|INT_|LIB_}DEPS <dependencies>
#   {|<BINNAME>_|<LIBNAME>_}DEFS <list of additional definitions>
#   {|<BINNAME>_|<LIBNAME>_}CFLAGS <list of additional compile flags>
#   {|<BINNAME>_|<LIBNAME>_}LINK_FLAGS <list of additional link flags>
#   {|<BINNAME>_|<LIBNAME>_}DOXYGEN 0/1
#   {<BINNAME>_|<LIBNAME>_}DOXYGEN_TARGET_NAME <doxygen target name override>
#   {|<BINNAME>_|<LIBNAME>_}DOXYGEN_TARGET_PREFIX <doxygen target prefix>
#   {|<BINNAME>_|<LIBNAME>_}DOXYGEN_TARGET_SUFFIX <doxygen target suffix>
#   {|<BINNAME>_|<LIBNAME>_}DOXYGEN_FORMATS <list of doxygen formats>
#   {|<BINNAME>_|<LIBNAME>_}DOXYGEN_{|<FORMAT>_}INSTALL_DIR <dirs override>
#   {|<BINNAME>_|<LIBNAME>_}DOXYGEN_OPTS <add_doxygen() options>
#   {|<LIBNAME>_}GEN_CMAKE_CONFIG 0/1
#   {|<LIBNAME>_}CMAKE_CONFIG_PATH <path_to_custom cmake config file>
#   {|<LIBNAME>_}GEN_PKG_CONFIG 0/1
#   {<LIBNAME>_}_DESCRIPTION <description string>
#   {|<BINNAME>_|<LIBNAME>_}_VERSION <version string>
#   {|<LIBNAME>_}PKG_CONFIG_PATH <path_to_custom pkg config file>
#   {|<BINNAME>_|<LIBNAME>_}{LIB|AR|BIN|RES|DOC|INCLUDE|CMAKE|PKGCONFIG|MAN}_DIR <installation path override>
# )
#
# Function provides most of its parameters as cache variables available to user,
# so there is no additional work needed for providing ability to override them.
#
# Target name: in case it is not overridden with *_TARGET_NAME, it is
# constructed as follows:
#   "<prefix><bin/libname><suffix><static/shared suffix>"
#
# Dependency:
#  * "Local" dependency - library name found by "add_library"
#
# Dependency is provided in form
#   "<dep_name>[/{<component_name>]"
#
# Note: in case no doxygen generation is performed, no doxygen format install
#       dir options parsing is performed, take this into account in case of
#       relying on CMAKE_* defaults and providing *DOXYGEN_*_INSTALL_DIR
#       options!
#
# XXX: not to be confused with install components or package components
#
# TODO: switching between ext/int deps?
# TODO: version support for deps
# TODO: package versioning (parse headers, explicit setting)
function (add_component)
    # Argument parsing

    set(_ova_parts ${_add_component_opts})
    set(_multi_parts "SOURCES" "HEADERS" "SOURCES_GLOB" "HEADERS_GLOB"
        "INCLUDE_DIRS" "RES" "DOC" "RES_GLOB" "DOC_GLOB" "DEPS" "INT_DEPS"
        "LIB_DEPS" "DOXYGEN_FORMATS" "DOXYGEN_OPTS")

    set(_addcmp_opt_args)
    set(_addcmp_single_args "NAME" "PARENT" ${_ova_parts})
    set(_addcmp_multi_args "BIN" "LIB" ${_multi_parts})

    foreach (_part ${_addcmp_opt_args} ${_addcmp_single_args}
        ${_addcmp_multi_args})
        unset(ADDCMP_${_part})
    endforeach ()

    parse_args_incremental(ADDCMP
        "${_addcmp_opt_args}" "${_addcmp_single_args}" "${_addcmp_multi_args}"
        _add_component_arg_parse_update ${ARGN})

    if (NOT DEFINED ADDCMP_NAME)
        set(ADDCMP_NAME "${PROJECT_NAME}")
    endif ()

    message("BIN: ${ADDCMP_BIN}")
    message("LIB: ${ADDCMP_LIB}")

    # Implicit generation of bin/lib subcomponents list
    if (("${ADDCMP_BIN}" STREQUAL "") AND ("${ADDCMP_LIB}" STREQUAL ""))
        if (NOT (DEFINED ADDCMP_BIN) AND NOT (DEFINED ADDCMP_LIB))
            set(ADDCMP_BIN "${ADDCMP_NAME}")
        elseif (DEFINED ADDCMP_LIB AND NOT (DEFINED ADDCMP_BIN))
            set(ADDCMP_LIB "${ADDCMP_NAME}")
        else ()

            message(FATAL_ERROR "add_component(): nor BIN nor LIB lists are explicitly defined, and not one and only one of empty BIN or LIB is declared, so implicit declaation is also failed.")
        endif ()
    endif ()

    # Override from cache

    foreach (_part "" ${ADDCMP_BIN} ${ADDCMP_LIB})
        if (NOT ("${_part}" STREQUAL ""))
            set(_part "${_part}_")
        endif ()

        foreach (_type "ova" "multi")
            foreach (_val ${_${_type}_parts})
                if (DEFINED COMPONENT_${ADDCMP_NAME}_${_part}${_val})
                    set(ADDCMP_${_part}${_val}
                        "${COMPONENT_${ADDCMP_NAME}_${_part}${_val}}")
                endif ()
            endforeach ()
        endforeach ()
    endforeach ()

    # Parameter propagation

    if (NOT DEFINED ADDCMP_PARENT)
        set(ADDCMP_PARENT "${GENERAL_CONFIG_NAME}")
    endif ()
    set(_parent_prefix "${GENERAL_CONFIG_PREFIX_${ADDCMP_PARENT}}")

    if (NOT DEFINED ADDCMP_FORCE_OUT_OF_SOURCE_BUILD)
        if (DEFINED ${${_parent_prefix}_FORCE_OUT_OF_SOURCE_BUILD})
            set(ADDCMP_FORCE_OUT_OF_SOURCE_BUILD
                "${${_parent_prefix}_FORCE_OUT_OF_SOURCE_BUILD}")
        else ()
            set(ADDCMP_FORCE_OUT_OF_SOURCE_BUILD
                "${CMAKE_GENERAL_CONFIG_FORCE_OUT_OF_SOURCE_BUILD}")
        endif ()
    endif ()

    foreach (_dir ${_general_config_dirs})
        update_config_dir(ADDCMP_${_dir}_DIR "${_dir}"
            PROJECT "${ADDCMP_NAME}"
            GENERAL_DEFAULT "${GENCFG_${_dir}}")
    endforeach ()

    foreach (_part ${ADDCMP_BIN} ${ADDCMP_LIB})
        foreach (_dir ${_general_config_dirs})
            update_config_dir(ADDCMP_${_part}_${_dir}_DIR "${_dir}"
                PROJECT "${_part}"
                PROJECT_DEFAULT "${ADDCMP_${_dir}_DIR}"
                GENERAL_DEFAULT "${${_parent_prefix}_INSTALL_${_dir}_DIR}")
        endforeach ()
    endforeach ()

    foreach (_opt ${_ova_parts})
        if ((NOT DEFINED ADDCMP_${_opt}) AND
            (DEFINED CMAKE_ADD_COMPONENT_${_opt}))
            message("Propagating to ADDCMP_${_opt} value '${CMAKE_ADD_COMPONENT_${_opt}}'")
            set(ADDCMP_${_opt} "${CMAKE_ADD_COMPONENT_${_opt}}")
        endif ()
    endforeach ()

    foreach (_part ${ADDCMP_BIN} ${ADDCMP_LIB})
        foreach (_opt ${_ova_parts})
            if ((NOT DEFINED ADDCMP_${_part}_${_opt}) AND
                (DEFINED ADDCMP_${_opt}))
                message("Propagating to ADDCMP_${_part}_${_opt} value '${ADDCMP_${_opt}}'")
                set(ADDCMP_${_part}_${_opt} "${ADDCMP_${_opt}}")
            endif ()
        endforeach ()
    endforeach ()

    foreach (_part ${ADDCMP_BIN} ${ADDCMP_LIB})
        if (NOT DEFINED "ADDCMP_${_part}_OUTPUT_NAME")
            set("ADDCMP_${_part}_OUTPUT_NAME" "${_part}")
        endif ()
    endforeach ()

    foreach (_part ${ADDCMP_LIB})
        foreach (_linking "STATIC" "SHARED")
            if (NOT DEFINED "ADDCMP_${_part}_${_linking}_OUTPUT_NAME")
                set("ADDCMP_${_part}_${_linking}_OUTPUT_NAME"
                    "${ADDCMP_${_part}_OUTPUT_NAME}")
            endif ()
        endforeach ()
    endforeach ()

    # Calculating target name

    foreach (_part ${ADDCMP_BIN})
        unset(_${_part}_target_STATIC)
        unset(_${_part}_target_SHARED)

        if (DEFINED ADDCMP_${_part}_TARGET_NAME)
            set(_${_part}_target "${ADDCMP_${_part}_TARGET_NAME}")
        else ()
            set(_${_part}_target
                "${ADDCMP_${_part}_TARGET_PREFIX}${_part}${ADDCMP_${_part}_TARGET_SUFFIX}")
        endif ()
    endforeach ()

    foreach (_part ${ADDCMP_LIB})
        unset(_${_part}_target)

        foreach (_type "STATIC" "SHARED")
            if (DEFINED ADDCMP_${_part}_${_type}_TARGET_NAME)
                set(_${_part}_target_${_type} "${ADDCMP_${_part}_TARGET_NAME}")
            else ()
                if (DEFINED ADDCMP_${_part}_TARGET_NAME)
                    set(_${_part}_target_${_type}
                        "${ADDCMP_${_part}_TARGET_NAME}${ADDCMP_${_part}_${_type}_TARGET_SUFFIX}")
                else ()
                    set(_${_part}_target_${_type}
                        "${ADDCMP_${_part}_TARGET_PREFIX}${_part}${ADDCMP_${_part}_TARGET_SUFFIX}${ADDCMP_${_part}_${_type}_TARGET_SUFFIX}")
                endif ()
            endif ()
        endforeach ()
    endforeach ()


    # Forcing out of source build

    if (ADDCMP_FORCE_OUT_OF_SOURCE_BUILD)
        include(MacroOutOfSourceBuild)
        macro_ensure_out_of_source_build(
            "${ADDCMP_NAME} requires an out of source build.")
    endif ()


    # Dependency handling

    set(_alldeps)
    set(_INT_alldeps)
    set(_lib_alldeps)
    foreach (_part "" ${ADDCMP_BIN} ${ADDCMP_LIB})
        if (NOT ("${_part}" STREQUAL ""))
            set(_part "${_part}_")
        endif ()

        # Package names
        set(_${_part}deps)
        set(_${_part}INT_deps)

        foreach (_type "" "INT_")
            if (DEFINED COMPONENT_${ADDCMP_NAME}_${_part}${_type}DEPS)
                foreach (_dep_str ${COMPONENT_${ADDCMP_NAME}_${_part}${_type}DEPS})
                    string(REGEX MATCH "^[^/]*" _dep "${_dep_str}")
                    string(REGEX REPLACE "^[^/]*/" "" _dep_comp "${_dep_str}")

                    list(FIND _${_type}deps "${_dep}" _dep_pos)
                    if (${_dep_pos} EQUAL -1)
                        set(_alldep_components_${_dep})
                        set(_${_part}dep_components_${_dep})
                    endif ()

                    # Adding component to the list of components
                    if (NOT ("${_dep_str}" STREQUAL "${_dep_comp}"))
                        list(APPEND _alldep_components_${_dep} "${_dep_comp}")
                        list(APPEND _${_part}dep_components_${_dep} "${_dep_comp}")
                    endif ()

                    list(APPEND _${_type}alldeps "${_dep}")
                    list(APPEND _${_part}${_type}deps "${_dep}")
                endforeach ()
            endif ()
        endforeach ()

        foreach (_list "_${_part}deps" "_${_part}INT_deps")
            if (DEFINED "${_list}")
                list(REMOVE_DUPLICATES "${_list}")
            endif ()
        endforeach ()

        if (DEFINED COMPONENT_${ADDCMP_NAME}_${_part}LIB_DEPS)
            foreach (_dep ${COMPONENT_${ADDCMP_NAME}_${_part}LIB_DEPS})
                list(APPEND _lib_alldeps "${_dep}")
                list(APPEND _${_part}lib_deps "${_dep}")
            endforeach ()
        endif ()
    endforeach ()

    set(_merged_alldeps ${_deps} ${_INT_deps})

    foreach (_list "_alldeps" "_INT_alldeps" "_lib_alldeps" "_merged_alldeps")
        if (DEFINED "${_list}")
            list(REMOVE_DUPLICATES "${_list}")
        endif ()
    endforeach ()

    foreach (_dep ${_merged_alldeps})
        if ("${_dep_components_${_dep}}" STREQUAL "")
            find_package("${_dep}" REQUIRED)
        else ()
            find_package("${_dep}" REQUIRED COMPONENTS ${_dep_components_${_dep}})
        endif ()
    endforeach ()

    foreach (_dep ${_lib_alldeps})
        find_library(_${_dep}_lib "${_dep}")
    endforeach ()

    # File globbings

    foreach (_part "" ${ADDCMP_BIN} ${ADDCMP_LIB})
        if (NOT ("${_part}" STREQUAL ""))
            set(_part "${_part}_")
        endif ()

        foreach (_type "SOURCES" "HEADERS" "RES" "DOC")
            foreach (_glob ${ADDCMP_${_part}${_type}_GLOB})
                file(GLOB _tmp "${_glob}")
                list(APPEND "ADDCMP_${_part}${_type}" ${_tmp})
            endforeach ()
        endforeach ()
    endforeach ()

    # Executable definition

    foreach (_bin ${ADDCMP_BIN})
        set("_${_bin}_target_suffixes" "")
        set("_${_bin}_targets" "${_${_bin}_target}")

        message("BIN: ${_bin}")

        add_executable(${_${_bin}_target}
            ${ADDCMP_SOURCES} ${ADDCMP_HEADERS}
            ${ADDCMP_${_bin}_SOURCES} ${ADDCMP_${_bin}_HEADERS})

        foreach (_prop "OUTPUT_NAME" "VERSION" "SOVERSION")
            if (DEFINED "ADDCMP_${_bin}_${_prop}")
                set_property(TARGET "${_${_bin}_target}"
                    PROPERTY "${_prop}"
                    "${ADDCMP_${_bin}_${_prop}}")
            endif ()
        endforeach ()
    endforeach ()


    # Library definition

    foreach (_lib ${ADDCMP_LIB})
        unset("_${_lib}_target_suffixes")
        unset("_${_lib}_targets")

        foreach (_linking "SHARED" "STATIC")
            if ("${ADDCMP_${_lib}_${_linking}}")
                list(APPEND "_${_lib}_target_suffixes" "_${_linking}")
                list(APPEND "_${_lib}_targets" "${_${_lib}_target_${_linking}}")

                add_library("${_${_lib}_target_${_linking}}" "${_linking}"
                    ${ADDCMP_SOURCES} ${ADDCMP_HEADERS}
                    ${ADDCMP_${_lib}_SOURCES} ${ADDCMP_${_lib}_HEADERS})

                foreach (_prop "OUTPUT_NAME" "VERSION" "SOVERSION")
                    if (DEFINED "ADDCMP_${_lib}_${_linking}_${_prop}")
                        set_property(TARGET "${_${_lib}_target_${_linking}}"
                            PROPERTY "${_prop}"
                            "${ADDCMP_${_lib}_${_linking}_${_prop}}")
                    elseif (DEFINED "ADDCMP_${_lib}_${_prop}")
                        set_property(TARGET "${_${_lib}_target_${_linking}}"
                            PROPERTY "${_prop}"
                            "${ADDCMP_${_lib}_${_prop}}")
                    endif ()
                endforeach ()
            endif ()
        endforeach ()

        if (NOT DEFINED "_${_lib}_target_suffixes")
            message(SEND_ERROR "Both static and shared targets disabled for ${_lib}, this is considered erroneous. Enable at least one of the targets or remove '${_lib}' from component list.")
        endif ()
    endforeach ()

    # Deps preprocessing: include dirs and link libs discovery

    foreach (_dep ${_merged_alldeps})
        dep_discovery(${_dep} ${_alldep_components_${_dep}})
    endforeach ()


    # Forging libs/includedirs/cflags/defs for targets

    macro (_update_target _part _type)
        set(_ut_opt_args)
        set(_ut_single_args)
        set(_ut_multi_args "DIRECT")

        foreach (_var ${_ut_opt_args} ${_ut_single_args} ${_ut_multi_args})
            unset(UPDATE_TARGET_${_part})
        endforeach ()

        cmake_parse_arguments(UPDATE_TARGET
            "${_ut_opt_args}" "${_ut_single_args}" "${_ut_multi_args}" ${ARGN})

        set(_ARGS "${UPDATE_TARGET_DIRECT}")
        foreach (_var ${UPDATE_TARGET_UNPARSED_ARGUMENTS})
            list(APPEND "${${_var}}")
        endforeach ()

        foreach (_suffix ${_${_part}_target_suffixes})
            set(_target "${_${_part}_target${_suffix}}")

            if ("${_type}" STREQUAL "lib")
                target_link_libraries("${_target}" ${_ARGS})
            elseif ("${_type}" STREQUAL "include_dir")
                set_property(TARGET "${_target}" APPEND
                    PROPERTY INCLUDE_DIRECTORIES ${_ARGS})
            elseif ("${_type}" STREQUAL "cflags")
                foreach (_arg ${_ARGS})
                    set_property(TARGET "${_target}" APPEND_STRING
                        PROPERTY COMPILE_FLAGS " ${_arg}")
                endforeach ()
            elseif ("${_type}" STREQUAL "link_flags")
                foreach (_arg ${_ARGS})
                    set_property(TARGET "${_target}" APPEND_STRING
                        PROPERTY LINK_FLAGS " ${_arg}")
                endforeach ()
            elseif ("${_type}" STREQUAL "defs")
                set_property(TARGET "${_target}" APPEND
                    PROPERTY COMPILE_DEFINITIONS ${_ARGS})
            endif ()
        endforeach ()

        list(APPEND "_${_part}_CMAKE_CONFIG_DEP_CODE_DIRECT_${_type}"
            "${UPDATE_TARGET_DIRECT}")
        list(APPEND "_${_part}_CMAKE_CONFIG_DEP_CODE_${_type}"
            "${UPDATE_TARGET_UNPARSED_ARGUMENTS}")
    endmacro ()

    foreach (_entity "cflags" "defs" "link_flags")
        string(TOUPPER "${_entity}" _entity_upper)

        set(_merged_parent_${_entity})
        if (DEFINED "${_parent_prefix}_${_var}")
            foreach (_var ${${_parent_prefix}_${_entity_upper}_VARS})
                if (DEFINED "${_var}")
                    list(APPEND "_merged_parent_${_entity}" "${${_var}}")
                endif ()
            endforeach ()
        endif ()
    endforeach ()

    foreach (_part ${ADDCMP_BIN} ${ADDCMP_LIB})
        foreach (_type "" "INT_" "lib_")
            set("_${_part}_merged_${_type}deps"
                "${_${type}deps} ${_${_part}_${_type}deps}")
            list(REMOVE_DUPLICATES "_${_part}_merged_${_type}deps")

            foreach (_dep _${_part}_merged_${_type}deps)
                foreach (_entity "lib" "include_dir" "cflags" "defs" "link_flags")
                    if ((NOT DEFINED "_${_dep}_components") OR
                        (NOT DEFINED "_${_part}_${_dep}_components"))
                        # Hack: appending string only once
                        if ("${_entity}" STREQUAL "lib")
                            set("_${_part}_CMAKE_CONFIG_DEP_CODE_findpkg"
                                "${_${_part}_CMAKE_CONFIG_DEP_CODE_findpkg}\n    find_package(\"${_dep}\" REQUIRED)")
                        endif ()

                        _update_target("${_part}" "${_entity}"
                            "${_${dep}_dep${_entity}_varname}"
                            "${_${_dep}_${_entity}_varname}")
                    else ()
                        set("_${_part}_${_dep}_merged_${_type}comps"
                            "${_${_dep}_components} ${_${_part}_${_dep}_components}")
                        list(REMOVE_DUPLICATES "_${_part}_${_dep}_merged_${_type}comps")

                        # Hack: appending string only once
                        if ("${_entity}" STREQUAL "lib")
                            set("_${_part}_CMAKE_CONFIG_DEP_CODE_findpkg"
                                "${_${_part}_CMAKE_CONFIG_DEP_CODE_findpkg}\n    find_package(\"${_dep}\" REQUIRED COMPONENTS ${_${_part}_${_dep}_merged_${_type}comps})")
                        endif ()

                        foreach (_comp _${_part}_${_dep}_merged_${_type}comps)
                            if (DEFINED "_${_dep}_${_comp}_dep${_entity}_varname")
                                _update_target("${_part}" "${_entity}"
                                    "${_${_dep}_${_comp}_dep${_entity}_varname}")
                            elseif (DEFINED "_${_dep}_dep${_entity}_varname")
                                _update_target("${_part}" "${_entity}"
                                    "${_${_dep}_dep${_entity}_varname}")
                            else ()
                                _update_target("${_part}" "${_entity}"
                                    "${_${_dep}_${_entity}_varname}")
                            endif ()

                            if (DEFINED "_${_dep}_${_comp}_${_entity}_varname")
                                _update_target("${_part}" "${_entity}"
                                    "${_${_dep}_${_comp}_${_entity}_varname}")
                            else ()
                                _update_target("${_part}" "${_entity}"
                                    "${_${_dep}_${_entity}_varname}")
                            endif ()
                        endforeach ()
                    endif ()
                endforeach ()
            endforeach ()
        endforeach ()

        foreach (_entity "cflags" "defs" "link_flags" "include_dirs")
            string(TOUPPER "${_entity}" _entity_upper)

            _update_target("${_part}" "${_entity}"
                DIRECT  "${_merged_parent_${_entity}}"
                ${ADDCMP_${_entity_upper}} ${ADDCMP_${_part}_${_entity_upper}})
        endforeach ()
    endforeach ()


    # Doxygen

    ## Figuring out whether we should include DoxygenUtils
    set(_include_doxygen_utils "${CMAKE_ADD_COMPONENT_DOXYGEN}")
    if (NOT "${_include_doxygen_utils}")
        foreach (_part "" ${ADDCMP_BIN} ${ADDMCP_LIB})
            if (NOT ("${_part}" STREQUAL ""))
                set(_part "${_part}_")
            endif ()

            if ("${ADDCMP${_part}_DOXYGEN}")
                set(_include_doxygen_utils 1)

                break()
            endif ()
        endforeach ()
    endif ()

    # Initializing doxygen per-format option lists
    set(_fmt_opts)
    set(_all_fmt_opts)

    if ("${_include_doxygen_utils}")
        include(DoxygenUtils)

        foreach (_opt in "INSTALL_DIR")
            foreach (_fmt in _doc_formats)
                foreach (_part "" ${ADDCMP_BIN} ${ADDCMP_LIB})
                    if (NOT ("${_part}" STREQUAL ""))
                        set(_part "${_part}_")
                    endif ()

                    list(APPEND _fmt_opts "${_part}DOXYGEN_${_fmt}_${_opt}")
                endforeach ()

                list(APPEND _all_fmt_opts "DOXYGEN_${_fmt}_${_opt}")
            endforeach ()
        endforeach ()

        set(_Options)
        set(_OneValueArgs ${_fmt_opts})
        set(_MultiValueArgs)

        foreach (_part ${_Options} ${_OneValueArgs} ${_MultiValueArgs})
            unset(ADDCMP_${_part})
        endforeach ()

        cmake_parse_arguments(ADDCMP
            "${_Options}" "${_OneValueArgs}" "${_MultiValueArgs}"
            ${ADDCMP_UNPARSED_ARGUMENTS})

        # Override from cache

        foreach (_opt ${_fmt_opts})
            if (DEFINED COMPONENT_${ADDCMP_NAME}_${_opt})
                set(ADDCMP_${_opt}
                    "${COMPONENT_${ADDCMP_NAME}_${_opt}}")
            endif ()
        endforeach ()

        # Propagation

        foreach (_opt ${_all_fmt_opts})
            if ((NOT DEFINED ADDCMP_${_opt}) AND
                (DEFINED CMAKE_ADD_COMPONENT_${_opt}))
                set(ADDCMP_${_opt} "${CMAKE_ADD_COMPONENT_${_opt}}")
            endif ()
        endforeach ()

        foreach (_part ${ADDCMP_BIN} ${ADDCMP_LIB})
            foreach (_opt ${_all_fmt_opts})
                if ((NOT DEFINED ADDCMP_${_part}_${_opt}) AND
                    (DEFINED ADDCMP_${_opt}))
                    set(ADDCMP_${_part}_${_opt} "${ADDCMP_${_opt}}")
                endif ()
            endforeach ()
        endforeach ()

        # Calculating target name

        foreach (_part ${ADDCMP_BIN} ${ADDCMP_LIB})
            if (DEFINED ADDCMP_${_part}_DOXYGEN_TARGET_NAME)
                set(_${_part}_doxygen_target
                    "${ADDCMP_${_part}_DOXYGEN_TARGET_NAME}")
            else ()
                set(_${_part}_doxygen_target
                    "${ADDCMP_${_part}_DOXYGEN_TARGET_PREFIX}${_part}${ADDCMP_${_part}_DOXYGEN_TARGET_SUFFIX}")
            endif ()
        endforeach ()

        # Calling add_doxygen()

        foreach (_part ${ADDCMP_BIN} ${ADDCMP_LIB})
            set(_dir_opts)
            foreach (_fmt ${_doc_formats})
                list(APPEND _dir_opts
                    "${_fmt}_INSTALL_DIR"
                    "${ADDCMP_${_part}_DOXYGEN_${_fmt}_INSTALL_DIR}")
            endforeach ()

            unset(_targets)
            foreach (_suffix ${_${_part}_target_suffixes})
                list(APPEND _targets "${_${_part}_target${_suffix}}")
            endforeach ()

            add_doxygen("_${_part}_doxygen_target"
                ${ADDCMP_${_part}_DOXYGEN_FORMATS}
                TARGETS _${_targets}
                ${_dir_opts}
                ${ADDCMP_${_part}_DOXYGEN_OPTS}
                )
        endforeach ()
    endif ()


    # Install
    foreach (_part ${ADDCMP_BIN} ${ADDCMP_LIB})
        install(FILES ${ADDCMP_HEADERS} ${ADDCMP_${_part}_HEADERS}
            DESTINATION "${ADDCMP_${_part}_INCLUDE_DIR}")

        install(TARGETS ${_${_part}_targets}
            EXPORT ${_part}Targets
            RUNTIME DESTINATION "${ADDCMP_${_part}_BIN_DIR}"
            LIBRARY DESTINATION "${ADDCMP_${_part}_LIB_DIR}"
            ARCHIVE DESTINATION "${ADDCMP_${_part}_AR_DIR}")
    endforeach ()

    # pkg-config
    foreach (_type "LIB")
        foreach (_part ${ADDCMP_LIB})
            if ("${ADDCMP_${_part}_GEN_PKG_CONFIG}")
                foreach (_dir "LIB" "INCLUDE")
                    get_rel_path(PKG_CONPKG_CONFIG_${_dir}_INSTALL_DIR
                        "${CMAKE_INSTALL_DIR}"
                        "${ADDCMP_${_part}_${_dir}_DIR}")
                endforeach ()

                set(PKG_CONFIG_COMPONENT_NAME "${_part}")
                set(PKG_CONFIG_COMPONENT_DESCRIPTION "${ADDCMP_${_part}_DESCRIPTION}")
                set(PKG_CONFIG_COMPONENT_VERSION "${ADDCMP_${_part}_VERSION}")
                set(PKG_CONFIG_LIB_NAME "${ADDCMP_${_part}_OUTPUT_NAME}")

                if (DEFINED "ADDCMP_${_part}_PKG_CONFIG_REQUIRES")
                    set(PKG_CONFIG_COMPONENT_REQUIRES
                        "${ADDCMP_${_part}_PKG_CONFIG_REQUIRES}")
                else ()
                endif ()
            endif ()

            message("configure_file('${ADDCMP_${_part}_PKG_CONFIG_PATH}' '${PROJECT_BINARY_DIR}/${ADDCMP_${_part}_OUTPUT_NAME}.pc' @ONLY)")
            configure_file("${ADDCMP_${_part}_PKG_CONFIG_PATH}"
                "${PROJECT_BINARY_DIR}/${ADDCMP_${_part}_OUTPUT_NAME}.pc" @ONLY)
            install(FILES "${PROJECT_BINARY_DIR}/${ADDCMP_${_part}_OUTPUT_NAME}.pc"
                DESTINATION "${ADDCMP_${_part}_PKGCONFIG_DIR}")
        endforeach ()
    endforeach ()


    # CMake exports
    foreach (_part ${ADDCMP_BIN} ${ADDCMP_LIB})
        to_varpart("${_part}" _part_upper)

        list(LENGTH "_${_part}_target_suffixes" _suffixes_len)
        if ("${_suffixes_len}" GREATER 0)
            list(GET "_${_part}_target_suffixes" 0 _suffix)
            set(_part_target "${_${_part}_target${_suffix}}")
        else ()
            set(_suffix "")
            set(_part_target "${_${_part}_target}")
        endif ()

        set(CMAKE_CONFIG_PROJECT_NAME "${_part}")
        set(CMAKE_CONFIG_PROJECT_VAR_NAME "${_part_upper}")

        set(CMAKE_CONFIG_DEPS_CODE "    ${_${_part}_CMAKE_CONFIG_DEP_CODE_findpkg}")

        foreach (_list_prop "include_dir:INCLUDE_DIRS" "lib:LIBRARIES" "defs:DEFS")
            string(REGEX MATCH "^[^:]*" _key "${_list_prop}")
            string(REGEX MATCH "[^:]*$" _val "${_list_prop}")
            set(CMAKE_CONFIG_DEPS_CODE
                "${CMAKE_CONFIG_DEPS_CODE}\n\n    set(${_part_upper}_DEP_${_val} \"${_${_part}_CMAKE_CONFIG_DEP_CODE_${_key}}\")")
        endforeach ()

        set(CMAKE_CONFIG_DEPS_CODE
            "${CMAKE_CONFIG_DEPS_CODE}\n")

        foreach (_str_prop "cflags" "link_flags")
            string(TOUPPER "${_str_prop}" _suffix)

            unset(_concat_val)
            foreach (_val ${_${_part}_CMAKE_CONFIG_DEP_CODE_${_str_prop}})
                if (DEFINED _concat_val)
                    set(_concat_val "${_concat_val} \$\{${_val}\}")
                else ()
                    set(_concat_val "\$\{${_val}\}")
                endif ()
            endforeach ()

            set(CMAKE_CONFIG_DEPS_CODE
                "${CMAKE_CONFIG_DEPS_CODE}\n\n    set(${_part_upper}_DEP_${_suffix} \"${_concat_val}\")")
        endforeach ()

        set(_dirs)
        foreach (_file ${ADDCMP_HEADERS} ${ADDCMP_${_part}_HEADERS})
            get_abs_path(_file "${_file}" BASE "${PROJECT_SOURCE_DIR}")
            get_filename_component(_dir "${_file}" PATH)
            list(APPEND _dirs "${_dir}")
        endforeach ()
        list(REMOVE_DUPLICATES _dirs)

        set(CMAKE_CONFIG_INCLUDE_DIR "${_dirs}")
        set(CMAKE_CONFIG_TARGET_NAME "${_part_target}")
        set(CMAKE_CONFIG_LIBRARY "${_part_target}")
        set(CMAKE_CONFIG_DEFS ${ADDCMP_DEFS} ${ADDCMP_${_part}_DEFS})
        set(CMAKE_CONFIG_CFLAGS ${ADDCMP_CFLAGS} ${ADDCMP_${_part}_CFLAGS})
        set(CMAKE_CONFIG_LINK_FLAGS ${ADDCMP_LINK_FLAGS} ${ADDCMP_${_part}_LINK_FLAGS})

        # Local cmake config
        configure_file("${ADDCMP_${_part}_CMAKE_CONFIG_PATH}"
            "${PROJECT_BINARY_DIR}/${_part}Config.cmake" @ONLY)
        export(TARGETS ${_${_part}_targets}
            FILE "${PROJECT_BINARY_DIR}/${_part}Targets.cmake")
        export(PACKAGE "${_part}")

        # Installed cmake config
        configure_file("${ADDCMP_${_part}_CMAKE_CONFIG_PATH}"
            "${PROJECT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${ADDCMP_${_part}}Config.cmake" @ONLY)
        install(FILES "${PROJECT_BINARY_DIR}/${ADDCMP_${_part}}Config.cmake"
            DESTINATION "${ADDCMP_${_part}_CMAKE_DIR}")

        install(EXPORT ${PROJECT_NAME}Targets DESTINATION
            "${ADDCMP_${_part}_CMAKE_DIR}" COMPONENT dev)
    endforeach ()
endfunction ()
