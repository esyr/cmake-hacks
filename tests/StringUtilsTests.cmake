include(../modules/StringUtils.cmake)

# split() test
function (test_split _strings _chars _min _max _array _empty)
    list(LENGTH ARGN _arg_len)
    math(EXPR _arg_len "${_arg_len} - 1")

    set(_vars)
    foreach (_i RANGE "${_arg_len}")
        set("_var_${_i}")
        list(APPEND _vars "_var_${_i}")
    endforeach ()

    set(_args)

    if (NOT ("${_chars}" STREQUAL ""))
        list(APPEND _args "CHARS" "${_chars}")
    endif ()

    if (NOT ("${_min}" STREQUAL ""))
        list(APPEND _args "MIN_PARTS" "${_min}")
    endif ()

    if (NOT ("${_max}" STREQUAL ""))
        list(APPEND _args "MAX_PARTS" "${_max}")
    endif ()

    if (NOT ("${_array}" STREQUAL ""))
        list(APPEND _args "SPLIT_TO_ARRAY" "${_array}")
    endif ()

    if (NOT ("${_empty}" STREQUAL ""))
        list(APPEND _args "ALLOW_EMPTY_PARTS" "${_empty}")
    endif ()

    split(STRINGS "${_strings}" ${_args} VARS ${_vars})

    message(STATUS "Checking split with strings '${_strings}', chars '${_chars}', min '${_min}', max '${_max}', array '${_array}', empty '${_empty}'...")

    set(_passed 1)
    foreach (_idx RANGE "${_arg_len}")
        list(GET ARGN "${_idx}" _var)
        #message(STATUS "(${_idx}) Comparing '${_var}' with '${_var_${_idx}}'...")
        if (NOT ("${_var}" STREQUAL "${_var_${_idx}}"))
            set(_passed 0)
            break()
        endif ()

        math(EXPR _idx "${_idx} + 1")
    endforeach ()

    if ("${_passed}" EQUAL 1)
        message(STATUS "  ... OK")
    else ()
        message(SEND_ERROR "  ... FAILED!")
    endif ()
endfunction ()

test_split("a:b:c" "" "" "" "" "" "a" "b:c")
test_split("a:b:c" "" "" "0" "" "" "a" "b" "c")
test_split("a:b:c" "" "" "1" "" "" "a:b:c")
test_split("a:b:c" "" "4" "0" "" "" "a" "b" "c" "")
test_split("a:b:c" "=" "" "" "" "" "a:b:c")
test_split("a:b:c=d:e" ":=" "" "" "" "" "a" "b:c=d:e")
test_split("a:b:c=d:e" ":=" "" "0" "" "" "a" "b" "c" "d" "e")
test_split("a::::b:c" ":" "" "" "" "0" "a" "b:c")
test_split("a::::b:::c" ":" "" "" "" "0" "a" "b:::c")
test_split("a::::b:::c" ":" "" "" "" "1" "a" ":::b:::c")
test_split("a::::b:::c" ":" "0" "0" "1" "0" "a\;b\;c")
test_split("a::::b:::c\;d:e:f" ":" "0" "0" "1" "0" "a\;b\;c\;d\;e\;f")
test_split("a::::b:::c\;d:e" ":" "0" "0" "1" "0" "a\;b\;c" "d\;e")
test_split("a::::b:::c\;d:e" ":" "" "" "1" "0" "a\;b:::c" "d\;e")
test_split("a::::b:::c\;d:e" ":" "3" "0" "1" "0" "a\;b\;c" "d\;e\;")
test_split("a::::b:::\;d:e:f::g::e" ":" "3" "0" "0" "0" "a" "b" "" "d" "e" "f::g::e")
test_split("a::::b:::\;d:e:f::g::e\;h:::i" ":" "3" "0" "0" "0" "a" "b" "" "d" "e" "f::g::e\;h:::i")
test_split("a::::b:::c\;d:e" ":" "" "" "1" "0" "a\;b:::c\;d:e")
test_split("a::::b:::c\;d:e" ":" "" "" "0" "0" "a" "b:::c\;d:e")
test_split("a::::b:::c\;d:e" ":" "" "" "0" "1" "a" ":::b:::c\;d:e")

#split("a:b:c" _a _b)
#message("a: ${_a}")
#message("b: ${_b}")
