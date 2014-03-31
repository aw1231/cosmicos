
##############################################################################
##
## Compile some basic tools for processing the message, using haxe
##
##

find_program(HAXE haxe)
if(NOT HAXE)
  MESSAGE(FATAL_ERROR "Could not find haxe, please install it")
endif()

set(WORK ${CMAKE_CURRENT_BINARY_DIR})
set(SRC ${CMAKE_SOURCE_DIR}/transform)
set(MSG ${CMAKE_SOURCE_DIR}/src)

add_custom_command(OUTPUT ${WORK}/CosmicAudio.js
  COMMAND ${HAXE} -js CosmicAudio.js -main cosmicos.Sound -cp ${SRC}
  WORKING_DIRECTORY ${WORK}
  DEPENDS ${SRC}/cosmicos/Sound.hx)

add_custom_command(OUTPUT ${WORK}/CosmicEval.js
  COMMAND ${HAXE} -js CosmicEval.js -main cosmicos.Evaluate -cp ${SRC}
  WORKING_DIRECTORY ${WORK}
  DEPENDS ${SRC}/cosmicos/Evaluate.hx)

add_custom_command(OUTPUT ${WORK}/SpiderScrawl.js
  COMMAND ${HAXE} -js SpiderScrawl.js -main cosmicos.SpiderScrawl -cp ${SRC}
  WORKING_DIRECTORY ${WORK}
  DEPENDS ${SRC}/cosmicos/SpiderScrawl.hx)

add_custom_command(OUTPUT ${WORK}/OghamStyle.js
  COMMAND ${HAXE} -js OghamStyle.js -main cosmicos.OghamStyle -cp ${SRC}
  WORKING_DIRECTORY ${WORK}
  DEPENDS ${SRC}/cosmicos/OghamStyle.hx)

add_custom_target(jshelpers ALL DEPENDS 
  ${WORK}/CosmicAudio.js
  ${WORK}/CosmicEval.js
  ${WORK}/SpiderScrawl.js
  ${WORK}/OghamStyle.js
)



##############################################################################
##
## Add targets for message parts
##

file(READ "${CMAKE_SOURCE_DIR}/src/index.txt" COSMIC_DEPENDS)
string(REGEX REPLACE ":[^\n]*\n+" ";" COSMIC_DEPENDS "${COSMIC_DEPENDS}")

find_program(NODE NAMES nodejs node)
if(NOT NODE)
  MESSAGE(FATAL_ERROR "Could not find node, please install it")
endif()

get_target_property(UnlessDriverLoc UnlessDriver JAR_FILE)
get_target_property(FritzifierLoc Fritzifier JAR_FILE)
FILE(WRITE ${WORK}/setup.cmake "
  set(base \"${CMAKE_SOURCE_DIR}/src\")
  set(out_dir \"${CMAKE_CURRENT_BINARY_DIR}\")
  set(JAVA_EXE \"${Java_JAVA_EXECUTABLE}\")
  set(JAVAC_EXE \"${Java_JAVAC_EXECUTABLE}\")
  set(UNLESS \"${UnlessDriverLoc}\")
  set(ENCODER \"${FritzifierLoc}\")
  set(BCEL \"${BCEL_JAR}\")
  set(NODE \"${NODE}\")
")

set(ACTIVE_DEPENDS)
set(ACTIVE_DEPENDS_SHORT "")
foreach(depend ${COSMIC_DEPENDS})
  # message(STATUS "<${MSG}/${depend}.pl>")
  
  foreach(ext pl scm gate java)
    if(EXISTS ${MSG}/${depend}.${ext})
      add_custom_command(OUTPUT ${WORK}/${depend}.ftz
	COMMAND ${CMAKE_COMMAND} 
	"-Din:STRING=${depend}.${ext}" 
	"-Dout:STRING=${depend}.ftz"
	"-Dname:STRING=${depend}"
	-P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/convert_${ext}.cmake
	WORKING_DIRECTORY ${WORK}
	DEPENDS ${MSG}/${depend}.${ext} UnlessDriver Fritzifier
	${CMAKE_CURRENT_SOURCE_DIR}/cmake/convert_${ext}.cmake)
      list(APPEND ACTIVE_DEPENDS ${WORK}/${depend}.ftz)
      set(ACTIVE_DEPENDS_SHORT "${ACTIVE_DEPENDS_SHORT} ${depend}")
    endif()
  endforeach()
endforeach()

add_custom_command(OUTPUT ${WORK}/assem.txt
  COMMAND ${CMAKE_COMMAND}
  "-Din:STRING=${ACTIVE_DEPENDS_SHORT}" 
  "-Dout:STRING=assem.txt"
  -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/assemble.cmake
  WORKING_DIRECTORY ${WORK}
  DEPENDS ${ACTIVE_DEPENDS} ${CMAKE_CURRENT_SOURCE_DIR}/cmake/assemble.cmake)

add_custom_command(OUTPUT ${WORK}/assem.json
  COMMAND ${NODE} ${CMAKE_SOURCE_DIR}/transform/assemble/assemble2json.js ${WORK}/assem.txt
  WORKING_DIRECTORY ${WORK}
  DEPENDS ${WORK}/assem.txt)

add_custom_command(OUTPUT ${WORK}/primer.json
  COMMAND ${CMAKE_COMMAND} 
  "-Din:STRING=${CMAKE_SOURCE_DIR}/transform/assemble/primer.js" 
  "-Dnargs:STRING=${WORK}/assem.json"
  "-Dlog:STRING=make-primer"
  -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/node.cmake
  WORKING_DIRECTORY ${WORK}
  DEPENDS ${WORK}/assem.json
  ${WORK}/CosmicEval.js
  ${CMAKE_SOURCE_DIR}/transform/assemble/primer.js)

add_custom_command(OUTPUT ${WORK}/assem2.json
  COMMAND ${CMAKE_COMMAND} 
  "-Din:STRING=${CMAKE_SOURCE_DIR}/transform/assemble/evaluate.js" 
  "-Dnargs:STRING="
  "-Dlog:STRING=make-assem2"
  -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/node.cmake
  WORKING_DIRECTORY ${WORK}
  DEPENDS ${WORK}/assem.json
  ${WORK}/primer.json
  ${WORK}/CosmicEval.js
  ${CMAKE_SOURCE_DIR}/transform/assemble/evaluate.js)

add_custom_target(assem ALL DEPENDS ${WORK}/assem2.json)
