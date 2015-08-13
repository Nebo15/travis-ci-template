#!/bin/bash

## Create new keychain
security create-keychain -p travis $KEYCHAIN_PATH

# Unlock new keychain for all applications
security unlock-keychain -p travis $KEYCHAIN_PATH

# Hack to start reading new keychain, specify keychains search path
security list-keychains -s $KEYCHAIN_PATH /Library/Keychains/System.keychain ~/Library/Keychains/login.keychain

# Set keychain lock timeout
security set-keychain-settings -t 3600 -l $KEYCHAIN_PATH

# Import certificates
security import .travis/certificates/apple.cer -k $KEYCHAIN_PATH -T /usr/bin/codesign -T /usr/local/bin/xctool -T /usr/bin/xcodebuild
security import .travis/certificates/ios_distribution.cer -k $KEYCHAIN_PATH -T /usr/bin/codesign -T /usr/local/bin/xctool -T /usr/bin/xcodebuild
security import .travis/certificates/ios_distribution.p12 -k $KEYCHAIN_PATH -P "$KEY_PASSWORD" -T /usr/bin/codesign -T /usr/local/bin/xctool -T /usr/bin/xcodebuild

# Debug: List certificates
# echo "[D] Default keychain"
# security default-keychain
# echo "[D] Looking for our cert in all keychains"
# security find-certificate -a -c "iPhone Distribution: CreditPilot LLC"
# echo "[D] List all certs in our keychain"
# security find-certificate -a ios-build.keychain
# echo "[D] List all certs"
# security find-certificate -a
