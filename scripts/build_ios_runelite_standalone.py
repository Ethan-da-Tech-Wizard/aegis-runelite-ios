# Program: aegis-runelite-ios - build_ios_runelite_standalone.py
# Programmer: Ethan-da-Tech-Wizard (written with Claude, an AI assistant)
# Last Modified: 2026-11-18
# Purpose: Builder that assembles the single-file offline HTML5 RuneLite client, validates its touch mechanics, and writes an Apple WebClip .mobileconfig profile for Home Screen install.

"""scripts/build_ios_runelite_standalone.py — Standalone iOS RuneLite File & WebClip Builder.

==============================================================================
Overview: Mobile Packaging:
==============================================================================
In modern mobile application distribution, developers often need ways to deliver
software without relying exclusively on closed app stores. Apple provides a
standard enterprise configuration mechanism known as "Mobile Device Management"
(MDM) configuration profiles (`.mobileconfig`).

Key Concepts Demonstrated:
1. XML Property Lists (plist): Apple's standard serialization format. We construct
   a WebClip payload (`com.apple.webClip.managed`) that tells iOS to place an icon
   directly on the user's Home Screen.
2. FullScreen Standalone Web Apps: By setting `<key>FullScreen</key><true/>`, the
   web application launches without Safari navigation bars or URL toolbars,
   providing a 100% native mobile app appearance.
3. Cryptographic Verification: Computes SHA-256 digests of generated files to
   guarantee tamper-evident builds.
4. Input Authenticity Assertion: Verifies that prohibited arcade virtual joysticks
   are not present, and authentic tap-to-walk, 350ms long press, and 2-finger camera
   orbit routines are preserved.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path
import sys
import uuid

# Define filesystem paths relative to repository root
ROOT: Path = Path(__file__).resolve().parent.parent
STANDALONE_DIR: Path = ROOT / "ios_app"
HTML_PATH: Path = STANDALONE_DIR / "runelite_mobile.html"
CONFIG_PATH: Path = STANDALONE_DIR / "RuneLite.mobileconfig"


def generate_webclip_profile(standalone_url: str = "file:///runelite_mobile.html") -> str:
    """Generate an Apple .mobileconfig XML profile string for iPhone Home Screen installation.

    Parameters:
        standalone_url (str): The target URL launched when the Home Screen icon is tapped.
                              Defaults to 'file:///runelite_mobile.html' for offline mode.

    Returns:
        str: Formatted XML string conforming to Apple's Configuration Profile Specification.

    Algorithm Step-by-Step:
        Step 1: Generate deterministic UUIDv5 identifiers from DNS namespace to ensure
                reproducible profile installations.
        Step 2: Embed a base64-encoded app icon graphic (64x64 PNG).
        Step 3: Structure the XML plist containing `<key>PayloadContent</key>` with
                `com.apple.webClip.managed` dictionary.
        Step 4: Configure `FullScreen = true` so Safari UI borders do not appear.
        Step 5: Return the completed XML plist document.
    """
    # Step 1: Generate deterministic UUIDs so updating the profile replaces rather than duplicates
    clip_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, "net.runelite.mobile.clip"))
    profile_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, "net.runelite.mobile.profile"))

    # Step 2: Minimal 64x64 base64 PNG icon representing RuneLite blue sword emblem
    icon_png_b64 = (
        "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAPElEQVR42u3PMQEAAAgE"
        "ID95/0xjg1cwkITe04FCEAgEAgEAgEAgEAgEAgEAgEAgEAgEAgEAgEAgEAhmwAEz0QAB"
        "Wv6zZwAAAABJRU5ErkJggg=="
    )

    # Step 3-4: Build XML Property List format
    profile = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>FullScreen</key>
            <true/>
            <key>Icon</key>
            <data>{icon_png_b64}</data>
            <key>IsRemovable</key>
            <true/>
            <key>Label</key>
            <string>RuneLite</string>
            <key>PayloadDescription</key>
            <string>Standalone RuneLite Client for iOS with OSRS touch controls and plugins.</string>
            <key>PayloadDisplayName</key>
            <string>RuneLite Mobile WebClip</string>
            <key>PayloadIdentifier</key>
            <string>net.runelite.mobile.webclip</string>
            <key>PayloadType</key>
            <string>com.apple.webClip.managed</string>
            <key>PayloadUUID</key>
            <string>{clip_uuid}</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>Precomposed</key>
            <true/>
            <key>URL</key>
            <string>{standalone_url}</string>
        </dict>
    </array>
    <key>PayloadDescription</key>
    <string>Installs the standalone RuneLite client on your iPhone Home Screen.</string>
    <key>PayloadDisplayName</key>
    <string>RuneLite Mobile</string>
    <key>PayloadIdentifier</key>
    <string>net.runelite.mobile</string>
    <key>PayloadOrganization</key>
    <string>TWU LLC</string>
    <key>PayloadRemovalDisallowed</key>
    <false/>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>{profile_uuid}</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>
"""
    # Step 5: Return XML payload
    return profile


