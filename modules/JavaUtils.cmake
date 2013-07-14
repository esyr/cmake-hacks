include(CMakeParseArguments)
include(PathUtils)

# find_java_class(<variable> <class> path1 path2 ...)
function (find_java_class _VAR _CLASS)
    set(_CLASS_FOUND 0)

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
            message(STATUS "Found for ${_CLASS}: ${_CHECK_PATH}")
            set(${_VAR} "${_CHECK_PATH}" PARENT_SCOPE) # XXX or ${_prefix} ?
            set(_CLASS_FOUND 1)
            break()
        else ("${_prefix}${_needle}" EQUAL "${_CHECK_PATH}")
            # check as if ${_CHECK_PATH} is a jar file
            if (NOT "_FIND_JAVA_CLASS_JAR_LIST_CACHE_${_CHECK_PATH}")
                execute_process(COMMAND ${Java_JAR_EXECUTABLE} tf "${_CHECK_PATH}"
                    RESULT_VARIABLE _jar_exitcode
                    OUTPUT_VARIABLE _jar_output)

                string(REPLACE "\n" ";" _jar_output "${_jar_output}")

                if (${_jar_exitcode} EQUAL 0)
                    #message(STATUS "Saving listing for ${_CHECK_PATH} to cache.")
                    set("_FIND_JAVA_CLASS_JAR_LIST_CACHE_${_CHECK_PATH}" "${_jar_output}" CACHE INTERNAL "Cache for listing of ${_CHECK_PATH} archive")
                    mark_as_advanced("_FIND_JAVA_CLASS_JAR_LIST_CACHE_${_CHECK_PATH}")
                else (${_jar_exitcode} EQUAL 0)
                    message(WARNING "Error during interpreting ${_CHECK_PATH} as a jar file.")
                endif (${_jar_exitcode} EQUAL 0)
            else (NOT "_FIND_JAVA_CLASS_JAR_LIST_CACHE_${_CHECK_PATH}")
                #message(STATUS "Using cached value for ${_CHECK_PATH}")
            endif (NOT "_FIND_JAVA_CLASS_JAR_LIST_CACHE_${_CHECK_PATH}")

            list(FIND "_FIND_JAVA_CLASS_JAR_LIST_CACHE_${_CHECK_PATH}" "${_needle}" _position)
            if ("${_position}" GREATER -1)
                message(STATUS "Found for ${_CLASS}: ${_CHECK_PATH}")
                set(${_VAR} "${_CHECK_PATH}" PARENT_SCOPE)
                set(_CLASS_FOUND 1)
                break()
            endif ("${_position}" GREATER -1)
        endif ("${_prefix}${_needle}" EQUAL "${_CHECK_PATH}")
    endforeach (_CHECK_PATH ${_res_paths})

    if (NOT _CLASS_FOUND)
        message(STATUS "Class ${_CLASS} NOT found!")
    endif (NOT _CLASS_FOUND)
endfunction (find_java_class _VAR)

