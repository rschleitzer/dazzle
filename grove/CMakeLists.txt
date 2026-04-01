# grove/CMakeLists.txt — build libogrove (SGML grove library)

add_library(ogrove STATIC
  Node.cxx
  LocNode.cxx
)

target_include_directories(ogrove
  PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${CMAKE_BINARY_DIR}/include"
    "${CMAKE_BINARY_DIR}/compat-include"
)

target_compile_definitions(ogrove PRIVATE BUILD_LIBGROVE)

target_link_libraries(ogrove PUBLIC osp)

if(NOT WIN32)
  target_link_libraries(ogrove PUBLIC m)
endif()
