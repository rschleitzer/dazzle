# opensp/CMakeLists.txt — build libosp (OpenSP 1.5.2) as a static library

set(OSP_SOURCES
  lib/Allocator.cxx
  lib/ArcEngine.cxx
  lib/Attribute.cxx
  lib/Big5CodingSystem.cxx
  lib/CharsetDecl.cxx
  lib/CharsetInfo.cxx
  lib/CharsetRegistry.cxx
  lib/CmdLineApp.cxx
  lib/CodingSystem.cxx
  lib/CodingSystemKit.cxx
  lib/ConsoleOutput.cxx
  lib/ContentState.cxx
  lib/ContentToken.cxx
  lib/DescriptorManager.cxx
  lib/Dtd.cxx
  lib/DtdDeclEventHandler.cxx
  lib/EUCJPCodingSystem.cxx
  lib/ElementType.cxx
  lib/Entity.cxx
  lib/EntityApp.cxx
  lib/EntityCatalog.cxx
  lib/EntityDecl.cxx
  lib/EntityManager.cxx
  lib/ErrnoMessageArg.cxx
  lib/ErrorCountEventHandler.cxx
  lib/Event.cxx
  lib/EventGenerator.cxx
  lib/ExtendEntityManager.cxx
  lib/ExternalId.cxx
  lib/Fixed2CodingSystem.cxx
  lib/Fixed4CodingSystem.cxx
  lib/GenericEventHandler.cxx
  lib/Group.cxx
  lib/Hash.cxx
  lib/IListBase.cxx
  lib/Id.cxx
  lib/IdentityCodingSystem.cxx
  lib/InputSource.cxx
  lib/InternalInputSource.cxx
  lib/Link.cxx
  lib/LinkProcess.cxx
  lib/LiteralStorage.cxx
  lib/Location.cxx
  lib/Lpd.cxx
  lib/Markup.cxx
  lib/Message.cxx
  lib/MessageArg.cxx
  lib/MessageEventHandler.cxx
  lib/MessageFormatter.cxx
  lib/MessageReporter.cxx
  lib/MessageTable.cxx
  lib/ModeInfo.cxx
  lib/Notation.cxx
  lib/NotationStorage.cxx
  lib/NumericCharRefOrigin.cxx
  lib/OffsetOrderedList.cxx
  lib/OpenElement.cxx
  lib/OutputByteStream.cxx
  lib/OutputCharStream.cxx
  lib/OutputState.cxx
  lib/Param.cxx
  lib/Parser.cxx
  lib/ParserApp.cxx
  lib/ParserEventGeneratorKit.cxx
  lib/ParserMessages.cxx
  lib/ParserOptions.cxx
  lib/ParserState.cxx
  lib/Partition.cxx
  lib/PosixStorage.cxx
  lib/Recognizer.cxx
  lib/RewindStorageObject.cxx
  lib/SGMLApplication.cxx
  lib/SJISCodingSystem.cxx
  lib/SOEntityCatalog.cxx
  lib/Sd.cxx
  lib/SdText.cxx
  lib/SearchResultMessageArg.cxx
  lib/SgmlParser.cxx
  lib/ShortReferenceMap.cxx
  lib/StdioStorage.cxx
  lib/StorageManager.cxx
  lib/SubstTable.cxx
  lib/Syntax.cxx
  lib/Text.cxx
  lib/TokenMessageArg.cxx
  lib/TranslateCodingSystem.cxx
  lib/TrieBuilder.cxx
  lib/TypeId.cxx
  lib/URLStorage.cxx
  lib/UTF8CodingSystem.cxx
  lib/UTF16CodingSystem.cxx
  lib/Undo.cxx
  lib/UnicodeCodingSystem.cxx
  lib/UnivCharsetDesc.cxx
  lib/XMLCodingSystem.cxx
  lib/assert.cxx
  lib/parseAttribute.cxx
  lib/parseCommon.cxx
  lib/parseDecl.cxx
  lib/parseInstance.cxx
  lib/parseMode.cxx
  lib/parseParam.cxx
  lib/parseSd.cxx
  lib/splib.cxx
)

