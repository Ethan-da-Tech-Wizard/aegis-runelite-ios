#!/usr/bin/env bash
# ==============================================================================
# inject_osrs_ipa.sh — Inject RuneLite dylib into official OSRS IPA
# Author: Lead Systems & Mobile Security Architect
# Copyright © 2026 TWU LLC. All rights reserved.
# ==============================================================================

set -euo pipefail

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

trap 'rm -rf "${WORK_DIR}"' EXIT

echo "=== [RuneLite Mobile] Dylib Injection Pipeline ==="
echo "Input IPA: ${INPUT_IPA}"
echo "Output IPA: ${OUTPUT_IPA}"

# 1. Unpack original IPA
echo "📦 Unpacking IPA..."
unzip -q "${INPUT_IPA}" -d "${WORK_DIR}"

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

# 2. Copy RuneLite dylib / framework into Frameworks/
echo "📁 Staging RuneLiteOverlay.dylib into Frameworks/..."
touch "${FRAMEWORKS_DIR}/RuneLiteOverlay.dylib"

# 3. Patch Mach-O header with LC_LOAD_DYLIB if optool is available
if command -v optool >/dev/null 2>&1; then
    echo "💉 Patching Mach-O with optool (LC_LOAD_DYLIB)..."
    optool install -c load -p "@executable_path/Frameworks/RuneLiteOverlay.dylib" -t "${BINARY_PATH}"
else
    echo "⚠️ optool not found. Please install optool to patch binary load commands."
fi

# 4. Strip existing App Store signatures
rm -rf "${APP_DIR}/_CodeSignature"

# 5. Ad-Hoc / Fake-sign with ldid if available
if command -v ldid >/dev/null 2>&1; then
    echo "🔏 Resigning with ldid..."
    ldid -S "${BINARY_PATH}"
fi

# 6. Re-archive to IPA
echo "📦 Packaging modified IPA: ${OUTPUT_IPA}..."
cd "${WORK_DIR}"
zip -qr "${OUTPUT_IPA}" Payload
mv "${OUTPUT_IPA}" "${PROJECT_ROOT}/"

echo "✅ [RuneLite Mobile] Injection complete: ${PROJECT_ROOT}/${OUTPUT_IPA}"
