#!/bin/bash

# Archiving
ARCHIVE_PATH="${BUILD_DIR}/${APPLICATION}.xcarchive"

# Archiving application
echo "[I] Archiving application '${APPLICATION}' to '${ARCHIVE_PATH}'."
xctool -workspace "${WORKSPACE}" \
       -scheme "${APPLICATION}" \
       -sdk iphoneos \
       archive \
       -archivePath "${ARCHIVE_PATH}" \
       -configuration "${CONFIGURATION}"

if [ -e $ARCHIVE_PATH ]
then
    echo " ~ Done."
else
    echo "[E] Can't archive application."
    exit 1
fi

# Exporting archive to ipa file
IPA_PATH="${BUILD_DIR}/${APPLICATION}.ipa"

echo "[I] Exporting archive to IPA file."
xcodebuild -sdk iphoneos \
           -exportArchive \
           -exportFormat ipa \
           -archivePath "${ARCHIVE_PATH}" \
           -exportPath "${IPA_PATH}" \
           -exportProvisioningProfile "${MAIN_PROVISIONING_PROFILE_NAME}" \
           -configuration "${CONFIGURATION}"

if [ -f "${IPA_PATH}" ]
then
    BUILD_FILE_SIZE=$(wc "${IPA_PATH}" | cut -f 7 -d ' ')
    BUILD_FILE_SIZE_MB=$(echo "${BUILD_FILE_SIZE}/1024/1024" | bc)
    echo " ~ Exported. File size: ~${BUILD_FILE_SIZE_MB} Mb"
else
    echo "[E] Can't locate ipa file. Build failed!"
    exit 1
fi
