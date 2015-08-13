#!/bin/bash
security delete-keychain $KEYCHAIN_PATH
rm -Rf ~/Library/MobileDevice/Provisioning\ Profiles/*
