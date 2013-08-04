set(_doxygen_utils_listfile_dir "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "Current list dir for doxygen utils module. Used for template discovery.")

function (add_doxygen _TARGET_NAME)
	include(GNUInstallDirs)

	set(_formats MAN HTML LATEX RTF)

	set(GENERATE_DOXYGEN_MAN_SUBDIR "man")
	set(GENERATE_DOXYGEN_MAN_INSTALL_DIR "${CMAKE_INSTALL_MANDIR}")
	set(GENERATE_DOXYGEN_MAN_APPEND_TARGET_NAME 0)
	set(GENERATE_DOXYGEN_MAN_APPEND_SUBDIR 0)

	set(GENERATE_DOXYGEN_HTML_SUBDIR "html")
	set(GENERATE_DOXYGEN_HTML_INSTALL_DIR "${CMAKE_INSTALL_DATAROOTDIR}/doc/")
	set(GENERATE_DOXYGEN_HTML_APPEND_TARGET_NAME 1)
	set(GENERATE_DOXYGEN_HTML_APPEND_SUBDIR 1)

	set(GENERATE_DOXYGEN_LATEX_SUBDIR "latex")
	set(GENERATE_DOXYGEN_LATEX_INSTALL_DIR "${CMAKE_INSTALL_DATAROOTDIR}/doc/")
	set(GENERATE_DOXYGEN_LATEX_APPEND_TARGET_NAME 1)
	set(GENERATE_DOXYGEN_LATEX_APPEND_SUBDIR 1)

	set(GENERATE_DOXYGEN_RTF_SUBDIR "rtf")
	set(GENERATE_DOXYGEN_RTF_INSTALL_DIR "${CMAKE_INSTALL_DATAROOTDIR}/doc/")
	set(GENERATE_DOXYGEN_RTF_APPEND_TARGET_NAME 1)
	set(GENERATE_DOXYGEN_RTF_APPEND_SUBDIR 1)

	foreach (_format ${_formats})
		list(APPEND _install_opts "${_formats}_APPEND_TARGET_NAME" "${_formats}_APPEND_SUBDIR")
		list(APPEND _install_ova "${_formats}_INSTALL_DIR" "${_formats}_SUBDIR")
	endforeach ()

	set(_Options ${_formats} ${_install_opts})
	set(_OneValueArgs MAN_SECTION TEMPLATE PROJECT_NAME FILES_TARGET_NAME ${_install_ova})
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
		set(_template "${_doxygen_utils_listfile_dir}/../templates/Doxyfile.template")
	endif ()

	# Otherwise changes in configuration but not in sources would not be noticed
	file(SHA256 "${_template}" _template_hash)
	string(SHA256 _marker_hash "${_TARGET_NAME}|${ARGN}|${_template_hash}")

	# Making format vars in doxygen format
	foreach (_format ${_formats})
		if (GENERATE_DOXYGEN_${_format})
			set(GENERATE_DOXYGEN_${_format} "YES")
		else ()
			set(GENERATE_DOXYGEN_${_format} "NO")
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

		execute_process(COMMAND "${CMAKE_COMMAND}" -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/${_target}_doxygen.dir")

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

			set(_sources_fullpath)
			foreach (_source ${_sources_list})
				get_filename_component(_source "${_source}" ABSOLUTE)
				list(APPEND _sources_fullpath "${_source}")
			endforeach ()

			string(REPLACE ";" " " _source_files "${_sources_fullpath}")

			_doxygen_target()
		endforeach ()
	endif ()

	if (GENERATE_DOXYGEN_FILES)
		set(_target "${GENERATE_DOXYGEN_FILES_TARGET_NAME}")
		set(_target_dir "${CMAKE_CURRENT_BINARY_DIR}/doxygen.dir")
		set(_project_name "${GENERATE_DOXYGEN_PROJECT_NAME}")

		get_target_property(_source_files "${GENERATE_DOXYGEN_FILES}")

		set(_sources_fullpath)
		foreach (_source ${_source_files})
			get_filename_component(_source "${_source}" ABSOLUTE)
			list(APPEND _sources_fullpath "${_source}")
		endforeach ()

		string(REPLACE ";" " " _source_files "${_sources_fullpath}")

		_doxygen_target()
	endif ()

	add_custom_target("${_TARGET_NAME}" ALL DEPENDS ${_depend_targets})
endfunction (add_doxygen _TARGET_NAME)

