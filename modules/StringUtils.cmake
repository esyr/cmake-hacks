# Some general string utilities.

# XXX: there is "XXX_" prefix in if() statements in order to evade pre-3.1
#      autodereferencing (see
#      http://public.kitware.com/Bug/print_bug_page.php?bug_id=8226 )

include(CMakeParseArguments)

set(CMAKE_STRING_UTILS_SPLIT_CHARS ":" CACHE INTERNAL
    "Character used for splitting by split by default")
set(CMAKE_STRING_UTILS_SPLIT_MIN_PARTS "2" CACHE INTERNAL
    "Mimimum parts count in string.")
set(CMAKE_STRING_UTILS_SPLIT_MAX_PARTS "2" CACHE INTERNAL
    "Maximum parts count in string.")
set(CMAKE_STRING_UTILS_SPLIT_SPLIT_TO_ARRAY "0" CACHE INTERNAL
    "Whether split() stores result to variables as arrays instead of separate parts")
set(CMAKE_STRING_UTILS_SPLIT_ALLOW_EMPTY_PARTS "1" CACHE INTERNAL
    "Whether empty parts allowed in split()")

# Escapes string making it usable as a literal part of regular expression
function (escape_regex _string _out_var)
    string(REGEX REPLACE "([()\\.*+?^{}$]|\\[|\\])" "\\\\\\1" _res
        "${_string}")

    set("${_out_var}" "${_res}" PARENT_SCOPE)
endfunction ()

# Converts a string to a list of chars
function (string_to_list _string _list_var)
    string(REGEX REPLACE "." "\0;" _res "${_string}")
    string(REGEX REPLACE ";$" "" _res "${_res}")

    set("${_list_var}" "${_res}" PARENT_SCOPE)
endfunction ()