function (add_eclipse_plugin _TARGET_NAME _FEATURE)
    set(_PDE_BUILD_SUBDIR pde)
    set(_ECLIPSE_PLUGIN_TARGET_OUTPUT_NAME "${_TARGET_NAME}.zip")
    set(_ECLIPSE_PLUGIN_OUTPUT_PATH ${CMAKE_CURRENT_BINARY_DIR}/${_ECLIPSE_PLUGIN_TARGET_OUTPUT_NAME})
    set(_ECLIPSE_PLUGIN_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/${_TARGET_NAME}_dir)

    find_program(_PDE_BUILD_EXECUTABLE
        NAMES pdebuild pde-build
        PATHS /usr/lib64/eclipse/buildscripts/
              /usr/lib/eclipse/buildscripts/
              /usr/share/eclipse/buildscripts/
    )
    find_program(_UNZIP_EXECUTABLE NAMES unzip)

    if (NOT _PDE_BUILD_EXECUTABLE)
        message(SEND_ERROR "_PDE_BUILD_EXECUTABLE is not set and can't find pdebuild executable myself. Aborting.")
    endif (NOT _PDE_BUILD_EXECUTABLE)

    if (NOT _UNZIP_EXECUTABLE)
        message(SEND_ERROR "_UNZIP_EXECUTABLE is not set and can't find unzip executable myself. Aborting.")
    endif (NOT _UNZIP_EXECUTABLE)

    add_custom_target(
        "${_TARGET_NAME}_prepare"
        COMMAND "${CMAKE_COMMAND}" -E remove_directory
            "${_ECLIPSE_PLUGIN_OUTPUT_DIR}"
        COMMAND "${CMAKE_COMMAND}" -E remove_directory
            "${CMAKE_CURRENT_BINARY_DIR}/${_PDE_BUILD_SUBDIR}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory
            "${CMAKE_CURRENT_BINARY_DIR}/${_PDE_BUILD_SUBDIR}"
        COMMENT "Preparing to build ${_TARGET_NAME}.zip - recreating build directory."
    )

    file(GLOB_RECURSE ${_TARGET}_SOURCES
        "${CMAKE_CURRENT_SOURCE_DIR}/plugins/*"
        "${CMAKE_CURRENT_SOURCE_DIR}/features/*")

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
        DEPENDS "${_TARGET_NAME}_prepare" ${${_TARGET}_SOURCES}
        COMMENT "Building ${_TARGET_NAME}.zip"
    )

    add_custom_target(
        "${_TARGET_NAME}_unpack_prepare"
        COMMAND "${CMAKE_COMMAND}" -E make_directory
            "${_ECLIPSE_PLUGIN_OUTPUT_DIR}"
        DEPENDS "${_TARGET_NAME}_prepare"
        COMMENT "Creating ${_TARGET_NAME} unpack destination dir."
    )

    add_custom_target(
        "${_TARGET_NAME}_unpack"
        COMMAND "${_UNZIP_EXECUTABLE}"
            "${_ECLIPSE_PLUGIN_OUTPUT_PATH}"
        WORKING_DIRECTORY "${_ECLIPSE_PLUGIN_OUTPUT_DIR}"
        DEPENDS "${_TARGET_NAME}_unpack_prepare" ${_ECLIPSE_PLUGIN_OUTPUT_PATH}
        COMMENT "Unpacking ${_TARGET_NAME}.zip."
    )

    add_custom_target(${_TARGET_NAME} ALL
        DEPENDS ${_ECLIPSE_PLUGIN_OUTPUT_PATH} "${_TARGET_NAME}_unpack"
    )

    install_eclipse_plugin(${_TARGET_NAME})
endfunction (add_eclipse_plugin _TARGET_NAME _FEATURE)

function (install_eclipse_plugin _TARGET_NAME)
    set(_ECLIPSE_PLUGIN_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/${_TARGET_NAME}_dir)

    include(GNUInstallDirs)

    install(DIRECTORY "${_ECLIPSE_PLUGIN_OUTPUT_DIR}/eclipse/plugins" DESTINATION "${CMAKE_INSTALL_DATADIR}/eclipse/dropins/${_TARGET_NAME}/")
endfunction (install_eclipse_plugin _TARGET_NAME)

