cmake_minimum_required(VERSION 3.15)
project(dazzle VERSION 1.3.3 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Perl is required for code generation (instmac.pl, msggen.pl)
find_package(Perl REQUIRED)

# Load code generation helpers
include(cmake/DazzleGenerate.cmake)

# ======================================================================
# Feature detection
# ======================================================================

include(CheckIncludeFileCXX)
include(CheckIncludeFile)
include(CheckTypeSize)
include(CheckCXXSourceCompiles)
include(CheckFunctionExists)
include(CMakePushCheckState)
include(TestBigEndian)

# Headers
check_include_file_cxx("new" HAVE_NEW)
check_include_file_cxx("cassert" HAVE_CASSERT)
check_include_file("unistd.h" HAVE_UNISTD_H)
check_include_file("io.h" HAVE_IO_H)
check_include_file("osfcn.h" HAVE_OSFCN_H)
check_include_file("limits.h" HAVE_LIMITS_H)

# Functions
check_function_exists(setlocale HAVE_SETLOCALE)
check_function_exists(strerror HAVE_STRERROR)
check_function_exists(memmove HAVE_MEMMOVE)
check_function_exists(memcmp HAVE_MEMCMP)
check_function_exists(wcslen HAVE_WCSLEN)

# Type sizes
check_type_size("bool" SIZEOF_BOOL LANGUAGE CXX)
if(HAVE_SIZEOF_BOOL)
  set(HAVE_BOOL 1)
endif()
check_type_size("wchar_t" SIZEOF_WCHAR_T LANGUAGE CXX)
if(HAVE_SIZEOF_WCHAR_T)
  set(HAVE_WCHAR_T 1)
endif()
check_type_size("unsigned short" SIZEOF_UNSIGNED_SHORT LANGUAGE CXX)
check_type_size("unsigned int" SIZEOF_UNSIGNED_INT LANGUAGE CXX)
check_type_size("size_t" SIZEOF_SIZE_T LANGUAGE CXX)

# C++ features
check_cxx_source_compiles("
  namespace test { int x = 0; }
  int main() { return test::x; }
" HAVE_NAMESPACES)

check_cxx_source_compiles("
  #include <iostream>
  namespace std { }
  using namespace std;
  int main() { return 0; }
" HAVE_NAMESPACE_STD)

check_cxx_source_compiles("
  template<class T> class A { public: T x; };
  template class A<int>;
  int main() { return 0; }
" HAVE_INSTANTIATIONS)

check_cxx_source_compiles("
  class A { public: typename int x; };
  int main() { return 0; }
" _TYPENAME_TEST)
# typename keyword is standard in C++14, just set it
set(HAVE_TYPENAME 1)

check_cxx_source_compiles("
  class A { mutable int x; public: A() : x(0) {} };
  int main() { A a; return 0; }
" HAVE_MUTABLE)

check_cxx_source_compiles("
  int main() { for (int i = 0; i < 1; i++) {} int i = 1; return i; }
" HAVE_NEW_FOR_SCOPING)

check_cxx_source_compiles("
  class Base { };
  class Derived : public Base { };
  int main() { Derived d; Base& b = d; Derived& d2 = dynamic_cast<Derived&>(b); return 0; }
" HAVE_DYNAMIC_CAST)

# Placement operator new is available in all modern C++ via <new>.
# We must set this so SP_DECLARE_PLACEMENT_OPERATOR_NEW is NOT defined
# (which would redeclare placement new and conflict with <new>).
set(HAVE_PLACEMENT_OPERATOR_NEW 1)

# Note: HAVE_PLACEMENT_OPERATOR_DELETE is intentionally NOT set.
# Defining SP_HAVE_PLACEMENT_OPERATOR_DELETE causes private operator delete
# in ELObj.h which breaks derived class destructors in C++11+.
# The autoconf build + build.sh also leave this undefined.

# struct stat st_blksize
check_cxx_source_compiles("
  #include <sys/stat.h>
  int main() { struct stat s; return s.st_blksize; }
" HAVE_ST_BLKSIZE)

# Threads
find_package(Threads)
if(CMAKE_USE_PTHREADS_INIT)
  set(HAVE_LIBPTHREAD 1)
endif()

# Iconv
include(FindIconv)
if(Iconv_FOUND)
  set(HAVE_ICONV 1)
  # Check if iconv() needs const
  cmake_push_check_state(RESET)
  set(CMAKE_REQUIRED_LIBRARIES Iconv::Iconv)
  check_cxx_source_compiles("
    #include <iconv.h>
    int main() {
      iconv_t cd = iconv_open(\"UTF-8\", \"ASCII\");
      const char* in = \"test\";
      char out[16];
      char* outp = out;
      size_t inl = 4, outl = 16;
      iconv(cd, &in, &inl, &outp, &outl);
      return 0;
    }
  " ICONV_NEEDS_CONST)
  cmake_pop_check_state()
  if(ICONV_NEEDS_CONST)
    set(ICONV_CONST "const")
  else()
    set(ICONV_CONST "")
  endif()
else()
  set(ICONV_CONST "")
endif()

# Endianness
test_big_endian(WORDS_BIGENDIAN)

# Socket support (for URLStorage HTTP)
if(WIN32)
  set(SP_HAVE_SOCKET 1)
else()
  check_cxx_source_compiles("
    #include <sys/socket.h>
    int main() { int s = socket(AF_INET, SOCK_STREAM, 0); return s; }
  " SP_HAVE_SOCKET)
endif()

# Platform-specific path defaults
if(WIN32)
  set(PATH_SEPARATOR ";")
  set(SGML_CATALOG_FILES_DEFAULT "")
  set(SP_LOCALE_DIR "")
else()
  set(PATH_SEPARATOR ":")
  if(NOT SGML_CATALOG_FILES_DEFAULT)
    set(SGML_CATALOG_FILES_DEFAULT "${CMAKE_INSTALL_PREFIX}/share/sgml/catalog")
  endif()
  if(NOT SP_LOCALE_DIR)
    set(SP_LOCALE_DIR "${CMAKE_INSTALL_PREFIX}/share/locale")
  endif()
endif()

set(SP_DTDDECL 1)
set(SP_MULTI_BYTE 1)

# ======================================================================
# Generate config.h
# ======================================================================

configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake/config.h.cmake"
  "${CMAKE_BINARY_DIR}/include/config.h"
)

# ======================================================================
# Generate OpenSP forwarding headers
#
# The dazzle msggen.pl generates: #include <OpenSP/Message.h>
# On Unix the source tree has a symlink opensp/include/OpenSP -> .
# On Windows symlinks may not work, so we create forwarding headers:
#   build/compat-include/OpenSP/Foo.h -> #include "real/path/Foo.h"
# ======================================================================

set(COMPAT_INCLUDE_DIR "${CMAKE_BINARY_DIR}/compat-include")
file(MAKE_DIRECTORY "${COMPAT_INCLUDE_DIR}/OpenSP")

file(GLOB _osp_headers "${CMAKE_CURRENT_SOURCE_DIR}/opensp/include/*.h")
foreach(_h ${_osp_headers})
  get_filename_component(_name "${_h}" NAME)
  file(WRITE "${COMPAT_INCLUDE_DIR}/OpenSP/${_name}"
    "// Forwarding header generated by CMake\n#include \"${_h}\"\n")
endforeach()

# Also forward the generated config.h so <OpenSP/config.h> works
file(WRITE "${COMPAT_INCLUDE_DIR}/OpenSP/config.h"
  "// Forwarding header generated by CMake\n#include \"${CMAKE_BINARY_DIR}/include/config.h\"\n")

# ======================================================================
# Subdirectories (order matters: dependencies first)
# ======================================================================

add_subdirectory(opensp)
add_subdirectory(grove)
add_subdirectory(spgrove)
add_subdirectory(style)
add_subdirectory(jade)

# ======================================================================
# Install DSSSL data files
# ======================================================================

include(GNUInstallDirs)
install(
  FILES
    dsssl/builtins.dsl
    dsssl/catalog
    dsssl/dsssl.dtd
    dsssl/extensions.dsl
    dsssl/fot.dtd
    dsssl/style-sheet.dtd
  DESTINATION "${CMAKE_INSTALL_DATADIR}/dazzle"
)
