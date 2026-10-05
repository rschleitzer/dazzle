#!/bin/bash
#
# Build script for Dazzle (OpenJade + OpenSP)
#
# This builds OpenSP and OpenJade together, with correct default paths
# so dazzle can find SGML catalogs without -c or SGML_CATALOG_FILES
#

set -e

# Configuration
PREFIX="${PREFIX:-/usr/local}"
JOBS="${JOBS:-4}"

# Derived paths
SGML_CATALOG="${PREFIX}/share/sgml/catalog"
DAZZLE_DATADIR="${PREFIX}/share/dazzle"
BUILTINS_DSL="${DAZZLE_DATADIR}/builtins.dsl"

TOP="$(cd "$(dirname "$0")" && pwd)"

# Portable sed -i (BSD vs GNU)
if sed --version >/dev/null 2>&1; then
    sedi() { sed -i "$@"; }
else
    sedi() { sed -i '' "$@"; }
fi

echo "=== Dazzle Build ==="
echo "PREFIX:        ${PREFIX}"
echo "SGML_CATALOG:  ${SGML_CATALOG}"
echo "BUILTINS_DSL:  ${BUILTINS_DSL}"
echo ""

# ============================================
# Step 1: Build OpenSP
# ============================================
echo "=== Building OpenSP ==="
cd "${TOP}/opensp"

# Apply patches if needed (check if already patched by looking for "using")
if ! grep -q "using IListBase::clear;" include/IList.h 2>/dev/null; then
    echo "Applying C++11 compatibility patches..."
    # Fix access declarations (old C++ style -> C++11 using declarations)
    sedi 's/^[[:space:]]*IListBase::clear;/  using IListBase::clear;/' include/IList.h
    sedi 's/^[[:space:]]*IListBase::empty;/  using IListBase::empty;/' include/IList.h
    sedi 's/^[[:space:]]*IListIterBase::next;/  using IListIterBase::next;/' include/IListIter.h
    sedi 's/^[[:space:]]*IListIterBase::done;/  using IListIterBase::done;/' include/IListIter.h
    sedi 's/^[[:space:]]*Ptr<T>::isNull;/  using Ptr<T>::isNull;/' include/Ptr.h
    sedi 's/^[[:space:]]*Ptr<T>::clear;/  using Ptr<T>::clear;/' include/Ptr.h
    sedi 's/^[[:space:]]*ParserState::\([a-zA-Z]*\);/  using ParserState::\1;/' lib/Parser.h
fi

if [ ! -f Makefile ] || [ ! -f config.h ]; then
    CXXFLAGS="-std=c++98 -g -O2" ./configure \
        --prefix="${PREFIX}" \
        --enable-http \
        --enable-default-catalog="${SGML_CATALOG}" \
        --disable-doc-build \
        --disable-dependency-tracking \
        --disable-nls
fi

# Fix config.h issues for modern compilers
if grep -q "^#define ptrdiff_t long" config.h 2>/dev/null; then
    echo "Fixing config.h for modern compilers..."
    sedi 's/^#define ptrdiff_t long$/\/* #undef ptrdiff_t *\//' config.h
    sedi 's/^#define SP_DECLARE_PLACEMENT_OPERATOR_NEW$/\/* #undef SP_DECLARE_PLACEMENT_OPERATOR_NEW *\//' config.h
    sedi 's/^#define SP_NO_STD_NAMESPACE$/\/* #undef SP_NO_STD_NAMESPACE *\//' config.h
fi

make -j${JOBS}

echo "OpenSP built successfully"
echo ""

# ============================================
# Step 2: Build OpenJade (dazzle)
# ============================================
echo "=== Building OpenJade (dazzle) ==="
cd "${TOP}"

# Set up paths to use our local OpenSP build
SP_INCLUDE="${TOP}/opensp/include"
SP_LIB="${TOP}/opensp/lib/.libs"
if [ "$(uname)" != "Darwin" ]; then
    # Work around old libtool doubling .libs path on Linux
    ln -sfn . "${SP_LIB}/.libs"
fi

# Create OpenSP symlink if needed
if [ ! -L "${SP_INCLUDE}/OpenSP" ]; then
    ln -s . "${SP_INCLUDE}/OpenSP"
fi

if [ ! -f Makefile.comm ] || [ ! -f include/config.h ]; then
    ./configure \
        --prefix="${PREFIX}" \
        --enable-spincludedir="${SP_INCLUDE}" \
        --enable-splibdir="${SP_LIB}" \
        --datadir="${DAZZLE_DATADIR}"

    # Fix the include path in config.h
    sedi "s|${SP_INCLUDE}/config.h|${TOP}/opensp/config.h|" include/config.h
fi

make -j${JOBS}

echo ""
echo "=== Build Complete ==="
echo ""
echo "Binary: ${TOP}/jade/.libs/dazzle"
echo ""
echo "To test locally:"
if [ "$(uname)" = "Darwin" ]; then
echo "  DYLD_LIBRARY_PATH=${SP_LIB} ${TOP}/jade/.libs/dazzle --help"
else
echo "  LD_LIBRARY_PATH=${SP_LIB} ${TOP}/jade/.libs/dazzle --help"
fi
echo ""
echo "To install, run:"
echo "  sudo ./install.sh"
echo ""
