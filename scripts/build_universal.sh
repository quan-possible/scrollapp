#!/bin/bash

# Build script for universal Scrollapp binary
# This creates a .app that works on both Intel and Apple Silicon Macs

set -e

PROJECT_PATH="Scrollapp.xcodeproj"
SCHEME="Scrollapp"
COMMON_XCODEBUILD_ARGS=(-project "$PROJECT_PATH" -scheme "$SCHEME" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)

echo "Building Scrollapp as Universal Binary..."

if [ ! -d "$PROJECT_PATH" ]; then
    if command -v xcodegen >/dev/null 2>&1 && [ -f "project.yml" ]; then
        echo "Generating Xcode project from project.yml..."
        xcodegen generate --spec project.yml
    else
        echo "ERROR: $PROJECT_PATH not found and xcodegen is unavailable"
        exit 1
    fi
fi

# Clean previous builds
echo "Cleaning previous builds..."
xcodebuild "${COMMON_XCODEBUILD_ARGS[@]}" clean
rm -rf build

# Create build directories
mkdir -p build/intel
mkdir -p build/arm64
mkdir -p build/universal

# Build for Intel (x86_64)
echo "Building for Intel (x86_64)..."
xcodebuild "${COMMON_XCODEBUILD_ARGS[@]}" -configuration Release -arch x86_64 ONLY_ACTIVE_ARCH=NO SYMROOT=build/intel build

# Build for Apple Silicon (arm64)  
echo "Building for Apple Silicon (arm64)..."
xcodebuild "${COMMON_XCODEBUILD_ARGS[@]}" -configuration Release -arch arm64 ONLY_ACTIVE_ARCH=NO SYMROOT=build/arm64 build

# Copy the app structure from one of the builds
echo "Creating universal binary..."
cp -R "build/arm64/Release/Scrollapp.app" "build/universal/"

# Use lipo to create universal binary
lipo -create \
    "build/intel/Release/Scrollapp.app/Contents/MacOS/Scrollapp" \
    "build/arm64/Release/Scrollapp.app/Contents/MacOS/Scrollapp" \
    -output "build/universal/Scrollapp.app/Contents/MacOS/Scrollapp"

echo "Universal build complete!"
echo "The app now supports both Intel and Apple Silicon Macs"
echo "Find your universal app in: build/universal/Scrollapp.app"

# Verify the universal binary
echo "Verifying universal binary..."
if [ -f "build/universal/Scrollapp.app/Contents/MacOS/Scrollapp" ]; then
    lipo -info "build/universal/Scrollapp.app/Contents/MacOS/Scrollapp"
    file "build/universal/Scrollapp.app/Contents/MacOS/Scrollapp"
else
    echo "ERROR: Universal binary creation failed"
    exit 1
fi 
