# DazzleGenerate.cmake — code generation helpers for instmac.pl and msggen.pl

# Generate a _inst.cxx file from a .m4 template using instmac.pl.
# The .m4 file is processed by Perl's instmac.pl and output is redirected to the .cxx file.
#
# Usage:
#   dazzle_generate_inst(<output_cxx> <input_m4>)
#
function(dazzle_generate_inst output_cxx input_m4)
  add_custom_command(
    OUTPUT "${output_cxx}"
    COMMAND "${CMAKE_COMMAND}"
      -DPERL=${PERL_EXECUTABLE}
      -DSCRIPT=${PROJECT_SOURCE_DIR}/instmac.pl
      -DINPUT=${input_m4}
      -DOUTPUT=${output_cxx}
      -P ${PROJECT_SOURCE_DIR}/cmake/RunRedirect.cmake
    DEPENDS "${input_m4}" "${PROJECT_SOURCE_DIR}/instmac.pl"
    COMMENT "Generating ${output_cxx} from ${input_m4}"
    VERBATIM
  )
endfunction()

# Generate a _inst.cxx file from a .m4 template using OpenSP's instmac.pl.
# Same as above but uses the instmac.pl from opensp/.
#
# Usage:
#   dazzle_generate_inst_opensp(<output_cxx> <input_m4>)
#
function(dazzle_generate_inst_opensp output_cxx input_m4)
  add_custom_command(
    OUTPUT "${output_cxx}"
    COMMAND "${CMAKE_COMMAND}"
      -DPERL=${PERL_EXECUTABLE}
      -DSCRIPT=${PROJECT_SOURCE_DIR}/opensp/instmac.pl
      -DINPUT=${input_m4}
      -DOUTPUT=${output_cxx}
      -P ${PROJECT_SOURCE_DIR}/cmake/RunRedirect.cmake
    DEPENDS "${input_m4}" "${PROJECT_SOURCE_DIR}/opensp/instmac.pl"
    COMMENT "Generating ${output_cxx} from ${input_m4}"
    VERBATIM
  )
endfunction()

# Generate message header (and optionally .cxx) from a .msg file using msggen.pl.
# The msggen.pl script runs in the output directory and produces:
#   <basename>.h   — always
#   <basename>.cxx — only if the .msg file starts with "!cxx"
#   <basename>.rc  — always (Windows resource file)
#
# Usage:
#   dazzle_generate_messages(<msggen_script> <input_msg> <output_dir> <module_flag>
#                            [GEN_CXX] [OUTPUTS <var>])
#
# module_flag: e.g. "libModule" or "jstyleModule"
# GEN_CXX: if set, the .msg file also generates a .cxx file (has !cxx directive)
# If OUTPUTS is given, the variable is set to the list of generated files.
#
function(dazzle_generate_messages msggen_script input_msg output_dir module_flag)
  cmake_parse_arguments(ARG "GEN_CXX" "OUTPUTS" "" ${ARGN})

  get_filename_component(msg_name "${input_msg}" NAME)
  get_filename_component(msg_base "${input_msg}" NAME_WE)

  set(_outputs "${output_dir}/${msg_base}.h" "${output_dir}/${msg_base}.rc")

  if(ARG_GEN_CXX)
    list(APPEND _outputs "${output_dir}/${msg_base}.cxx")
  endif()

  add_custom_command(
    OUTPUT ${_outputs}
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${input_msg}" "${output_dir}/${msg_name}"
    COMMAND "${PERL_EXECUTABLE}" -w "${msggen_script}" -l "${module_flag}" "${output_dir}/${msg_name}"
    DEPENDS "${input_msg}" "${msggen_script}"
    WORKING_DIRECTORY "${output_dir}"
    COMMENT "Generating messages from ${msg_name}"
    VERBATIM
  )

  if(ARG_OUTPUTS)
    set(${ARG_OUTPUTS} ${_outputs} PARENT_SCOPE)
  endif()
endfunction()
