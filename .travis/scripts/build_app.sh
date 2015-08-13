#!/bin/bash

# Archiving
DERIVED_PATH="${BUILD_DIR}/${APPLICATION}/derived"

# Clearing old derived data, just to make sure
rm -rf "${DERIVED_PATH}/*"

# Archiving application
echo "[I] Archiving application '${APPLICATION}' to '${DERIVED_PATH}'."
xctool -workspace "${WORKSPACE}" \
       -scheme "${APPLICATION}" \
       -sdk iphonesimulator \
       build \
       -derivedDataPath "${DERIVED_PATH}" \
       -configuration "Debug" \
       CODE_SIGNING_REQUIRED=NO

if [ -e $DERIVED_PATH ]
then
    echo " ~ Done."
else
    echo "[E] Can't archive application."
    exit 1
fi

APP_PACKAGE_PATH="${DERIVED_PATH}/Build/Products/Debug-iphonesimulator"
APP_PACKAGE_FILE="${APPLICATION}.app"

if [ -e "${APP_PACKAGE_PATH}/${APP_PACKAGE_FILE}" ]
then
    echo " ~ Exported."
else
    echo "[E] Can't locate app file. Build failed!"
    echo "[E] Path: ${APP_PACKAGE_PATH}/${APP_PACKAGE_FILE}"
    ls -l ${APP_PACKAGE_PATH}
    exit 1
fi

echo " ~ Archiving."
APP_PACKAGE_ARCH_FILE="${APPLICATION}.app.tar.gz"
APP_ARCH_PATH="${BUILD_DIR}/${APP_PACKAGE_ARCH_FILE}"

TMP=$(pwd)
cd $APP_PACKAGE_PATH
tar -zcvf "${APP_PACKAGE_ARCH_FILE}" "${APP_PACKAGE_FILE}/"
cd $TMP

echo " ~ Moving to build dir."
mv "${APP_PACKAGE_PATH}/${APP_PACKAGE_ARCH_FILE}" "${BUILD_DIR}"
ls -l ${BUILD_DIR}

if [ -f "${APP_ARCH_PATH}" ]
then
    ARCH_FILE_SIZE=$(wc "${APP_ARCH_PATH}" | cut -f 7 -d ' ')
    ARCH_FILE_SIZE_MB=$(echo "${ARCH_FILE_SIZE}/1024/1024" | bc)
    echo " ~ Exported. File size: ~${ARCH_FILE_SIZE_MB} Mb"
else
    echo "[E] Can't locate app file. Build failed!"
    echo "[E] Path: ${APP_ARCH_PATH}"
    ls -l $BUILD_DIR
    exit 1
fi

