include(CMakeParseArguments)
include(PathUtils)

set(JAVA_STD_PATHS
    "/usr/share/java/"
    "/usr/local/share/java/"
    "/usr/lib/java/"
    "/usr/lib/jvm"
    "/usr/lib64/java/"
    "/usr/lib64/jvm"
    "/usr/lib32/java/"
    "/usr/lib32/jvm"
    "/usr/local/lib/java/"
    "/usr/local/lib/jvm/"
    "/usr/local/lib64/java/"
    "/usr/local/lib64/jvm/"
    "/usr/local/lib32/java/"
    "/usr/local/lib32/jvm/"
    # XXX some additional path for eclipse
    "/usr/share/eclipse/"
    "/usr/lib/eclipse/"
    "/usr/lib64/eclipse/"
    "/usr/lib32/eclipse/"
    "/usr/local/share/eclipse/"
    "/usr/local/lib/eclipse/"
    "/usr/local/lib64/eclipse/"
    "/usr/local/lib32/eclipse/"
    CACHE INTERNAL "Java standard search paths for JavaUtil"
    )

# find_java_class(<variable> <class> path1 path2 ...)
function (find_java_class _VAR _CLASS)
    set(_CLASS_FOUND 0)

    set(_find_file_paths
        ${JAVA_STD_PATHS}
        ${Java_JAR_PATHS})
    set(_find_paths
        ${ARGN}
        ${_find_file_paths})
    set(_res_paths)

    string(SHA256 _path_hash "${_find_paths}")

    if (DEFINED _FIND_JAVA_CLASS_CACHE_${_CLASS}_${_path_hash})
        #message(STATUS "Getting path for class ${_CLASS} from cache (Path hash: ${_path_hash}).")

        set(${_VAR} "${_FIND_JAVA_CLASS_CACHE_${_CLASS}_${_path_hash}}" PARENT_SCOPE)

        return ()
    endif ()

    message(STATUS "Looking for java class ${_CLASS}...")
    set(_result_path)

    string(REGEX REPLACE "\\." "/" _needle "${_CLASS}")
    set(_needle "${_needle}.class")

    set(_check_paths "")

    foreach (_PATH ${_find_paths})
        # Absolute - paths with jar/class
        if (IS_ABSOLUTE "${_PATH}")
            if (NOT EXISTS "${_PATH}")
                #message(STATUS "${_PATH} not exists")
            else (NOT EXISTS "${_PATH}")
                if ((IS_DIRECTORY "${_PATH}") AND (EXISTS "${_PATH}"))
                    file(GLOB_RECURSE _files "${_PATH}/*.class" "${_PATH}/*.jar")
                    set(_check_paths ${_check_paths} ${_files})
                else ((IS_DIRECTORY "${_PATH}") AND (EXISTS "${_PATH}"))
                    set(_check_paths ${_check_paths} ${_PATH})
                endif ((IS_DIRECTORY "${_PATH}") AND (EXISTS "${_PATH}"))
            endif (NOT EXISTS "${_PATH}")
        # Relative - jar/class to find
        else (IS_ABSOLUTE "${_PATH}")
            # Try to find in available paths
            set(_res_path)
            find_file(_res_path "${_PATH}" PATHS ${_find_file_paths})

            if (EXISTS "${_res_path}")
                set(_check_paths ${_check_paths} ${_res_path})
            endif (EXISTS "${_res_path}")
        endif (IS_ABSOLUTE "${_PATH}")
    endforeach (_PATH ${_find_paths})

    foreach (_CHECK_PATH ${_check_paths})
        # If file is a class

        ## assuming thre prefix should remain after replace
        string(REPLACE "${_needle}" "" _prefix "${_CHECK_PATH}")

        if ("${_prefix}${_needle}" EQUAL "${_CHECK_PATH}")
            message(STATUS "Found for ${_CLASS}: ${_CHECK_PATH}")
            set(${_VAR} "${_CHECK_PATH}" PARENT_SCOPE) # XXX or ${_prefix} ?
            set(_result_path "${_CHECK_PATH}")
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
                set(_result_path "${_CHECK_PATH}")
                set(_CLASS_FOUND 1)
                break()
            endif ("${_position}" GREATER -1)
        endif ("${_prefix}${_needle}" EQUAL "${_CHECK_PATH}")
    endforeach (_CHECK_PATH ${_check_paths})

    if (NOT _CLASS_FOUND)
        message(STATUS "Class ${_CLASS} NOT found!")
    else ()
        set("_FIND_JAVA_CLASS_CACHE_${_CLASS}_${_path_hash}" "${_result_path}" CACHE INTERNAL "Cached path for class ${_CLASS}")
    endif (NOT _CLASS_FOUND)
