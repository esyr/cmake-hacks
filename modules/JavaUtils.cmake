# find_java_class(<variable> <class> path1 path2 ...)
function (find_java_class _VAR _CLASS)
    if ("${_VAR}")
        return()
    endif ("${_VAR}")

    message(STATUS "Looking for java class ${_CLASS}...")

    set(_find_file_paths
        /usr/share/java/
        /usr/local/share/java/
        ${Java_JAR_PATHS})
    set(_find_paths
        ${ARGN}
        ${_find_file_paths})
    set(_res_paths)

    string(REGEX REPLACE "\\." "/" _needle "${_CLASS}")
    set(_needle "${_needle}.class")

    foreach (_PATH ${_find_paths})
        # Absolute - paths with jar/class
        if (IS_ABSOLUTE "${_PATH}")
            if (NOT EXISTS "${_PATH}")
                #message(STATUS "${_PATH} not exists")
                break()
            endif (NOT EXISTS "${_PATH}")

            if ((IS_DIRECTORY "${_PATH}") AND (EXISTS "${_PATH}"))
                file(GLOB_RECURSE _files "${_PATH}/*.class" "${_PATH}/*.jar")
                set(_res_paths ${_res_paths} ${_files})
            else ((IS_DIRECTORY "${_PATH}") AND (EXISTS "${_PATH}"))
                set(_res_paths ${_res_paths} ${_PATH})
            endif ((IS_DIRECTORY "${_PATH}") AND (EXISTS "${_PATH}"))
        # Relative - jar/class to find
        else (IS_ABSOLUTE "${_PATH}")
            # Try to find in available paths
            set(_res_path)
            find_file(_res_path "${_PATH}" PATHS ${_find_file_paths})

            if (EXISTS "${_res_path}")
                set(_res_paths ${_res_paths} ${_res_path})
            endif (EXISTS "${_res_path}")
        endif (IS_ABSOLUTE "${_PATH}")
    endforeach (_PATH ${_find_paths})

    foreach (_CHECK_PATH ${_res_paths})
        # If file is a class

        ## assuming thre prefix should remain after replace
        string(REPLACE "${_needle}" "" _prefix "${_CHECK_PATH}")

        if ("${_prefix}${_needle}" EQUAL "${_CHECK_PATH}")
            set(${_VAR} "${_CHECK_PATH}" PARENT_SCOPE) # XXX or ${_prefix} ?
            break()
        else ("${_prefix}${_needle}" EQUAL "${_CHECK_PATH}")
            # check as if ${_CHECK_PATH} is a jar file
            execute_process(COMMAND ${Java_JAR_EXECUTABLE} tf "${_CHECK_PATH}"
                RESULT_VARIABLE _jar_exitcode
                OUTPUT_VARIABLE _jar_output)

            if (${_jar_exitcode} EQUAL 0)
                #message(STATUS "Checking ${_CHECK_PATH}: ${_jar_output}")
                string(FIND "\n${_jar_output}\n" "\n${_needle}\n" _position)
                if ("${_position}" GREATER -1)
                     set(${_VAR} "${_CHECK_PATH}" PARENT_SCOPE)
                     break()
                endif ("${_position}" GREATER -1)
            else (${_jar_exitcode} EQUAL 0)
                message(WARNING "Error during interpreting ${_CHECK_PATH} as a jar file.")
            endif (${_jar_exitcode} EQUAL 0)
        endif ("${_prefix}${_needle}" EQUAL "${_CHECK_PATH}")
    endforeach (_CHECK_PATH ${_res_paths})
endfunction (find_java_class _VAR)

function (add_eclipse_plugin _TARGET_NAME _FEATURE)
    set(_PDE_BUILD_SUBDIR pde)
    set(_ECLIPSE_PLUGIN_TARGET_OUTPUT_NAME "${_TARGET_NAME}.zip")
    set(_ECLIPSE_PLUGIN_OUTPUT_PATH ${CMAKE_CURRENT_BINARY_DIR}/${_ECLIPSE_PLUGIN_TARGET_OUTPUT_NAME})

    find_program(_PDE_BUILD_EXECUTABLE
        NAMES pdebuild pde-build
        PATHS /usr/lib64/eclipse/buildscripts/
              /usr/lib/eclipse/buildscripts/
              /usr/share/eclipse/buildscripts/
    )

    add_custom_target(
        "${_TARGET_NAME}_pde_dir"
        COMMAND "${CMAKE_COMMAND}" -E remove_directory
        "${CMAKE_CURRENT_BINARY_DIR}/${_PDE_BUILD_SUBDIR}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory
        "${CMAKE_CURRENT_BINARY_DIR}/${_PDE_BUILD_SUBDIR}"
    )

    add_custom_command(
        OUTPUT "${_ECLIPSE_PLUGIN_OUTPUT_PATH}"
        COMMAND "${CMAKE_COMMAND}" -E copy_directory
        "${CMAKE_CURRENT_SOURCE_DIR}/plugins" "${CMAKE_CURRENT_BINARY_DIR}/${_PDE_BUILD_SUBDIR}/plugins"
        COMMAND "${CMAKE_COMMAND}" -E copy_directory
        "${CMAKE_CURRENT_SOURCE_DIR}/features" "${CMAKE_CURRENT_BINARY_DIR}/${_PDE_BUILD_SUBDIR}/features"
        COMMAND ${_PDE_BUILD_EXECUTABLE}
            -f "${_FEATURE}"
	WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${_PDE_BUILD_SUBDIR}/"
        COMMAND "${CMAKE_COMMAND}" -E copy
            "${CMAKE_CURRENT_BINARY_DIR}/${_PDE_BUILD_SUBDIR}/build/rpmBuild/${_FEATURE}.zip" "${_ECLIPSE_PLUGIN_OUTPUT_PATH}"
        COMMENT "Building ${_TARGET_NAME}.zip"
        DEPENDS "${_TARGET_NAME}_pde_dir"
    )

    add_custom_target(${_TARGET_NAME} ALL DEPENDS ${_ECLIPSE_PLUGIN_OUTPUT_PATH})
endfunction (add_eclipse_plugin _TARGET_NAME _FEATURE)