function (get_classpath _VAR _MANIFEST_PATH)
    execute_process(
        COMMAND awk
            "/^[ \t]*Bundle-ClassPath[ \t]*:[ \t]*/ {
                start=1;
                gsub(\"^[ \t]*Bundle-ClassPath[ \t]*:[ \t]*\", \"\");
            }
            (start == 1) {
                pr=$0;
                n = split(pr, pr_items, \"[ \t]*,[ \t]*\");
                for (i = 1; i<=n; i++)
                {
                    if (pr_items[i])
                    {
                        sub(\"^[ \t]*\", \"\", pr_items[i]);
                        sub(\"[ \t]*$\", \"\", pr_items[i]);
                        print pr_items[i];
                    }
                }
           }
           /[^,][ \t]*$/ {
               start=0
           }" "${_MANIFEST_PATH}"
        OUTPUT_VARIABLE _OUT
        RESULT_VARIABLE _RES
    )

    if ("${_RES}" EQUAL 0)
        string(REPLACE "\n" ";" _OUT "${_OUT}")
        set(${_VAR} "${_OUT}" PARENT_SCOPE)
    endif ("${_RES}" EQUAL 0)
endfunction (get_classpath _VAR _MANIFEST_PATH)

# Searches for local classpath classes and jars in system and other directories.
# Paths examined in the following order:
#  - Manifest path (if LOCAL_FIRST option provided)
#  - Provided path
#  - System path
#  - Manifest path (if LOCAL_FIRST option not provided; default)
#
# _VAR contains list of <name>=<value> records as a result.
function (find_classpath _VAR _MANIFEST_PATH)
    set(_Options "LOCAL_FIRST")
    set(_OneValueArgs "")
    set(_MultiValueArgs "PATHS")
    cmake_parse_arguments(FIND_CLASSPATH
        "${_Options}"
        "${_OneValueArgs}"
        "${_MultiValueArgs}"
        ${ARGN})

    set(_find_file_paths
        ${FIND_CLASSPATH_PATHS}
        /usr/share/java/
        /usr/local/share/java/
        ${Java_JAR_PATHS})

    set(_classpath "")
    get_classpath(_classpath "${_MANIFEST_PATH}")
    get_abs_path(_MANIFEST_ABS_PATH "${_MANIFEST_PATH}" BASE "${CMAKE_CURRENT_SOURCE_DIR}")
    get_filename_component(_MANIFEST_DIR "${_MANIFEST_ABS_PATH}" PATH)
    string(REGEX REPLACE "/META-INF/?$" "" _MANIFEST_DIR "${_MANIFEST_DIR}")

    foreach (_cpitem ${_classpath})
        get_abs_path(_cpitem_abs_path "${_cpitem}" BASE "${_MANIFEST_DIR}")

        string(FIND "${_cpitem_abs_path}" "${_MANIFEST_DIR}" _pos)
        if ("${_pos}" EQUAL 0)
            if ("${_cpitem_abs_path}" MATCHES "[.]jar$")
                # We have just to find file
                get_filename_component(_cpitem_name "${_cpitem}" NAME)

                set("${_cpitem_name}_cpitem_path" "${_cpitem_name}_cpitem_path-NOTFOUND" CACHE INTERNAL "")

                if (FIND_CLASSPATH_LOCAL_FIRST)
                    if (EXISTS "${_cpitem_abs_path}")
                        set("${_cpitem_name}_cpitem_path" "${_cpitem_abs_path}")
                    endif (EXISTS "${_cpitem_abs_path}")
                endif (FIND_CLASSPATH_LOCAL_FIRST)

                if (NOT "${_cpitem_name}_cpitem_path")
                    foreach (_path ${_find_file_paths})
                        get_filename_component(_fn "${_path}" NAME)

                        if ("${_fn}" STREQUAL "${_cpitem_name}")
                            set("${_cpitem_name}_cpitem_path" "${_path}")
                            break()
                        endif ("${_fn}" STREQUAL "${_cpitem_name}")
                    endforeach (_path ${_find_file_paths})
                endif (NOT "${_cpitem_name}_cpitem_path")

                if (NOT "${_cpitem_name}_cpitem_path")
                    find_file("${_cpitem_name}_cpitem_path" "${_cpitem_name}"
                        PATHS ${_find_file_paths})
                endif (NOT "${_cpitem_name}_cpitem_path")

                if (NOT "${_cpitem_name}_cpitem_path" AND NOT FIND_CLASSPATH_LOCAL_FIRST)
                    if (EXISTS "${_cpitem_abs_path}")
                        set("${_cpitem_name}_cpitem_path" "${_cpitem_abs_path}")
                    endif (EXISTS "${_cpitem_abs_path}")
                endif (NOT "${_cpitem_name}_cpitem_path" AND NOT FIND_CLASSPATH_LOCAL_FIRST)

                set(_result ${_result} "${_cpitem}=${${_cpitem_name}_cpitem_path}")
            else ("${_cpitem_abs_path}" MATCHES "[.]jar$")
                # We have to find all classes present in existing path

                #if (FIND_CLASSiPATH_LOCAL_FIRST)
                #    find_file()
                #endif (FIND_CLASSPATH_LOCAL_FIRST)
            endif ("${_cpitem_abs_path}" MATCHES "[.]jar$")
        endif ("${_pos}" EQUAL 0)
    endforeach (_cpitem ${_classpath})

    set(${_VAR} "${_result}" PARENT_SCOPE)
endfunction (find_classpath _VAR _MANIFEST_PATH)

function (generate_manifests _PATH)
    file(GLOB_RECURSE _MANIFESTS RELATIVE "${_PATH}" "MANIFEST.MF")

    foreach (_MF ${_MANIFESTS})
        if ("${_MF}" MATCHES ".*/META-INF/MANIFEST_MF")
            set(_RES_CP "")
            get_classpath(_MF_CP "${_MF}")

            foreach (_CP_ITEM ${MF_CP})
                string(REGEX MATCH "[^/\]*\.(jar|class)" _DEP "${_CP_ITEM}")

                if (_DEP)
                    set(_FOUND_DEP "")
                    find_java_class(_FOUND_DEP _DEP)

                    if (_FOUND_DEP)
                        set(_CP_ITEM "${_FOUND_DEP}")
                    else (_FOUND_DEP)
                        set(_CP_ITEM "${_DEP}")
                    endif (_FOUND_DEP)
                endif (_DEP)

                if (_RES_CP)
                    set(_RES_CP "${_RES_CP}, ${_CP_ITEM}")
                else (_RES_CP)
                    set(_RES_CP "${_CP_ITEM}")
                endif (_RES_CP)
            endforeach (_CP_ITEM ${MF_CP})

            string(MATCH ".*/" _MANIFEST_DIR "${CMAKE_CURRENT_BINARY_DIR}/${_MANIFEST_PATH}")
            execute_process(
                COMMAND "${CMAKE_COMMAND}" -E make_directory "${_MANIFEST_DIR}"
            )

            if (_RES_CP)
                execute_process(
                    COMMAND awk "" "${_MANIFEST_PATH}"
                    OUTPUT_FILE "${CMAKE_CURRENT_BINARY_DIR}/${_MANIFEST_PATH}"
                )
            endif (_RES_CP)
        endif ("${_MF}" MATCHES ".*/META-INF/MANIFEST_MF")
    endforeach (_MF ${_MANIFESTS})
endfunction (generate_manifests _PATH)

function (get_import_list _VAR)
    execute_process(
        COMMAND awk "
            BEGIN {
                FS=\";\"; ORS=\";\"
            }
            /import/{
                for (i = 1; i <= NF; i++) {
                    if (\$i ~ /^[ \t]*import[ \t]+([^ ]+)[ \t]*$/) {
                        sub(\"^[ \t]*import[ \t]+\", \"\", $i);
                        print $i;
                    }
                }
            }" ${ARGN}
        OUTPUT_VARIABLE _OUT
        RESULT_VARIABLE _RES
    )

    if (_RES EQUAL 0)
        list(REMOVE_DUPLICATES _OUT)

        set(${_VAR} "${_OUT}" PARENT_SCOPE)
    endif (_RES EQUAL 0)
endfunction (get_import_list)
