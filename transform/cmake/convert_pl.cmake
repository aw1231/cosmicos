include(setup.cmake)
execute_process(COMMAND perl -I${base} ${base}/${in} OUTPUT_FILE ${out} RESULT_VARIABLE result)

if (NOT ${result} EQUAL 0)
  if (EXISTS ${out})
    file(REMOVE ${out})
  endif()
  message(FATAL_ERROR "Error processing ${in}: perl returned ${result}")
endif()
