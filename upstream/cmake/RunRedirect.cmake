# RunRedirect.cmake — portable stdout-to-file redirect for code generation
# Usage: cmake -DPERL=... -DSCRIPT=... -DINPUT=... -DOUTPUT=... -P RunRedirect.cmake

execute_process(
  COMMAND "${PERL}" "${SCRIPT}" "${INPUT}"
  OUTPUT_FILE "${OUTPUT}"
  RESULT_VARIABLE rc
)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "Code generation failed (exit ${rc}): ${PERL} ${SCRIPT} ${INPUT}")
endif()
