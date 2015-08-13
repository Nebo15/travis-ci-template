#!/bin/bash
BASE_DIR=$(pwd)
SCRIPTS_DIR="${BASE_DIR}/.travis/scripts"
BUILD_DIR="${BASE_DIR}/${BUILD_DIR}"

echo ""
echo "=== CONFIGURING ENVIRONMENT ==="
echo ""
source $BASE_DIR/bin/setenv.sh

echo "Cleaning old artifacts"
rm -rf "${BUILD_DIR}/*"

# Cleaning dot files, http://stackoverflow.com/a/19950020/999889
dot_clean ./

echo ""
echo "=== BUILDING APP FILE (for Appium testing) ==="
echo ""
source $SCRIPTS_DIR/build_app.sh

echo ""
echo "=== BUILDING IPA FILE ==="
echo ""
source $SCRIPTS_DIR/build_ipa.sh

echo ""
echo "=== UPLOADING APP AND IPA files ==="
echo ""
source $SCRIPTS_DIR/upload.sh