# split(
#   [STRINGS] <list of strings>
#   [CHARS <chars>]
#   [VARS <list of variables>]
#   [MIN_PARTS <minimum split parts count>]
#   [MAX_PARTS <maximum split parts count>]
#   [SPLIT_TO_ARRAY <0|1>]
#   [ALLOW_EMPTY_PARTS <0|1>]
#   <variable> [<variable> ...])
#
# Splits strings with chars, up to MAX_PARTS parts, and stores produced parts to
# variables.
#
# STRING - list of strings to split.
# CHARS - list of chars used as separators.
# MIN_PARTS - Minimum parts a string can contain. If string contains parts less
#             than MIN_PARTS, empty values are stored in the variables.
# MAX_PARTS - Maximum parts a string can contain. Remainder of the string is
#             stored as is.
# SPLIT_TO_ARRAY - parts are stored as array items in variables instead of
#                  storing one part per variable. Parts of each string are
#                  stored in a separate variable (until there are spare
#                  variables; remaining parts are stored as array items in the
#                  last variable)
# ALLOW_EMPTY_PARTS - whether empty parts (created by two consequent split
#                     chars) allowed.
function (split)
    set(_opts)
    set(_ova "CHARS" "MIN_PARTS" "MAX_PARTS" "SPLIT_TO_ARRAY"
        "ALLOW_EMPTY_PARTS")
    set(_multi "STRINGS" "VARS")

    foreach (_var ${_opts} ${_ova} ${_multi})
        unset("SPLIT_${_var}")
    endforeach ()

    cmake_parse_arguments("SPLIT" "${_opts}" "${_ova}" "${_multi}" ${ARGN})

    if (NOT DEFINED SPLIT_STRINGS)
        list(GET SPLIT_UNPARSED_ARGUMENTS 0 SPLIT_STRINGS)
        list(REMOVE_AT SPLIT_UNPARSED_ARGUMENTS 0)
    endif ()

    foreach (_opt "CHARS" "MIN_PARTS" "MAX_PARTS" "SPLIT_TO_ARRAY"
        "ALLOW_EMPTY_PARTS")
        if (NOT DEFINED "SPLIT_${_opt}")
            set("SPLIT_${_opt}" "${CMAKE_STRING_UTILS_SPLIT_${_opt}}")
        endif ()
    endforeach ()

    list(APPEND SPLIT_VARS ${SPLIT_UNPARSED_ARGUMENTS})
    list(LENGTH SPLIT_VARS _var_count)
    math(EXPR _var_last "(${_var_count}) - 1")

    # We can't do anything if there's no output
    if ("${_var_count}" LESS 1)
        return()
    endif ()

    string(LENGTH "${SPLIT_CHARS}" _chars_len)
    math(EXPR _chars_last "(${_chars_len}) - 1")
    set(_chars_regex "(")

    # Constructing regular expression matching any of the SPLIT_CHARS
    foreach (_i RANGE ${_chars_last})
        string(SUBSTRING "${SPLIT_CHARS}" ${_i} 1 _char)
        escape_regex("${_char}" _char)
        set(_chars_regex "${_chars_regex}${_char}")

        if ("XXX_${_chars_last}" STREQUAL "XXX_${_i}")
            set(_chars_regex "${_chars_regex})")
        else ()
            set(_chars_regex "${_chars_regex}|")
        endif ()
    endforeach ()

    set(_var_idx 0)

    list(GET SPLIT_VARS "${_var_idx}" _var)
    set(_var_val)
    set(_part_count 0)

    foreach (_str ${SPLIT_STRINGS})
        if (("${_var_idx}" LESS "${_var_last}") OR (NOT DEFINED _var_val))
            set(_part_count 0)
        endif ()
        set(_dumped 0)
        string(LENGTH "${_str}" _str_len)
        set(_prev_split_char "")
        set(_split_char "")

        while (1)
            if ((("XXX_${_str}" STREQUAL "XXX_") AND
                (NOT ("${_part_count}" LESS "${SPLIT_MIN_PARTS}"))) OR
                (("${SPLIT_MAX_PARTS}" GREATER 0) AND
                (NOT ("${_part_count}" LESS "${SPLIT_MAX_PARTS}"))) OR
                (("${_dumped}" EQUAL 0) AND
                NOT ("${_var_idx}" LESS "${_var_last}") AND (DEFINED _var_val)
                AND (NOT "${SPLIT_SPLIT_TO_ARRAY}")))
                if (("${_dumped}" EQUAL 0) AND
                    NOT ("${_var_idx}" LESS "${_var_last}"))
                    set(_var_val "${_var_val};${_str}")
                endif ()

                break()
            endif ()

            string(REGEX MATCH "${_chars_regex}.*$" _cdr "${_str}")
            string(LENGTH "${_cdr}" _cdr_len)

            math(EXPR _part_len "${_str_len} - ${_cdr_len}")
            string(SUBSTRING "${_str}" 0 "${_part_len}" _part)

            set(_prev_split_char "${_split_char}")
            if ("${_cdr_len}" GREATER 0)
                string(SUBSTRING "${_cdr}" 0 1 _split_char)
                string(SUBSTRING "${_cdr}" 1 -1 _cdr)
                math(EXPR _cdr_len "${_cdr_len} - 1")
            else ()
                set(_split_char "")
            endif ()

            if (NOT ("${_var_idx}" LESS "${_var_last}") AND (DEFINED _var_val)
                AND NOT ("${SPLIT_SPLIT_TO_ARRAY}"))
                set(_var_val "${_var_val}${_prev_split_char}${_part}${_split_char}${_cdr}")

                break()
            endif ()

            if (("${_part_len}" GREATER 0) OR ("${SPLIT_ALLOW_EMPTY_PARTS}") OR
                (("XXX_${_str}" STREQUAL "XXX_") AND
                ("${_part_count}" LESS "${SPLIT_MIN_PARTS}")))
                if ("${SPLIT_SPLIT_TO_ARRAY}")
                    list(APPEND _var_val "${_part}")
                else ()
                    if (DEFINED _var_val)
                        set(_var_val "${_var_val}${_prev_split_char}${_part}")
                    else ()
                        set(_var_val "${_part}")
                    endif ()
                endif ()

                set(_dumped 1)

                math(EXPR _part_count "${_part_count} + 1")

                if (("${SPLIT_MAX_PARTS}" GREATER 0) AND
                    NOT ("${_part_count}" LESS "${SPLIT_MAX_PARTS}"))
                    # Dumping the rest to the var
                    set(_var_val "${_var_val}${_split_char}${_cdr}")
                endif ()

                if (("${_var_idx}" LESS "${_var_last}") AND
                    (NOT ("${SPLIT_SPLIT_TO_ARRAY}") OR
                    (("${SPLIT_MAX_PARTS}" GREATER 0) AND
                    NOT ("${_part_count}" LESS "${SPLIT_MAX_PARTS}"))
                    OR (("XXX_${_cdr}" STREQUAL "XXX_") AND
                    NOT ("${_part_count}" LESS "${SPLIT_MIN_PARTS}"))))
                    set("${_var}" "${_var_val}" PARENT_SCOPE)

                    math(EXPR _var_idx "${_var_idx} + 1")

                    list(GET SPLIT_VARS "${_var_idx}" _var)
                    unset(_var_val)
                endif ()
            endif ()

            set(_str "${_cdr}")
            set(_str_len "${_cdr_len}")
        endwhile ()
    endforeach ()

    if ("${_var_idx}" EQUAL "${_var_last}")
        set("${_var}" "${_var_val}" PARENT_SCOPE)
    endif ()
endfunction ()