endfunction (find_java_class _VAR)

function (add_eclipse_plugin _TARGET_NAME _FEATURE)
    set(_Options LOCAL_FIRST)
    set(_OneValueArgs "")
    set(_MultiValueArgs PATHS DEPS)
    cmake_parse_arguments(AEP
        "${_Options}"
        "${_OneValueArgs}"
        "${_MultiValueArgs}"
        ${ARGN})

    set(_ECLIPSE_PLUGIN_ROOT "${CMAKE_CURRENT_BINARY_DIR}/${_TARGET_NAME}_pdebuild.dir")
    set(_PDE_BUILD_SUBDIR pde)

    set(_ECLIPSE_PLUGIN_BUILD_DIR ${_ECLIPSE_PLUGIN_ROOT}/${_PDE_BUILD_SUBDIR})
    set(_ECLIPSE_PLUGIN_TARGET_OUTPUT_NAME "${_TARGET_NAME}.zip")
    set(_ECLIPSE_PLUGIN_OUTPUT_PATH ${_ECLIPSE_PLUGIN_ROOT}/${_ECLIPSE_PLUGIN_TARGET_OUTPUT_NAME})
    set(_ECLIPSE_PLUGIN_OUTPUT_DIR ${_ECLIPSE_PLUGIN_ROOT}/${_TARGET_NAME}.dir)

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

    file(GLOB_RECURSE ${_TARGET_NAME}_MANIFESTS MANIFEST.MF)

    file(GLOB_RECURSE ${_TARGET_NAME}_SOURCES
        "${CMAKE_CURRENT_SOURCE_DIR}/plugins/*"
        "${CMAKE_CURRENT_SOURCE_DIR}/features/*")

    string(SHA256 _marker_hash "${ARGN}|${${_TARGET_NAME}_SOURCES}|${_PDE_BUILD_EXECUTABLE}|${_UNZIP_EXECUTABLE}")

    set(_dep_paths "")

    foreach(_MANIFEST_PATH ${${_TARGET_NAME}_MANIFESTS})
        find_classpath(_cp_paths "${_MANIFEST_PATH}" ${ARGN})

        get_abs_path(_MANIFEST_ABS_PATH "${_MANIFEST_PATH}" BASE "${CMAKE_CURRENT_SOURCE_DIR}")
        file(RELATIVE_PATH _MANIFEST_REL_PATH "${CMAKE_CURRENT_SOURCE_DIR}" "${_MANIFEST_ABS_PATH}")
        get_abs_path(_MANIFEST_ABS_PATH "${_MANIFEST_REL_PATH}" BASE "${_ECLIPSE_PLUGIN_BUILD_DIR}")
        get_filename_component(_MANIFEST_DIR "${_MANIFEST_ABS_PATH}" PATH)
        string(REGEX REPLACE "/META-INF/?$" "" _MANIFEST_DIR "${_MANIFEST_DIR}")

        foreach (spec ${_cp_paths})
            string(FIND "${spec}" "=" _pos)
            string(SUBSTRING "${spec}" 0 "${_pos}" _libname)
            math(EXPR _pos "${_pos}+1")
            string(SUBSTRING "${spec}" "${_pos}" -1 _src_path)
            get_abs_path(_dst_path "${_libname}" BASE "${_MANIFEST_DIR}")
            string(REPLACE "_" "__" _dst_path_name "${_dst_path}")
            string(REPLACE "/" "_" _dst_path_name "${_dst_path_name}")
            get_filename_component(_dst_dir "${_dst_path}" PATH)

            add_custom_command(
                OUTPUT "${_dst_path}"
                COMMAND "${CMAKE_COMMAND}" -E make_directory
                    "${_dst_dir}"
                COMMAND "${CMAKE_COMMAND}" -E copy
                    "${_src_path}" "${_dst_path}"
                COMMENT "Building ${_TARGET_NAME}.zip - copying ${_src_path} to ${_dst_path}."
                DEPENDS "${_ECLIPSE_PLUGIN_ROOT}/pdebuild_make_build_dir_marker_${_marker_hash}" "${_src_path}"
            )

            list(APPEND _dep_src_paths "${_src_path}")
            list(APPEND _dep_paths "${_dst_path}")
        endforeach (spec ${cp_paths})
    endforeach(_MANIFEST_PATH ${${_TARGET_NAME}_MANIFESTS})

    add_custom_command(
        OUTPUT "${_ECLIPSE_PLUGIN_ROOT}/pdebuild_prepare_marker_${_marker_hash}"
        COMMAND "${CMAKE_COMMAND}" -E remove_directory
            "${_ECLIPSE_PLUGIN_ROOT}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory
            "${_ECLIPSE_PLUGIN_ROOT}"
        COMMAND "${CMAKE_COMMAND}" -E touch
            "${_ECLIPSE_PLUGIN_ROOT}/pdebuild_prepare_marker_${_marker_hash}"
        COMMENT "Preparing to build ${_TARGET_NAME}.zip - recreating build directory."
        DEPENDS ${${_TARGET_NAME}_SOURCES} ${_dep_src_paths}
    )

    add_custom_command(
        OUTPUT "${_ECLIPSE_PLUGIN_ROOT}/pdebuild_make_build_dir_marker_${_marker_hash}"
        COMMAND "${CMAKE_COMMAND}" -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/plugins" "${_ECLIPSE_PLUGIN_BUILD_DIR}/plugins"
        COMMAND "${CMAKE_COMMAND}" -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/features" "${_ECLIPSE_PLUGIN_BUILD_DIR}/features"
        COMMAND "${CMAKE_COMMAND}" -E touch
            "${_ECLIPSE_PLUGIN_ROOT}/pdebuild_make_build_dir_marker_${_marker_hash}"
        COMMENT "Building ${_TARGET_NAME}.zip - copying source directories into build tree."
        DEPENDS "${_ECLIPSE_PLUGIN_ROOT}/pdebuild_prepare_marker_${_marker_hash}" ${AEP_DEPS}
    )

    add_custom_command(
        OUTPUT "${_ECLIPSE_PLUGIN_ROOT}/pdebuild_copy_deps_marker_${_marker_hash}"
        COMMAND "${CMAKE_COMMAND}" -E touch
            "${_ECLIPSE_PLUGIN_ROOT}/pdebuild_copy_deps_marker_${_marker_hash}"
        COMMENT "Building ${_TARGET_NAME}.zip - copying dependencies into builddir."
        DEPENDS "${_ECLIPSE_PLUGIN_ROOT}/pdebuild_make_build_dir_marker_${_marker_hash}" ${_dep_paths}
    )

    add_custom_command(
        OUTPUT "${_ECLIPSE_PLUGIN_OUTPUT_PATH}"
        COMMAND ${_PDE_BUILD_EXECUTABLE}
            -f "${_FEATURE}"
        WORKING_DIRECTORY "${_ECLIPSE_PLUGIN_BUILD_DIR}/"
        COMMAND "${CMAKE_COMMAND}" -E copy
            "${_ECLIPSE_PLUGIN_BUILD_DIR}/build/rpmBuild/${_FEATURE}.zip" "${_ECLIPSE_PLUGIN_OUTPUT_PATH}"
        COMMENT "Building ${_TARGET_NAME}.zip"
        DEPENDS "${_ECLIPSE_PLUGIN_ROOT}/pdebuild_copy_deps_marker_${_marker_hash}"
    )

    add_custom_command(
        OUTPUT "${_ECLIPSE_PLUGIN_ROOT}/pdebuild_unpack_prepare_marker_${_marker_hash}"
        COMMAND "${CMAKE_COMMAND}" -E remove_directory
            "${_ECLIPSE_PLUGIN_OUTPUT_DIR}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory
            "${_ECLIPSE_PLUGIN_OUTPUT_DIR}"
        COMMAND "${CMAKE_COMMAND}" -E touch
            "${_ECLIPSE_PLUGIN_ROOT}/pdebuild_unpack_prepare_marker_${_marker_hash}"
        COMMENT "Building ${_TARGET_NAME} - creating unpack destination dir."
        DEPENDS "${_ECLIPSE_PLUGIN_ROOT}/pdebuild_prepare_marker_${_marker_hash}" "${_ECLIPSE_PLUGIN_OUTPUT_PATH}"
    )

    add_custom_command(
        OUTPUT "${_ECLIPSE_PLUGIN_ROOT}/pdebuild_unpack_marker_${_marker_hash}"
        COMMAND "${_UNZIP_EXECUTABLE}"
            "${_ECLIPSE_PLUGIN_OUTPUT_PATH}"
        WORKING_DIRECTORY "${_ECLIPSE_PLUGIN_OUTPUT_DIR}"
        COMMAND "${CMAKE_COMMAND}" -E touch
            "${_ECLIPSE_PLUGIN_ROOT}/pdebuild_unpack_marker_${_marker_hash}"
        COMMENT "Unpacking ${_TARGET_NAME}.zip."
        DEPENDS "${_ECLIPSE_PLUGIN_ROOT}/pdebuild_unpack_prepare_marker_${_marker_hash}" ${_ECLIPSE_PLUGIN_OUTPUT_PATH}
    )

    add_custom_target(${_TARGET_NAME} ALL
        COMMENT "Building ${_TARGET_NAME} eclipse plugin"
        DEPENDS ${_ECLIPSE_PLUGIN_OUTPUT_PATH} "${_ECLIPSE_PLUGIN_ROOT}/pdebuild_unpack_marker_${_marker_hash}"
    )

    install_eclipse_plugin(${_TARGET_NAME} ${ARGN})
