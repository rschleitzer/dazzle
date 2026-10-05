#!/bin/bash
#
# Install script for Dazzle
#
# Installs OpenSP, dazzle binary, and sets up SGML catalog chain
#

set -e

PREFIX="${PREFIX:-/usr/local}"

TOP="$(cd "$(dirname "$0")" && pwd)"

SGML_DIR="${PREFIX}/share/sgml"
DAZZLE_DIR="${PREFIX}/share/dazzle"
ETC_SGML_DIR="${PREFIX}/etc/sgml"

echo "=== Installing Dazzle to ${PREFIX} ==="
echo ""

# ============================================
# Step 1: Install OpenSP
# ============================================
echo "Installing OpenSP..."
cd "${TOP}/opensp"
make install

# ============================================
# Step 2: Install OpenJade/dazzle
# ============================================
echo "Installing dazzle binary..."
cd "${TOP}"
make install

# ============================================
# Step 3: Install DSSSL files
# ============================================
echo "Installing DSSSL files to ${DAZZLE_DIR}..."
mkdir -p "${DAZZLE_DIR}"
cp -f "${TOP}/dsssl/builtins.dsl" "${DAZZLE_DIR}/"
cp -f "${TOP}/dsssl/dsssl.dtd" "${DAZZLE_DIR}/"
cp -f "${TOP}/dsssl/fot.dtd" "${DAZZLE_DIR}/"
cp -f "${TOP}/dsssl/style-sheet.dtd" "${DAZZLE_DIR}/"
cp -f "${TOP}/dsssl/extensions.dsl" "${DAZZLE_DIR}/"

# ============================================
# Step 4: Set up catalog chain
# ============================================
echo "Setting up SGML catalog chain..."

# Create directories
mkdir -p "${SGML_DIR}"
mkdir -p "${ETC_SGML_DIR}"

# Create dazzle catalog
cat > "${DAZZLE_DIR}/catalog" << 'EOF'
PUBLIC "-//James Clark//DTD DSSSL Flow Object Tree//EN" "fot.dtd"
PUBLIC "ISO/IEC 10179:1996//DTD DSSSL Architecture//EN" "dsssl.dtd"
PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN" "style-sheet.dtd"
PUBLIC "-//OpenJade//DTD DSSSL Style Sheet//EN" "style-sheet.dtd"
SYSTEM "builtins.dsl" "builtins.dsl"
EOF

# Create /etc/sgml/catalog pointing to dazzle catalog
cat > "${ETC_SGML_DIR}/catalog" << EOF
-- SGML catalog managed by Dazzle --
CATALOG "${DAZZLE_DIR}/catalog"
EOF

# Create master catalog at share/sgml/catalog (this is the default OpenSP looks for)
cat > "${SGML_DIR}/catalog" << EOF
-- Master SGML catalog --
CATALOG "${ETC_SGML_DIR}/catalog"
EOF

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Installed:"
echo "  Binary:      ${PREFIX}/bin/dazzle"
echo "  Libraries:   ${PREFIX}/lib/libosp*, libostyle*, etc."
echo "  DSSSL files: ${DAZZLE_DIR}/"
echo "  Catalogs:    ${SGML_DIR}/catalog"
echo ""
echo "The default catalog chain is:"
echo "  ${SGML_DIR}/catalog"
echo "    -> ${ETC_SGML_DIR}/catalog"
echo "       -> ${DAZZLE_DIR}/catalog"
echo ""
echo "Test with:"
echo "  dazzle --version"
echo "  dazzle -t fot your-document.sgml"
echo ""
