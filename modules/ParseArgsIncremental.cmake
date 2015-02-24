# PARSE_ARGS_INCREMENTAL(<prefix> <options> <one_value_keywords>
#   <multi_value_keywords> <callback> args...)
#
# Based on CMAKE_PARSE_ARGUMENTS (CMakeParseArguments.cmake) from the CMake 2.8
# distribution. Please refer to its documentation for information on general
# usage.
#
# Two changes implemented over original version:
#  * (not really a feature) Possible variable name clash avoided.
#  * Added ability to call callback for each parsed variable. Callback is called
#    via variable_watch() hack: it is associated with _update_arg variable,
#    which is set to "${currentArgName}=${currentArg}" value on every parsed
#    argument value; please refer to function's source to understand how to make
#    this useful (one can update parent scope's _optionNames/_singleArgNames/
#    _multiArgNames, for example)

#=============================================================================
# Copyright 2010 Alexander Neundorf <neundorf@kde.org>
# Copyright 2015 Eugene Syromyatnikov <evgsyr@gmail.com>
#
# Original file is a part of CMake software, which is distributed under the
# following license:
#
#=============================================================================
# CMake - Cross Platform Makefile Generator
# Copyright 2000-2015 Kitware, Inc.
# Copyright 2000-2011 Insight Software Consortium
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# * Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
#
# * Neither the names of Kitware, Inc., the Insight Software Consortium,
#   nor the names of their contributors may be used to endorse or promote
#   products derived from this software without specific prior written
#   permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# ------------------------------------------------------------------------------
#
# The above copyright and license notice applies to distributions of
# CMake in source and binary form.  Some source files contain additional
# notices of original copyright by their contributors; see each source
# for details.  Third-party software packages supplied with CMake under
# compatible licenses provide their own copyright notices documented in
# corresponding subdirectories.
#
# ------------------------------------------------------------------------------
#
# CMake was initially developed by Kitware with the following sponsorship:
#
#  * National Library of Medicine at the National Institutes of Health
#    as part of the Insight Segmentation and Registration Toolkit (ITK).
#
#  * US National Labs (Los Alamos, Livermore, Sandia) ASC Parallel
#    Visualization Initiative.
#
#  * National Alliance for Medical Image Computing (NAMIC) is funded by the
#    National Institutes of Health through the NIH Roadmap for Medical Research,
#    Grant U54 EB005149.
#
#  * Kitware, Inc.
#=============================================================================


function (PARSE_ARGS_INCREMENTAL prefix _optionNames _singleArgNames
  _multiArgNames _updateCallback)
  # first set all result variables to empty/FALSE
  foreach (arg_name ${_singleArgNames} ${_multiArgNames})
    set(_out_${arg_name})
  endforeach ()

  foreach (_option ${_optionNames})
    set(_out_${_option} FALSE)
  endforeach ()

  set(_out_UNPARSED_ARGUMENTS)

  set(insideValues "NONE")
  set(currentArgName)

  set(_update_arg)
  variable_watch(_update_arg "${_updateCallback}")

  # now iterate over all arguments and fill the result variables
  foreach (currentArg ${ARGN})
    # this marks the end of the arguments belonging to this keyword:
    list(FIND _optionNames "${currentArg}" optionIndex)
    # this marks the end of the arguments belonging to this keyword:
    list(FIND _singleArgNames "${currentArg}" singleArgIndex)
    # this marks the end of the arguments belonging to this keyword:
    list(FIND _multiArgNames "${currentArg}" multiArgIndex)

    if (("${optionIndex}" EQUAL -1) AND ("${singleArgIndex}" EQUAL -1) AND
      ("${multiArgIndex}" EQUAL -1))
      if (NOT ("XXX_${insideValues}" STREQUAL "XXX_NONE"))
        if ("${insideValues}" STREQUAL "SINGLE")
          set(_out_${currentArgName} ${currentArg})
          set(insideValues FALSE)
        elseif ("${insideValues}" STREQUAL "MULTI")
          list(APPEND _out_${currentArgName} ${currentArg})
        endif ()

        set(_update_arg "${currentArgName}=${currentArg}")
      else ()
        list(APPEND _out_UNPARSED_ARGUMENTS ${currentArg})
      endif ()
    else ()
      if (NOT ${optionIndex} EQUAL -1)
        set(_out_${currentArg} TRUE)
        set(insideValues "NONE")
      elseif (NOT ${singleArgIndex} EQUAL -1)
        set(currentArgName ${currentArg})
        set(_out_${currentArgName})
        set(insideValues "SINGLE")
      elseif (NOT ${multiArgIndex} EQUAL -1)
        set(currentArgName ${currentArg})
        set(_out_${currentArgName} "")
        set(insideValues "MULTI")
      endif ()
    endif ()
  endforeach ()

  # propagate the result variables to the caller:
  foreach(arg_name ${_singleArgNames} ${_multiArgNames} ${_optionNames})
    if (DEFINED "_out_${arg_name}")
      set("${prefix}_${arg_name}" "${_out_${arg_name}}" PARENT_SCOPE)
    endif ()
  endforeach ()
  set("${prefix}_UNPARSED_ARGUMENTS" "${_out_UNPARSED_ARGUMENTS}" PARENT_SCOPE)

endfunction ()
