# jade/CMakeLists.txt — build the dazzle executable

set(JADE_GEN_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
file(MAKE_DIRECTORY "${JADE_GEN_DIR}")

# --- Generated inst files from .m4 ---
set(JADE_INST_M4S
  HtmlFOTBuilder_inst
  RtfFOTBuilder_inst
  TeXFOTBuilder_inst
  TransformFOTBuilder_inst
  MifFOTBuilder_inst
)

set(JADE_GENERATED_INSTS)
foreach(inst ${JADE_INST_M4S})
  set(_out "${JADE_GEN_DIR}/${inst}.cxx")
  dazzle_generate_inst("${_out}" "${CMAKE_CURRENT_SOURCE_DIR}/${inst}.m4")
  list(APPEND JADE_GENERATED_INSTS "${_out}")
endforeach()

# --- Generated message headers from .msg ---
set(JADE_MSG_FILES
  JadeMessages
  HtmlMessages
  RtfMessages
  TeXMessages
  MifMessages
)

set(JADE_GENERATED_MSGS)
foreach(msg ${JADE_MSG_FILES})
  dazzle_generate_messages(
    "${PROJECT_SOURCE_DIR}/msggen.pl"
    "${CMAKE_CURRENT_SOURCE_DIR}/${msg}.msg"
    "${JADE_GEN_DIR}"
    "jstyleModule"
    OUTPUTS _msg_outputs
  )
  list(APPEND JADE_GENERATED_MSGS ${_msg_outputs})
endforeach()

# --- Sources ---
set(JADE_SOURCES
  jade.cxx
  SgmlFOTBuilder.cxx
  RtfFOTBuilder.cxx
  HtmlFOTBuilder.cxx
  TeXFOTBuilder.cxx
  TransformFOTBuilder.cxx
  MifFOTBuilder.cxx
)

if(WIN32)
  list(APPEND JADE_SOURCES RtfOle.cxx)
endif()

# --- Build the executable ---
add_executable(dazzle
  ${JADE_SOURCES}
  ${JADE_GENERATED_INSTS}
)

# Ensure message headers are generated before compilation
add_custom_target(jade_messages DEPENDS ${JADE_GENERATED_MSGS})
add_dependencies(dazzle jade_messages)

target_include_directories(dazzle PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${JADE_GEN_DIR}"
)

target_compile_definitions(dazzle PRIVATE
  JADE_HTML
  JADE_MIF
)

target_link_libraries(dazzle PRIVATE ostyle ospgrove ogrove osp)

# Install
include(GNUInstallDirs)
install(TARGETS dazzle RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
