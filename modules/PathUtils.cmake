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
