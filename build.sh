#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p ResourceRing.app/Contents/MacOS
xcrun clang -fobjc-arc -framework Cocoa -framework QuartzCore main.m -o ResourceRing.app/Contents/MacOS/ResourceRing
/usr/libexec/PlistBuddy -c "Clear dict" ResourceRing.app/Contents/Info.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string ResourceRing" ResourceRing.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string local.resourcering" ResourceRing.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleName string ResourceRing" ResourceRing.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" ResourceRing.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" ResourceRing.app/Contents/Info.plist
codesign --force --sign - ResourceRing.app
echo "Built ResourceRing.app"
