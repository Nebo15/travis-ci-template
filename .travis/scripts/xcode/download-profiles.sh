#!/bin/bash
## Import provision profile

mkdir -p .travis/profiles
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles/

echo "[I] Downloading provisioning profiles."
TMP=$(PWD)
cd .travis/profiles
ios profiles:download:all --type distribution -u "madrobot@nebo15.com" -p "${APPSTORE_PASSWORD}" >> /dev/null
cd $TMP

echo "[I] Copying provisioning profiles to for XCode."
cp -R .travis/profiles/ ~/Library/MobileDevice/Provisioning\ Profiles/

echo "[I] List of available provisioning profiles: "
ls -l ~/Library/MobileDevice/Provisioning\ Profiles/