endfunction (add_eclipse_plugin _TARGET_NAME _FEATURE)

function (install_eclipse_plugin _TARGET_NAME)
    set(_Options "")
    set(_OneValueArgs "INSTALL_PATH")
    set(_MultiValueArgs "")
    cmake_parse_arguments(IEP
        "${_Options}"
        "${_OneValueArgs}"
        "${_MultiValueArgs}"
        ${ARGN})

    if (IEP_INSTALL_PATH)
        set(_install_path "${IEP_INSTALL_PATH}")
    else (IEP_INSTALL_PATH)
        set(_install_path "${CMAKE_INSTALL_DATADIR}/eclipse/dropins/${_TARGET_NAME}/")
    endif (IEP_INSTALL_PATH)

    set(_ECLIPSE_PLUGIN_ROOT "${CMAKE_CURRENT_BINARY_DIR}/${_TARGET_NAME}_pdebuild.dir")
    set(_ECLIPSE_PLUGIN_OUTPUT_DIR ${_ECLIPSE_PLUGIN_ROOT}/${_TARGET_NAME}.dir)

    include(GNUInstallDirs)

    install(DIRECTORY "${_ECLIPSE_PLUGIN_OUTPUT_DIR}/eclipse/plugins" DESTINATION "${_install_path}/")
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
        ${JAVA_STD_PATHS}
        ${Java_JAR_PATHS})

    set(_title_message_shown 0)

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
                get_filename_component(_cpitem_name_we "${_cpitem}" NAME_WE)

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
                    foreach (_path ${_find_file_paths})
                        file(GLOB_RECURSE _files "${_path}/${_cpitem_name}" "${_path}/${_cpitem_name_we}-*.jar")
                        if (_files)
                            list(GET _files 0 _file_item)
                            set("${_cpitem_name}_cpitem_path" "${_file_item}")
                            break()
                        endif (_files)
                    endforeach (_path ${_find_file_paths})
                endif (NOT "${_cpitem_name}_cpitem_path")

                if (NOT "${_cpitem_name}_cpitem_path" AND NOT FIND_CLASSPATH_LOCAL_FIRST)
                    if (EXISTS "${_cpitem_abs_path}")
                        set("${_cpitem_name}_cpitem_path" "${_cpitem_abs_path}")
                    endif (EXISTS "${_cpitem_abs_path}")
                endif (NOT "${_cpitem_name}_cpitem_path" AND NOT FIND_CLASSPATH_LOCAL_FIRST)

                if (NOT _title_message_shown)
                    message(STATUS "Searching for classpath for ${_MANIFEST_PATH}:")
                    set(_title_message_shown 1)
                endif (NOT _title_message_shown)

                if (NOT "${_cpitem_name}_cpitem_path")
                    # We should generate error regarding it somewhere
                    message(STATUS "    NOT found ${_cpitem_name}")
                else (NOT "${_cpitem_name}_cpitem_path")
                    message(STATUS "    Found for ${_cpitem_name}: ${${_cpitem_name}_cpitem_path}")
                endif (NOT "${_cpitem_name}_cpitem_path")

                set(_result ${_result} "${_cpitem}=${${_cpitem_name}_cpitem_path}")
            else ("${_cpitem_abs_path}" MATCHES "[.]jar$")
                # We have to find all classes present in existing path

                #if (FIND_CLASSPATH_LOCAL_FIRST)
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
                    set(_FOUND_DEP "_FOUND_DEP-NOTFOUND" CACHE INTERNAL "")
                    find_file(_FOUND_DEP ${_DEP})

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
