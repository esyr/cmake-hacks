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

	if (GET_ABS_PATH_BASE AND (_PATH MATCHES "^[^/]"))
		get_filename_component(${_VAR} "${GET_ABS_PATH_BASE}/${_PATH}" REALPATH)
	else (GET_ABS_PATH_BASE AND (_PATH MATCHES "^[^/]"))
		get_filename_component(${_VAR} "${_PATH}" REALPATH)
	endif (GET_ABS_PATH_BASE AND (_PATH MATCHES "^[^/]"))

	set(${_VAR} ${${_VAR}} PARENT_SCOPE)
endfunction (get_abs_path _VAR _PATH)

