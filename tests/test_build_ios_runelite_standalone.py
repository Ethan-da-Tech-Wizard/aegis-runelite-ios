#!/usr/bin/env python3
"""scripts/test_build_ios_runelite_standalone.py — Tests for Standalone iOS RuneLite Builder."""

from __future__ import annotations

from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.build_ios_runelite_standalone import build_all, HTML_PATH, CONFIG_PATH


class TestStandaloneIOSRuneLite(unittest.TestCase):

    def test_build_all_creates_artifacts(self):
        res = build_all()
        self.assertTrue(HTML_PATH.exists())
        self.assertTrue(CONFIG_PATH.exists())
        self.assertIn("html_sha256", res)
        self.assertIn("config_sha256", res)

    def test_no_joysticks_and_has_authentic_controls(self):
        content = HTML_PATH.read_text(encoding="utf-8")
        # Strict requirement: No joysticks
        self.assertNotIn("joystick", content.lower())

        # Strict requirement: OSRS tap, long-press right click, 2-finger orbit
        self.assertIn("osrsContextMenu", content)
        self.assertIn("isTwoFingerDragging", content)
        self.assertIn("triggerContextMenu", content)
        self.assertIn("tileIndicators", content)
        self.assertIn("groundItems", content)

    def test_mobileconfig_format(self):
        config_text = CONFIG_PATH.read_text(encoding="utf-8")
        self.assertIn("com.apple.webClip.managed", config_text)
        self.assertIn("net.runelite.mobile", config_text)
        self.assertIn("<key>FullScreen</key>", config_text)


if __name__ == "__main__":
    unittest.main()
