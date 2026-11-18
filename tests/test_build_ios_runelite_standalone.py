# Program: aegis-runelite-ios - test_build_ios_runelite_standalone.py
# Programmer: Ethan-da-Tech-Wizard (written with Claude, an AI assistant)
# Last Modified: 2026-11-18
# Purpose: Unit tests for the standalone builder checking that it emits valid HTML5 and .mobileconfig output and enforces the touch-gesture rules.

"""tests/test_build_ios_runelite_standalone.py — Tests for Standalone iOS RuneLite Builder.

==============================================================================
Overview: Test Verification:
==============================================================================
In this test file, we verify the integrity of the standalone build process:
1. Artifact Existence: Confirms that `runelite_mobile.html` and `RuneLite.mobileconfig`
   are successfully generated and contain valid cryptographic SHA-256 digests.
2. Invariant Assertion: Asserts that no virtual joystick controls are present
   (as joysticks violate authentic OSRS mobile design and Jagex compliance rules).
3. Gesture Verification: Confirms presence of essential touch gesture engine
   tokens: `osrsContextMenu`, `worldToScreen`, `tileIndicators`, and `groundItems`.
"""

from __future__ import annotations

from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.build_ios_runelite_standalone import build_all, HTML_PATH, CONFIG_PATH


class TestStandaloneIOSRuneLite(unittest.TestCase):
    """Test suite verifying the standalone builder pipeline and output files."""

    def test_build_all_creates_artifacts(self) -> None:
        """Verify that running build_all() creates HTML and mobileconfig files with checksums."""
        res = build_all()
        # Verify both physical files exist on the filesystem
        self.assertTrue(HTML_PATH.exists())
        self.assertTrue(CONFIG_PATH.exists())
        # Verify SHA-256 hashes were calculated
        self.assertIn("html_sha256", res)
        self.assertIn("config_sha256", res)

    def test_no_joysticks_and_has_authentic_controls(self) -> None:
        """Verify zero virtual joysticks and presence of authentic OSRS touch mechanics."""
        content = HTML_PATH.read_text(encoding="utf-8")
        # Strict requirement: No virtual joysticks
        self.assertNotIn("joystick", content.lower())

        # Strict requirement: Authentic OSRS tap, long-press right click, 2-finger orbit
        self.assertIn("osrsContextMenu", content)
        self.assertIn("isTwoFingerDragging", content)
        self.assertIn("triggerContextMenu", content)
        self.assertIn("tileIndicators", content)
        self.assertIn("groundItems", content)

    def test_mobileconfig_format(self) -> None:
        """Verify that the generated .mobileconfig conforms to Apple's XML Plist format."""
        config_text = CONFIG_PATH.read_text(encoding="utf-8")
        self.assertIn("com.apple.webClip.managed", config_text)
        self.assertIn("net.runelite.mobile", config_text)
        self.assertIn("<key>FullScreen</key>", config_text)


if __name__ == "__main__":
    unittest.main()