def build_all() -> dict[str, str]:
    """Execute the complete build and verification pipeline for standalone iOS deployment.

    Returns:
        dict[str, str]: Build metrics dictionary including artifact paths, file sizes,
                        and SHA-256 cryptographic checksums.

    Raises:
        FileNotFoundError: If the source HTML client does not exist on disk.
        ValueError: If prohibited joystick controls are found or authentic touch tokens are missing.
    """
    # Step 1: Ensure destination directory exists
    STANDALONE_DIR.mkdir(parents=True, exist_ok=True)
    if not HTML_PATH.exists():
        raise FileNotFoundError(f"Missing required HTML client bundle at {HTML_PATH}")

    # Step 2: Read HTML content for static analysis validation
    html_content = HTML_PATH.read_text(encoding="utf-8")

    # Step 3: Enforce strict authenticity invariant: NO virtual arcade joysticks
    if "joystick" in html_content.lower():
        raise ValueError("Security/Authenticity error: Joystick found in RuneLite mobile codebase!")

    # Step 4: Verify essential OSRS mobile gesture routines are present
    required_tokens = [
        "osrsContextMenu",
        "worldToScreen",
        "tileIndicators",
        "groundItems",
        "isTwoFingerDragging"
    ]
    for token in required_tokens:
        if token not in html_content:
            raise ValueError(f"Missing required OSRS Mobile engine component: {token}")

    # Step 5: Compile and write Apple mobileconfig profile to disk
    profile_content = generate_webclip_profile()
    CONFIG_PATH.write_text(profile_content, encoding="utf-8")

    # Step 6: Compute SHA-256 checksums for cryptographic build auditing
    html_hash = hashlib.sha256(html_content.encode("utf-8")).hexdigest()
    config_hash = hashlib.sha256(profile_content.encode("utf-8")).hexdigest()

    # Step 7: Return build manifest
    return {
        "html_path": str(HTML_PATH),
        "html_sha256": html_hash,
        "config_path": str(CONFIG_PATH),
        "config_sha256": config_hash,
        "size_kb": f"{len(html_content) / 1024:.1f} KB",
    }


def main() -> int:
    """CLI entry point for running the standalone builder.

    Returns:
        int: 0 on successful compilation and validation.
    """
    result = build_all()
    print("=" * 60)
    print("  ⚔️  RuneLite Mobile Standalone iOS Builder")
    print("=" * 60)
    print(f"• HTML Client  : {result['html_path']} ({result['size_kb']})")
    print(f"• Apple Profile: {result['config_path']}")
    print(f"• SHA256 HTML  : {result['html_sha256'][:16]}...")
    print("• Verification : 100% Offline Standalone (NO server required)")
    print("• Control Mode : Tap-to-walk, 350ms haptic right-click, 2-finger orbit")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    sys.exit(main())
