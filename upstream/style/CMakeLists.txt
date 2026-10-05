# style/CMakeLists.txt — build libostyle (DSSSL engine)

set(STYLE_GEN_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
file(MAKE_DIRECTORY "${STYLE_GEN_DIR}")

# --- Generated inst files from .m4 ---
set(STYLE_INST_M4S style_inst FlowObj_inst primitive_inst)
set(STYLE_GENERATED_INSTS)
foreach(inst ${STYLE_INST_M4S})
  set(_out "${STYLE_GEN_DIR}/${inst}.cxx")
  dazzle_generate_inst("${_out}" "${CMAKE_CURRENT_SOURCE_DIR}/${inst}.m4")
  list(APPEND STYLE_GENERATED_INSTS "${_out}")
endforeach()

# --- Generated messages from .msg ---
# InterpreterMessages has !cxx — generates .h, .cxx, and .rc
dazzle_generate_messages(
  "${PROJECT_SOURCE_DIR}/msggen.pl"
  "${CMAKE_CURRENT_SOURCE_DIR}/InterpreterMessages.msg"
  "${STYLE_GEN_DIR}"
  "jstyleModule"
  GEN_CXX
  OUTPUTS INTERP_MSG_OUTPUTS
)

# DssslAppMessages generates .h and .rc only
dazzle_generate_messages(
  "${PROJECT_SOURCE_DIR}/msggen.pl"
  "${CMAKE_CURRENT_SOURCE_DIR}/DssslAppMessages.msg"
  "${STYLE_GEN_DIR}"
  "jstyleModule"
  OUTPUTS DSSSLAPP_MSG_OUTPUTS
)

# The InterpreterMessages.cxx is a generated source that gets compiled
set(INTERP_MESSAGES_CXX "${STYLE_GEN_DIR}/InterpreterMessages.cxx")

add_library(ostyle STATIC
  LangObj.cxx
  Collector.cxx
  DssslApp.cxx
  DssslSpecEventHandler.cxx
  ELObj.cxx
  ELObjMessageArg.cxx
  Expression.cxx
  FOTBuilder.cxx
  ColumnSetSequence.cxx
  PageSequence.cxx
  Anchor.cxx
  EmbeddedText.cxx
  IncludedContainerArea.cxx
  GlyphAnnotation.cxx
  SideBySide.cxx
  SideBySideItem.cxx
  AlignedColumn.cxx
  MultiLineInlineNote.cxx
  EmphasizingMark.cxx
  FlowObj.cxx
  InheritedC.cxx
  Insn.cxx
  Interpreter.cxx
  NumberCache.cxx
  ProcessContext.cxx
  ProcessingMode.cxx
  SchemeParser.cxx
  Style.cxx
  StyleEngine.cxx
  primitive.cxx
  GroveManager.cxx
  Pattern.cxx
  MacroFlowObj.cxx
  MessageModule.cxx
  "${INTERP_MESSAGES_CXX}"
  ${STYLE_GENERATED_INSTS}
)

# Ensure message headers are generated before compilation
set(STYLE_ALL_MSG_OUTPUTS ${INTERP_MSG_OUTPUTS} ${DSSSLAPP_MSG_OUTPUTS})
add_custom_target(style_messages DEPENDS ${STYLE_ALL_MSG_OUTPUTS})
add_dependencies(ostyle style_messages)

target_include_directories(ostyle
  PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"
  PRIVATE
    "${STYLE_GEN_DIR}"
)

target_link_libraries(ostyle PUBLIC ospgrove ogrove osp)