# C compatibility sources
list(APPEND OSP_SOURCES
  lib/memcmp.c
  lib/memmove.c
  lib/strerror.c
)

# Windows-only sources
if(WIN32)
  list(APPEND OSP_SOURCES
    lib/Win32CodingSystem.cxx
    lib/WinInetStorage.cxx
  )
endif()

# --- Generated inst files from .m4 templates ---
set(OSP_M4_DIR "${CMAKE_CURRENT_SOURCE_DIR}/lib")
set(OSP_GEN_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
file(MAKE_DIRECTORY "${OSP_GEN_DIR}")

set(OSP_INST_M4S
  app_inst
  arc_inst
  entmgr_inst
  parser_inst
  xentmgr_inst
)

set(OSP_GENERATED_INSTS)
foreach(inst ${OSP_INST_M4S})
  set(_out "${OSP_GEN_DIR}/${inst}.cxx")
  dazzle_generate_inst_opensp("${_out}" "${OSP_M4_DIR}/${inst}.m4")
  list(APPEND OSP_GENERATED_INSTS "${_out}")
endforeach()

# --- Generated message headers from .msg files ---
set(OSP_MSG_FILES
  ArcEngineMessages
  CatalogMessages
  CmdLineAppMessages
  EntityAppMessages
  EntityManagerMessages
  MessageFormatterMessages
  MessageReporterMessages
  ParserAppMessages
  PosixStorageMessages
  StdioStorageMessages
  URLStorageMessages
)

if(WIN32)
  list(APPEND OSP_MSG_FILES WinInetStorageMessages)
endif()

set(OSP_GENERATED_MSGS)
foreach(msg ${OSP_MSG_FILES})
  dazzle_generate_messages(
    "${PROJECT_SOURCE_DIR}/opensp/msggen.pl"
    "${OSP_M4_DIR}/${msg}.msg"
    "${OSP_GEN_DIR}"
    "libModule"
    OUTPUTS _msg_outputs
  )
  list(APPEND OSP_GENERATED_MSGS ${_msg_outputs})
endforeach()

# ParserMessages also generates .cxx (has !cxx directive) — handle separately
dazzle_generate_messages(
  "${PROJECT_SOURCE_DIR}/opensp/msggen.pl"
  "${OSP_M4_DIR}/ParserMessages.msg"
  "${OSP_GEN_DIR}"
  "libModule"
  GEN_CXX
  OUTPUTS _parser_msg_outputs
)
list(APPEND OSP_GENERATED_MSGS ${_parser_msg_outputs})

# ParserMessages.cxx is generated into OSP_GEN_DIR
set(OSP_GENERATED_CXX "${OSP_GEN_DIR}/ParserMessages.cxx")

# --- Build the library ---
add_library(osp STATIC
  ${OSP_SOURCES}
  ${OSP_GENERATED_INSTS}
  ${OSP_GENERATED_CXX}
)

# Generated message headers are needed at compile time but aren't compiled themselves.
# Create a custom target to ensure they're generated before osp compiles.
add_custom_target(osp_messages DEPENDS ${OSP_GENERATED_MSGS})
add_dependencies(osp osp_messages)

target_include_directories(osp
  PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}/include"
    "${CMAKE_BINARY_DIR}/include"
    "${CMAKE_BINARY_DIR}/compat-include"
  PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/lib"
    "${CMAKE_CURRENT_SOURCE_DIR}/generic"
    "${OSP_GEN_DIR}"
)

target_compile_definitions(osp
  PUBLIC
    SP_MULTI_BYTE=1
  PRIVATE
    BUILD_LIBSP
)

# Threading
find_package(Threads)
if(Threads::Threads)
  target_link_libraries(osp PUBLIC Threads::Threads)
endif()

# Iconv
include(FindIconv)
if(Iconv_FOUND)
  target_link_libraries(osp PUBLIC Iconv::Iconv)
endif()

# Winsock (for URLStorage HTTP support)
if(WIN32)
  target_link_libraries(osp PUBLIC ws2_32)
endif()
