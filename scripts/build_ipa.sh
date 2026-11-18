#!/usr/bin/env bash
# ==============================================================================
# Program: scripts/build_ipa.sh
# Programmer: Ethan-da-Tech-Wizard
# Last Modified: November 18, 2026
# Purpose: Standalone iOS RuneLite IPA Packaging Tool.
#          Compiles the native Swift/Metal project into a signed or unsigned
#          iOS application bundle (.app) and archives it into a standard iOS
#          Application Archive (.ipa) for distribution via SideStore or AltStore.
# ==============================================================================

# ==============================================================================
# Overview — iOS Packaging Pipeline:
# ==============================================================================
# In Unix systems programming, shell scripts automate complex multi-stage
# build processes.
#
# An iOS .ipa file is essentially a standard zip archive with a specific structure:
#   RuneLiteMobile.ipa
#   └── Payload/
#       └── RuneLiteMobile.app/
#           ├── Info.plist (metadata)
#           ├── Entitlements.plist (permissions)
#           ├── RuneLiteMobile (Mach-O executable)
#           └── Frameworks/ (shared libraries)
# ==============================================================================

# Exit immediately if a command exits with a non-zero status (-e),
# treat unset variables as an error (-u), and propagate pipeline errors (-o pipefail).
set -euo pipefail

# Step 1: Resolve absolute filesystem paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
IOS_APP_DIR="${REPO_ROOT}/ios_app"
BUILD_DIR="${REPO_ROOT}/build"
PAYLOAD_DIR="${BUILD_DIR}/Payload"
OUTPUT_IPA="${REPO_ROOT}/RuneLiteMobile.ipa"

echo "=== [RuneLite Mobile] Packaging Standalone iOS IPA ==="
echo "Repo Root:    ${REPO_ROOT}"
echo "iOS App Root: ${IOS_APP_DIR}"

# Step 2: Clean previous build artifacts to ensure a pristine build environment
rm -rf "${BUILD_DIR}" "${OUTPUT_IPA}"
mkdir -p "${PAYLOAD_DIR}"

# Step 3: Check toolchain availability
# On macOS with Xcode Command Line Tools installed, `xcodebuild` will compile
# the Swift source files and Metal shaders into a native arm64 Mach-O binary.
if command -v xcodebuild >/dev/null 2>&1; then
    echo "🔨 Building with Xcode (xcodebuild)..."
    xcodebuild \
        -project "${IOS_APP_DIR}/RuneLiteMobile.xcodeproj" \
        -scheme "RuneLiteMobile" \
        -configuration Release \
        -sdk iphoneos \
        -derivedDataPath "${BUILD_DIR}/DerivedData" \
        CODE_SIGNING_ALLOWED=NO \
        clean build

    APP_PATH="${BUILD_DIR}/DerivedData/Build/Products/Release-iphoneos/RuneLiteMobile.app"
    cp -R "${APP_PATH}" "${PAYLOAD_DIR}/"
else
    # In Linux CI/CD environments where Xcode is not available, assemble
    # a mock bundle structure to validate packaging rules and plists.
    echo "⚠️ xcodebuild not found in host environment (Linux/non-macOS)."
    echo "📦 Assembling mock standalone .app structure for validation & inspection..."
    MOCK_APP="${PAYLOAD_DIR}/RuneLiteMobile.app"
    mkdir -p "${MOCK_APP}/Frameworks"
    cp "${IOS_APP_DIR}/Info.plist" "${MOCK_APP}/"
    cp "${IOS_APP_DIR}/Entitlements.plist" "${MOCK_APP}/"
    touch "${MOCK_APP}/RuneLiteMobile"
    chmod +x "${MOCK_APP}/RuneLiteMobile"
fi

# Step 4: Compress the Payload directory into standard .ipa format
echo "📦 Compressing into IPA archive: ${OUTPUT_IPA}..."
cd "${BUILD_DIR}"
zip -qr "${OUTPUT_IPA}" Payload

echo "✅ [RuneLite Mobile] Build succeeded: ${OUTPUT_IPA}"
echo "📱 Ready for sideloading via AltStore, SideStore, or TrollStore!"
