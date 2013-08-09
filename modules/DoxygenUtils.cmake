include(GNUInstallDirs)

set(_doxygen_utils_listfile_dir "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "Current list dir for doxygen utils module. Used for template discovery.")
set(_doxygen_default_template_path "${_doxygen_utils_listfile_dir}/../templates/Doxyfile.template" CACHE INTERNAL "Path to default doxygen configuration template")

# Some default documentation-related options
set(CMAKE_DOC_MAN_SUBDIR "man"
	CACHE STRING "Subdirectory for storing generated manpages")
set(CMAKE_DOC_MAN_INSTALL_DIR "${CMAKE_INSTALL_MANDIR}"
	CACHE PATH "Installation directory for manpages")
set(CMAKE_DOC_MAN_APPEND_TARGET_NAME 0
	CACHE BOOL "Append target name to the manpages documentation installation path")
set(CMAKE_DOC_MAN_APPEND_SUBDIR 0
	CACHE BOOL "Append manpages subdir set to the documentation installation path")

set(CMAKE_DOC_HTML_SUBDIR "html"
	CACHE STRING "Subdirectory for storing generated HTML help files")
set(CMAKE_DOC_HTML_INSTALL_DIR "${CMAKE_INSTALL_DATAROOTDIR}/doc/"
	CACHE PATH "Installation directory for HTML help files")
set(CMAKE_DOC_HTML_APPEND_TARGET_NAME 1
	CACHE BOOL "Append target name to the HTML documentation installation path")
set(CMAKE_DOC_HTML_APPEND_SUBDIR 1
	CACHE BOOL "Append HTML subdir to the documentation installation path")

set(CMAKE_DOC_LATEX_SUBDIR "latex"
	CACHE STRING "Subdirectory for storing generated LaTeX documentation files")
set(CMAKE_DOC_LATEX_INSTALL_DIR "${CMAKE_INSTALL_DATAROOTDIR}/doc/"
	CACHE PATH "Installation directory for LaTeX documentation")
set(CMAKE_DOC_LATEX_APPEND_TARGET_NAME 1
	CACHE BOOL "Append target name to the LaTeX documentation installation path")
set(CMAKE_DOC_LATEX_APPEND_SUBDIR 1
	CACHE BOOL "Append LaTeX subdir to the documentation installation path")

set(CMAKE_DOC_RTF_SUBDIR "rtf"
	CACHE STRING "Subdirectory for storing generated RTF documentation")
set(CMAKE_DOC_RTF_INSTALL_DIR "${CMAKE_INSTALL_DATAROOTDIR}/doc/"
	CACHE PATH "Installation directory for RTF documentation")
set(CMAKE_DOC_RTF_APPEND_TARGET_NAME 1
	CACHE BOOL "Append target name to the RTF documentation installation path")
set(CMAKE_DOC_RTF_APPEND_SUBDIR 1
	CACHE BOOL "Append RTF subdir to the documentation installation path")

set(CMAKE_DOC_DOXYGEN_QUIET 1
	CACHE BOOL "Run doxygen quietly")

foreach (_format MAN HTML LATEX RTF)
	foreach (_opt SUBDIR INSTALL_DIR APPEND_TARGET_NAME APPEND_SUBDIR)
		mark_as_advanced(CMAKE_DOC_${_format}_${_opt})
	endforeach ()
endforeach ()


# add_doxygen(<name of doxygen target> [options])
function (add_doxygen _TARGET_NAME)
	# List of currently supported formats
	set(_formats MAN HTML LATEX RTF)

	# Setting format defaults
	set(_param_defaults)
	foreach (_format ${_formats})
		foreach (_opt SUBDIR INSTALL_DIR APPEND_TARGET_NAME APPEND_SUBDIR)
			set(GENERATE_DOXYGEN_${_format}_${_opt} "${CMAKE_DOC_${_format}_${_opt}}")
			set(_param_defaults "${_param_defaults}|${CMAKE_DOC_${_format}_${_opt}}")
		endforeach ()
	endforeach ()

	foreach (_format ${_formats})
		list(APPEND _install_opts "${_formats}_APPEND_TARGET_NAME" "${_formats}_APPEND_SUBDIR")
		list(APPEND _install_ova "${_formats}_INSTALL_DIR" "${_formats}_SUBDIR")
	endforeach ()

	set(_Options ${_formats} ${_install_opts})
	set(_OneValueArgs MAN_SECTION TEMPLATE PROJECT_NAME FILES_TARGET_NAME ${_install_ova} QUIET)
	set(_MultiValueArgs TARGETS FILES)
	cmake_parse_arguments(GENERATE_DOXYGEN
		"${_Options}"
		"${_OneValueArgs}"
		"${_MultiValueArgs}"
		${ARGN})

	find_package(Doxygen REQUIRED)

	if (GENERATE_DOXYGEN_TEMPLATE)
		set(_template "${GENERATE_DOXYGEN_TEMPLATE}")
	else ()
		set(_template "${_doxygen_default_template_path}")
	endif ()

	if (NOT DEFINED GENERATE_DOXYGEN_QUIET)
		set(GENERATE_DOXYGEN_QUIET "${CMAKE_DOC_DOXYGEN_QUIET}")
	endif ()

	# Otherwise changes in configuration but not in sources would not be noticed
	file(SHA256 "${_template}" _template_hash)
	string(SHA256 _marker_hash "${_TARGET_NAME}|${_param_defaults}|${ARGN}|${_template_hash}")

	# Making format vars in doxygen format
	foreach (_opt ${_formats} QUIET)
		if (GENERATE_DOXYGEN_${_opt})
			set(GENERATE_DOXYGEN_${_opt} "YES")
		else ()
			set(GENERATE_DOXYGEN_${_opt} "NO")
		endif ()
	endforeach ()

	if (NOT GENERATE_DOXYGEN_MAN_SECTION)
		set(GENERATE_DOXYGEN_MAN_SECTION "3")
	endif ()

	set(GENERATE_DOXYGEN_MAN_SECTION ".${GENERATE_DOXYGEN_MAN_SECTION}")
	set(_target_root_dir "${CMAKE_CURRENT_SOURCE_DIR}")

	macro (_doxygen_target)
		set(_output_dir "${_target_dir}/doc/")
		set(_doxyfile_path "${_target_dir}/Doxyfile")
		set(_marker_path "${_target_dir}/doxygen_build_marker_${_marker_hash}")

		# Processing sources list
		set(_sources_fullpath)
		foreach (_source ${_sources_list})
			get_filename_component(_source "${_source}" ABSOLUTE)
			list(APPEND _sources_fullpath "${_source}")
		endforeach ()

		string(REPLACE ";" " " _source_files "${_sources_fullpath}")

		# Processing include dirs
		foreach (_include ${_include_dirs})
			get_filename_component(_include_dir "${_include}" REALPATH)
			list(APPEND _include_path "${_include_dir}")
		endforeach ()
		list(REMOVE_DUPLICATES _include_path)
		string(REPLACE ";" " " _include_path "${_include_path}")

		# Creating target directory
		execute_process(COMMAND "${CMAKE_COMMAND}" -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/${_target}_doxygen.dir")

		# Generating template
		configure_file("${_template}" ${CMAKE_CURRENT_BINARY_DIR}/${_target}_doxygen.dir/Doxyfile)

		add_custom_command(
			OUTPUT "${_marker_path}"
			COMMAND "${DOXYGEN_EXECUTABLE}" ARGS "${_doxyfile_path}"
			COMMAND "${CMAKE_COMMAND}" ARGS -E touch "${_marker_path}"
			DEPENDS ${_sources_list}
		)

		list(APPEND _depend_targets "${_marker_path}")

		foreach (_format ${_formats})
			if ("${GENERATE_DOXYGEN_${_format}}" STREQUAL "YES")
				if (GENERATE_DOXYGEN_${_format}_APPEND_TARGET_NAME)
					set(_install_dir "${GENERATE_DOXYGEN_${_format}_INSTALL_DIR}/${_target}/")
				else ()
					set(_install_dir "${GENERATE_DOXYGEN_${_format}_INSTALL_DIR}/")
				endif ()

				if (GENERATE_DOXYGEN_${_format}_APPEND_SUBDIR)
					set(_src_dir "${_output_dir}/${GENERATE_DOXYGEN_${_format}_SUBDIR}")
				else ()
					set(_src_dir "${_output_dir}/${GENERATE_DOXYGEN_${_format}_SUBDIR}/")
				endif ()

				# XXX Hack for excluding generated directories from installation
				if ("${_format}" STREQUAL "MAN")
					set(_install_params PATTERN "*${GENERATE_DOXYGEN_MAN_SECTION}" PATTERN "d[0-9a-f]" EXCLUDE PATTERN "d[0-9a-f][0-9a-f]" EXCLUDE)
				else ()
					set(_install_params "")
				endif ()

				install(DIRECTORY "${_src_dir}" DESTINATION "${_install_dir}" ${_install_params})
			endif ()
		endforeach ()

	endmacro (_doxygen_target)

	if (GENERATE_DOXYGEN_TARGETS)
		foreach (_target ${GENERATE_DOXYGEN_TARGETS})
			set(_target_dir "${CMAKE_CURRENT_BINARY_DIR}/${_target}_doxygen.dir")
			set(_project_name "${GENERATE_DOXYGEN_PROJECT_NAME}")

			if (NOT _project_name)
				set(_project_name "${_target}")
			endif ()

			get_target_property(_sources_list "${_target}" SOURCES)
			get_target_property(_include_dirs "${_target}" INCLUDE_DIRECTORIES)

			_doxygen_target()
		endforeach ()
	endif ()

	if (GENERATE_DOXYGEN_FILES)
		set(_target "${GENERATE_DOXYGEN_FILES_TARGET_NAME}")
		set(_target_dir "${CMAKE_CURRENT_BINARY_DIR}/doxygen.dir")
		set(_project_name "${GENERATE_DOXYGEN_PROJECT_NAME}")

		set(_sources_list "${GENERATE_DOXYGEN_FILES}")
		get_directory_property(_include_dirs "${CMAKE_CURRENT_SOURCE_DIR}" INCLUDE_DIRECTORIES)

		_doxygen_target()
	endif ()

	add_custom_target("${_TARGET_NAME}" ALL DEPENDS ${_depend_targets})
endfunction (add_doxygen _TARGET_NAME)

