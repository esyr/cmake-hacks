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

    if (DEFINED GET_REL_PATH_BASE)
        get_abs_path(_base_abs "${_BASE}" BASE "${GET_REL_PATH_BASE}")
    else ()
        get_abs_path(_base_abs "${_BASE}")
    endif ()

    get_abs_path(_path_abs "${_PATH}" BASE "${_base_abs}")

    file(RELATIVE_PATH _result "${_base_abs}" "${_path_abs}")

    set("${_VAR}" "${_result}" PARENT_SCOPE)
endfunction ()
