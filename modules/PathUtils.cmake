# get_abs_path(<varname> <path> BASE <basepath>)
function (get_abs_path _VAR _PATH)
    include(CMakeParseArguments)

    set(_Options "")
    set(_OneValueArgs BASE)
    set(_MultiValueArgs "")
    cmake_parse_arguments(GET_ABS_PATH
        "${_Options}"
        "${_OneValueArgs}"
        "${_MultiValueArgs}"
        ${ARGN}
    )

    set(_result "")

    if (GET_ABS_PATH_BASE AND (_PATH MATCHES "^[^/]"))
        get_filename_component(_result "${GET_ABS_PATH_BASE}/${_PATH}" REALPATH)
    else (GET_ABS_PATH_BASE AND (_PATH MATCHES "^[^/]"))
        get_filename_component(_result "${_PATH}" REALPATH)
    endif (GET_ABS_PATH_BASE AND (_PATH MATCHES "^[^/]"))

    string(LENGTH "${_result}" _len)
    if ("${_len}" GREATER 0)
        string(SUBSTRING "${_result}" 0 1 _prefix)
    endif ()

    # Working around erroneous get_filename_component() behaviour
    if (("${_len}" EQUAL 0) OR NOT ("XXX_${_prefix}" STREQUAL "XXX_/"))
        set(_result "/${_result}")
    endif ()

    set(${_VAR} "${_result}" PARENT_SCOPE)
endfunction (get_abs_path _VAR _PATH)

# get_rel_path(<varname> <base> <path> [BASE <base_base>])
# Like file(RELATIVE_PATH ...), but normalizes paths (with get_abs_path())
# before calling it, which allows coping with some erroneous behaviour of this
# call.
function (get_rel_path _VAR _BASE _PATH)
    include(CMakeParseArguments)

    set(_Options)
    set(_OneValueArgs BASE)
    set(_MultiValueArgs)

    foreach (_arg in ${_Options} ${_OneValueArgs} ${_MultiValueArgs})
        unset("GET_REL_PATH_${_arg}")
    endforeach ()

    cmake_parse_arguments(GET_REL_PATH
        "${_Options}"
        "${_OneValueArgs}"
        "${_MultiValueArgs}"
        ${ARGN}
    )

    if (NOT ("${_BASE}" MATCHES "^/") AND NOT DEFINED GET_REL_PATH_BASE)
        if ("${_PATH}" MATCHES "^/")
            message(FATAL_ERROR "get_rel_path(${_VAR} ${_BASE} ${_PATH}): can't calculate patch for absolute path relative to relative one without base provided.")
        else ()
            # We can assume that paths have common base
            # Note: it can perform not so well in case one of paths is going to
            # far upwards (to many ".." part), since the result would be wrong
            # in case they are used against directory not deep enough

        endif ()
    endif ()

    if (DEFINED GET_REL_PATH_BASE)
        get_abs_path(_base_abs "${_BASE}" BASE "${GET_REL_PATH_BASE}")
    else ()
        get_abs_path(_base_abs "${_BASE}")
    endif ()

    get_abs_path(_path_abs "${_PATH}" BASE "${_base_abs}")

    file(RELATIVE_PATH _result "${_base_abs}" "${_path_abs}")

    set("${_VAR}" "${_result}" PARENT_SCOPE)
endfunction ()
