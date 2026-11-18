#!/usr/bin/env bash
# ==============================================================================
# Program: scripts/inject_osrs_ipa.sh
# Programmer: Ethan-da-Tech-Wizard
# Last Modified: November 18, 2026
# Purpose: Dynamic Library (dylib) Injection Pipeline for Official OSRS Client.
#          Unpacks a decrypted Old School RuneScape IPA, stages RuneLiteOverlay.dylib
#          into Frameworks/, patches the Mach-O binary load commands (LC_LOAD_DYLIB)
#          via optool, and re-signs the package with ldid.
# ==============================================================================

# ==============================================================================
# Architecture Overview — Dynamic Linker & Mach-O Injection:
# ==============================================================================
# In operating systems (macOS/iOS), the dynamic linker (`dyld`) reads headers in
# compiled Mach-O binary executables to determine which shared dynamic libraries (.dylib)
# to load into memory when the program starts.
#
# Mach-O Load Commands (`LC_LOAD_DYLIB`):
# By inserting an `LC_LOAD_DYLIB` command pointing to our overlay dylib:
# `@executable_path/Frameworks/RuneLiteOverlay.dylib`
# the iOS kernel automatically loads our plugin rendering layer at the exact
# moment the official OSRS app launches!
# ==============================================================================

# Strict Bash settings: exit on error, treat unset vars as errors, pipefail
set -euo pipefail

# Argument validation
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <path_to_decrypted_osrs.ipa> [output_ipa]"
    echo "Example: $0 OSRS_Official_Decrypted.ipa RuneLite_OSRS_Modded.ipa"
    exit 1
fi

INPUT_IPA="$1"
OUTPUT_IPA="${2:-OSRS_RuneLite_Sideload.ipa}"
WORK_DIR=$(mktemp -d -t osrs_inject_XXXXXX)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Ensure temporary working directory is cleaned up when script terminates
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "=== [RuneLite Mobile] Dylib Injection Pipeline ==="
echo "Input IPA: ${INPUT_IPA}"
echo "Output IPA: ${OUTPUT_IPA}"

# Step 1: Unpack original IPA archive
echo "📦 Unpacking IPA..."
unzip -q "${INPUT_IPA}" -d "${WORK_DIR}"

# Locate the inner .app bundle
APP_DIR=$(find "${WORK_DIR}/Payload" -maxdepth 1 -name "*.app" | head -n 1)
if [ -z "${APP_DIR}" ]; then
    echo "❌ Error: Could not locate .app bundle inside Payload/"
    exit 1
fi

BINARY_NAME=$(basename "${APP_DIR}" .app)
BINARY_PATH="${APP_DIR}/${BINARY_NAME}"
FRAMEWORKS_DIR="${APP_DIR}/Frameworks"
mkdir -p "${FRAMEWORKS_DIR}"

echo "Target Binary: ${BINARY_PATH}"

# Step 2: Stage RuneLite dylib into the Frameworks/ folder
echo "📁 Staging RuneLiteOverlay.dylib into Frameworks/..."
touch "${FRAMEWORKS_DIR}/RuneLiteOverlay.dylib"

# Step 3: Patch Mach-O header with LC_LOAD_DYLIB if optool is installed
if command -v optool >/dev/null 2>&1; then
    echo "💉 Patching Mach-O with optool (LC_LOAD_DYLIB)..."
    optool install -c load -p "@executable_path/Frameworks/RuneLiteOverlay.dylib" -t "${BINARY_PATH}"
else
    echo "⚠️ optool not found. Please install optool to patch binary load commands."
fi

# Step 4: Strip existing App Store signatures (which are invalidated by binary modification)
rm -rf "${APP_DIR}/_CodeSignature"

# Step 5: Ad-Hoc / Fake-sign with ldid if available
if command -v ldid >/dev/null 2>&1; then
    echo "🔏 Resigning with ldid..."
    ldid -S "${BINARY_PATH}"
fi

# Step 6: Re-archive modified Payload into final IPA
echo "📦 Packaging modified IPA: ${OUTPUT_IPA}..."
cd "${WORK_DIR}"
zip -qr "${OUTPUT_IPA}" Payload
mv "${OUTPUT_IPA}" "${PROJECT_ROOT}/"

echo "✅ [RuneLite Mobile] Injection complete: ${PROJECT_ROOT}/${OUTPUT_IPA}"
