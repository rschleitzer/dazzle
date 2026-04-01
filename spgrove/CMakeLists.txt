# spgrove/CMakeLists.txt — build libospgrove (OpenSP-to-grove bridge)

set(SPGROVE_GEN_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
file(MAKE_DIRECTORY "${SPGROVE_GEN_DIR}")

# Generated inst file
set(GROVE_INST_CXX "${SPGROVE_GEN_DIR}/grove_inst.cxx")
dazzle_generate_inst("${GROVE_INST_CXX}" "${CMAKE_CURRENT_SOURCE_DIR}/grove_inst.m4")

add_library(ospgrove STATIC
  GroveApp.cxx
  GroveBuilder.cxx
  SdNode.cxx
  "${GROVE_INST_CXX}"
)

target_include_directories(ospgrove
  PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"
  PRIVATE
    "${SPGROVE_GEN_DIR}"
)

target_link_libraries(ospgrove PUBLIC ogrove osp)
