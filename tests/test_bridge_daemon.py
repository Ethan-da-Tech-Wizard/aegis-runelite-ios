# ==============================================================================
# Program: tests/test_bridge_daemon.py
# Programmer: Ethan-da-Tech-Wizard
# Last Modified: November 18, 2026
# Purpose: Unit Test Suite for Aegis RuneLite iOS Bridge Daemon.
#          Validates the headless simulation tick loop, overlay batch production,
#          touch input handling, plugin toggle state transitions, and the
#          fail-closed zero-credential security boundary.
# ==============================================================================

"""tests/test_bridge_daemon.py — Test suite for Aegis RuneLite iOS Bridge Daemon.

==============================================================================
Overview: Test-Driven Development (TDD):
==============================================================================
In computer science, unit testing verifies that individual components (units) of
source code perform their intended tasks correctly in isolation.
Python's built-in `unittest` module provides test runners, assertions, and test fixtures:
- `setUp()`: Prepares the test fixture before each test method runs.
- `assertEqual()`, `assertTrue()`, `assertRaises()`: Verification assertions.

What These Tests Prove:
1. Engine Correctness: The headless daemon correctly steps through 600ms OSRS
   ticks and synthesizes valid graphical overlay primitives.
2. 1:1 Input Dispatch: Mobile touch events are converted accurately into coordinate
   packets for the headless canvas.
3. Fail-Closed Security: Outbound packets containing sensitive authentication
   keys (`password`, `auth_token`, `bank_pin`) or high-entropy tokens are
   immediately rejected by raising `SecurityViolation`.
4. Bundle Auditing: Confirms that the static frontend bundle contains zero
   hardcoded credentials.
"""

from __future__ import annotations

import json
from pathlib import Path
import sys
import unittest

# Ensure the repository root is on sys.path so modules can be imported
ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from bridge_daemon.event_stream_protocol import (
    PROTOCOL_VERSION,
    OverlayBatchPacket,
    OverlayItem,
    PluginStatePacket,
    TouchInputPacket,
)
from bridge_daemon.runelite_headless_daemon import HeadlessRuneLiteDaemon
from bridge_daemon.security_gate import MobileSecurityGate, SecurityViolation


class TestHeadlessRuneLiteDaemon(unittest.TestCase):
    """Verifies the headless game loop, plugin overlays, and touch dispatching."""

    def setUp(self) -> None:
        """Create a fresh daemon instance before each test run."""
        self.daemon = HeadlessRuneLiteDaemon()

    def test_daemon_initialization_and_plugins(self) -> None:
        """Verify the plugin catalog loads successfully and exports valid manifests."""
        manifest = self.daemon.get_plugin_manifest()
        # Verify protocol version string matches
        self.assertEqual(manifest["protocol"], PROTOCOL_VERSION)
        # Ensure at least the core plugins are loaded
        self.assertGreaterEqual(len(manifest["plugins"]), 5)
        # Check that standard RuneLite plugins like Ground Items or Tile Indicators are present
        plugin_names = {p.get("class_name") or p.get("name") for p in manifest["plugins"]}
        self.assertTrue(any("Ground" in name or "Tile" in name for name in plugin_names))

    def test_step_game_tick_produces_overlays(self) -> None:
        """Verify that advancing a 600ms tick generates active visual overlays."""
        state = self.daemon.step_game_tick()
        self.assertEqual(state["type"], "overlay_batch")
        self.assertEqual(state["protocol"], PROTOCOL_VERSION)
        self.assertGreater(state["tick"], 0)
        self.assertIsInstance(state["overlays"], list)
        self.assertGreater(len(state["overlays"]), 0)

        kinds = {item["kind"] for item in state["overlays"]}
        self.assertIn("tile", kinds)

    def test_touch_input_dispatch(self) -> None:
        """Verify that 1:1 hardware touch inputs are correctly recorded and dispatched."""
        touch = TouchInputPacket(action="tap", x=240, y=360, duration_ms=50)
        resp = self.daemon.handle_touch_input(touch)
        self.assertEqual(resp["status"], "dispatched")
        self.assertEqual(resp["action"], "tap")
        self.assertEqual(resp["coords"], [240, 360])

    def test_plugin_toggle(self) -> None:
        """Verify that plugins can be toggled on and off dynamically at runtime."""
        self.daemon.set_plugin_state("TileIndicatorsPlugin", False)
        self.assertFalse(self.daemon.active_plugins.get("TileIndicatorsPlugin"))
        self.daemon.set_plugin_state("TileIndicatorsPlugin", True)
        self.assertTrue(self.daemon.active_plugins.get("TileIndicatorsPlugin"))


class TestSecurityGate(unittest.TestCase):
    """Verifies fail-closed zero-credential security boundary."""

    def test_clean_packet_passes(self) -> None:
        """Verify that non-sensitive packets pass through the sanitizer intact."""
        clean_data = {
            "type": "overlay",
            "x": 100,
            "y": 200,
            "label": "Iron Ore",
            "nested": {"color": "#FF0000"},
        }
        sanitized = MobileSecurityGate.sanitize_outbound_dict(clean_data)
        self.assertEqual(sanitized["label"], "Iron Ore")

    def test_forbidden_keys_raise_security_violation(self) -> None:
        """Verify that any dictionary containing credential keys raises SecurityViolation."""
        violations = [
            {"password": "secret_password_123"},
            {"auth_token": "bearer 12345"},
            {"session": "xyz"},
            {"bank_pin": "1234"},
            {"private_key": "rsa_key_here"},
            {"user_credential": "val"},
        ]
        for bad_dict in violations:
            with self.assertRaises(SecurityViolation):
                MobileSecurityGate.sanitize_outbound_dict(bad_dict)

    def test_nested_forbidden_key_raises(self) -> None:
        """Verify that deeply nested dictionaries containing credential keys also fail."""
        nested_violation = {
            "ui": {
                "safe_field": True,
                "nested_token": "leaked_token",
            }
        }
        with self.assertRaises(SecurityViolation):
            MobileSecurityGate.sanitize_outbound_dict(nested_violation)

    def test_high_entropy_secret_string_raises(self) -> None:
        """Verify that high-entropy secret string values raise SecurityViolation."""
        high_entropy_dict = {
            "display": "A" * 65  # 65 chars of uniform entropy matching pattern
        }
        with self.assertRaises(SecurityViolation):
            MobileSecurityGate.sanitize_outbound_dict(high_entropy_dict)

    def test_audit_mobile_bundle_html(self) -> None:
        """Verify that static bundle audit verifies zero hardcoded credentials."""
        bundle_path = ROOT / "bridge_daemon" / "frontend" / "ios_runelite_webclip.html"
        self.assertTrue(bundle_path.exists())
        html_content = bundle_path.read_text(encoding="utf-8")
        audit_result = MobileSecurityGate.audit_mobile_bundle(html_content)
        self.assertEqual(audit_result["verdict"], "PASS")
        self.assertTrue(audit_result["zero_credential_guarantee"])
        self.assertEqual(len(audit_result["findings"]), 0)


if __name__ == "__main__":
    unittest.main()
