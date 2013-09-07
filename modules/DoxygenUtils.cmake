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

set(_doc_format_opts SUBDIR INSTALL_DIR APPEND_TARGET_NAME APPEND_SUBDIR
	CACHE INTERNAL "Internal variable holding documentation format option list")

set(_doc_formats MAN HTML LATEX RTF
	CACHE INTERNAL "List of known documentation formats (currently equivalent to Doxygen-supported formats)")

set(_doc_formats_opts)
foreach (_format ${_doc_formats})
	foreach (_opt ${_doc_format_opts})
		mark_as_advanced(CMAKE_DOC_${_format}_${_opt})
		list(APPEND _doc_formats_opts "${_format}_${_opt}")
	endforeach ()
endforeach ()

set(CMAKE_DOC_DOXYGEN_QUIET 1
	CACHE BOOL "Run doxygen quietly")
set(CMAKE_DOC_DOXYGEN_MAN_SECTION 3
	CACHE BOOL "Run doxygen quietly")
set(_doc_doxygen_opts
	QUIET MAN_SECTION
	CACHE INTERNAL "Internal variable holding list of options relatad to the add_doxygen function")

foreach (_opt ${_doc_doxygen_opts})
	mark_as_advanced(CMAKE_DOC_DOXYGEN_${_opt})
endforeach ()

set(CMAKE_DOC_CREATE_MAIN_TARGET 1
	CACHE BOOL "Automatically create main documantation target if there's not any")
set(CMAKE_DOC_MAIN_TARGET_NAME "doc"
	CACHE STRING "Name of the main documentation target")
set(CMAKE_DOC_MAIN_TARGET_ADD_TO_ALL 1
	CACHE BOOL "Add main documentation to the 'all' target in case of creating")
set(_doc_main_target_opts
	CREATE_MAIN_TARGET MAIN_TARGET_ADD_TO_ALL MAIN_TARGET_NAME
	CACHE INTERNAL "Internal variable holding list of options relatad to the main documentation target")

foreach (_opt ${_doc_main_target_opts})
	mark_as_advanced(CMAKE_DOC_${_opt})
endforeach ()

set(CMAKE_DOC_DOXYGEN_TARGETS_ADD_TO_ALL 1
	CACHE BOOL "Add doxygen main targets to the 'all' target")
set(CMAKE_DOC_DOXYGEN_ADD_MAIN_DEPEND 1
	CACHE BOOL "Add dependency to 'doc' target on each newly-added doxygen target")

mark_as_advanced(
	CMAKE_DOC_DOXYGEN_TARGETS_ADD_TO_ALL
	CMAKE_DOC_DOXYGEN_ADD_MAIN_DEPEND)

# update_doc_target(<options> TARGETS <targets>)
function (update_doc_main_target)
	set(_Options)
	set(_OneValueArgs ${_doc_main_target_opts})
	set(_MultiValueArgs TARGETS)
	cmake_parse_arguments(UDMT
		"${_Options}"
		"${_OneValueArgs}"
		"${_MultiValueArgs}"
		${ARGN})

	foreach (_ova ${_doc_main_target_opts})
		if (NOT DEFINED UDMT_${ova})
			set(UDMT_${_ova} "${CMAKE_DOC_${_ova}}")
		endif ()
	endforeach ()

	if (UDMT_MAIN_TARGET_ADD_TO_ALL)
		set(_all_opt "ALL")
	else ()
		set(_all_opt)
	endif ()

	if (NOT TARGET "${UDMT_MAIN_TARGET_NAME}")
		if (NOT UDMT_CREATE_MAIN_TARGET)
			return()
		endif ()

		add_custom_target("${UDMT_MAIN_TARGET_NAME}" ${_all_opt}
			DEPENDS ${UDMT_TARGETS}
			COMMENT "Main documentation target")
	else ()
		add_dependencies("${UDMT_MAIN_TARGET_NAME}" ${UDMT_TARGETS})
	endif ()
endfunction ()

