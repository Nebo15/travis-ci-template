#!/bin/bash

brew update >> /dev/null
brew update
if brew outdated | grep -qx xctool; then brew upgrade xctool; fi
brew install xcproj
xctool -v
gem install cupertino --no-ri --no-rdoc

COCOAPODS_VERSION=$(cat Podfile.lock | grep "COCOAPODS:" | awk -F' ' '{print $2}')
gem install cocoapods -v $COCOAPODS_VERSION --no-ri --no-rdoc