# add_doxygen(<name of doxygen target> [options])
function (add_doxygen _TARGET_NAME)
	# List of currently supported formats
	set(_formats ${_doc_formats})

	foreach (_format ${_formats})
		foreach (_opt ${_doc_format_opts})
			list(APPEND _format_opts "${_format}_${_opt}")
		endforeach ()
	endforeach ()

	set(_Options ${_formats} ${_install_opts})
	set(_OneValueArgs
		MAN_SECTION TEMPLATE PROJECT_NAME FILES_TARGET_NAME QUIET
		ADD_TO_ALL ADD_TO_MAIN
		${_doc_main_target_opts} ${_format_opts})
	set(_MultiValueArgs TARGETS FILES)
	cmake_parse_arguments(GENERATE_DOXYGEN
		"${_Options}"
		"${_OneValueArgs}"
		"${_MultiValueArgs}"
		${ARGN})

	# Setting options defaults
	foreach (_opt ${_format_opts} ${_doc_main_target_opts} ${_doc_doxygen_opts})
		if (NOT DEFINED GENERATE_DOXYGEN_${_opt})
			set(GENERATE_DOXYGEN_${_opt} "${CMAKE_DOC_${_opt}}")
		endif ()
	endforeach ()

	if (NOT DEFINED GENERATE_DOXYGEN_ADD_TO_ALL)
		set(GENERATE_DOXYGEN_ADD_TO_ALL	"${CMAKE_DOC_DOXYGEN_TARGETS_ADD_TO_ALL}")
	endif ()

	if (NOT DEFINED GENERATE_DOXYGEN_ADD_TO_MAIN)
		set(GENERATE_DOXYGEN_ADD_TO_MAIN "${CMAKE_DOC_DOXYGEN_ADD_MAIN_DEPEND}")
	endif ()

	if (GENERATE_DOXYGEN_TEMPLATE)
		set(_template "${GENERATE_DOXYGEN_TEMPLATE}")
	else ()
		set(_template "${_doxygen_default_template_path}")
	endif ()

	# Constructing hash source - parameters
	set(_param_defaults)
	foreach (_opt ${_OneValueArgs})
		set(_param_defaults "${_param_defaults}|${GENERATE_DOXYGEN_${_opt}}")
	endforeach ()

	# Otherwise changes in configuration but not in sources would not be noticed
	file(SHA256 "${_template}" _template_hash)
	string(SHA256 _marker_hash "${_TARGET_NAME}|${_param_defaults}|${ARGN}|${_template_hash}")

	# Making options used in template doxygen-friendly
	foreach (_opt ${_formats} QUIET)
		if (GENERATE_DOXYGEN_${_opt})
			set(GENERATE_DOXYGEN_${_opt} "YES")
		else ()
			set(GENERATE_DOXYGEN_${_opt} "NO")
		endif ()
	endforeach ()

	set(GENERATE_DOXYGEN_MAN_SECTION ".${GENERATE_DOXYGEN_MAN_SECTION}")
	set(_target_root_dir "${CMAKE_CURRENT_SOURCE_DIR}")

	find_package(Doxygen REQUIRED)

	macro (_doxygen_target)
		set(_output_dir "${_target_dir}/doc/")
		set(_doxyfile_path "${_target_dir}/Doxyfile")

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

		# XXX Hack: also including all implicit include dirs for all enabled
		#     languages. I wish i can append include paths only for those
		#     languages which actually used by the target, but as i understood
		#     CMake provides no ability to retrieve such information (neither
		#     per-target nor per-file basis)
		get_property(_langs GLOBAL PROPERTY ENABLED_LANGUAGES)
		foreach (_lang ${_langs})
			list(APPEND _include_path ${CMAKE_${_lang}_IMPLICIT_INCLUDE_DIRECTORIES})
		endforeach ()

		list(REMOVE_DUPLICATES _include_path)
		string(REPLACE ";" " " _include_path "${_include_path}")

		# Creating target directory
		execute_process(COMMAND "${CMAKE_COMMAND}" -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/${_target}_doxygen.dir")

		# Generating template
		configure_file("${_template}" ${CMAKE_CURRENT_BINARY_DIR}/${_target}_doxygen.dir/Doxyfile)

		string(SHA256 _target_hash "${_marker_hash};${_source_files};${_include_path}")
		set(_marker_path "${_target_dir}/doxygen_build_marker_${_target_hash}")

		add_custom_command(
			OUTPUT "${_marker_path}"
			COMMAND "${DOXYGEN_EXECUTABLE}" ARGS "${_doxyfile_path}"
			COMMAND "${CMAKE_COMMAND}" ARGS -E touch "${_marker_path}"
			DEPENDS ${_sources_list}
			COMMENT "Building doxygen documentation for ${_target}")

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
					set(_install_params)
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
			get_target_property(_headers_list "${_target}" HEADERS)
			if (_headers_list)
				list(APPEND _sources_list ${_headers_list})
			endif ()

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

	if (GENERATE_DOXYGEN_ADD_TO_ALL)
		set(_all_opt "ALL")
	else ()
		set(_all_opt)
	endif ()

	add_custom_target("${_TARGET_NAME}" ${_all_opt} DEPENDS ${_depend_targets})

	if (GENERATE_DOXYGEN_ADD_TO_MAIN)
		set(_udmt_opts)
		foreach (_opt ${_doc_main_target_opts})
			if (DEFINED GENERATE_DOXYGEN_${_opt})
				list(APPEND _udmt_opts ${_opt} "${GENERATE_DOXYGEN_${_opt}}")
			endif ()
		endforeach ()

		update_doc_main_target(${_udmt_opts} TARGETS "${_TARGET_NAME}")
	endif ()
endfunction (add_doxygen _TARGET_NAME)

