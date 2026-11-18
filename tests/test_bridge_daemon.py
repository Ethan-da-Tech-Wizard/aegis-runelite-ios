#!/usr/bin/env python3
"""tests/test_bridge_daemon.py — Test suite for Aegis RuneLite iOS Bridge Daemon."""

from __future__ import annotations

import json
from pathlib import Path
import sys
import unittest

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

    def setUp(self):
        self.daemon = HeadlessRuneLiteDaemon()

    def test_daemon_initialization_and_plugins(self):
        manifest = self.daemon.get_plugin_manifest()
        self.assertEqual(manifest["protocol"], PROTOCOL_VERSION)
        self.assertGreaterEqual(len(manifest["plugins"]), 5)
        # Should load the 77 plugins from data catalog if present
        plugin_names = {p.get("class_name") or p.get("name") for p in manifest["plugins"]}
        self.assertTrue(any("Ground" in name or "Tile" in name for name in plugin_names))

    def test_step_game_tick_produces_overlays(self):
        state = self.daemon.step_game_tick()
        self.assertEqual(state["type"], "overlay_batch")
        self.assertEqual(state["protocol"], PROTOCOL_VERSION)
        self.assertGreater(state["tick"], 0)
        self.assertIsInstance(state["overlays"], list)
        self.assertGreater(len(state["overlays"]), 0)

        kinds = {item["kind"] for item in state["overlays"]}
        self.assertIn("tile", kinds)

    def test_touch_input_dispatch(self):
        touch = TouchInputPacket(action="tap", x=240, y=360, duration_ms=50)
        resp = self.daemon.handle_touch_input(touch)
        self.assertEqual(resp["status"], "dispatched")
        self.assertEqual(resp["action"], "tap")
        self.assertEqual(resp["coords"], [240, 360])

    def test_plugin_toggle(self):
        self.daemon.set_plugin_state("TileIndicatorsPlugin", False)
        self.assertFalse(self.daemon.active_plugins.get("TileIndicatorsPlugin"))
        self.daemon.set_plugin_state("TileIndicatorsPlugin", True)
        self.assertTrue(self.daemon.active_plugins.get("TileIndicatorsPlugin"))


class TestSecurityGate(unittest.TestCase):
    """Verifies fail-closed zero-credential security boundary."""

    def test_clean_packet_passes(self):
        clean_data = {
            "type": "overlay",
            "x": 100,
            "y": 200,
            "label": "Iron Ore",
            "nested": {"color": "#FF0000"},
        }
        sanitized = MobileSecurityGate.sanitize_outbound_dict(clean_data)
        self.assertEqual(sanitized["label"], "Iron Ore")

    def test_forbidden_keys_raise_security_violation(self):
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

    def test_nested_forbidden_key_raises(self):
        nested_violation = {
            "ui": {
                "safe_field": True,
                "nested_token": "leaked_token",
            }
        }
        with self.assertRaises(SecurityViolation):
            MobileSecurityGate.sanitize_outbound_dict(nested_violation)

    def test_high_entropy_secret_string_raises(self):
        high_entropy_dict = {
            "display": "A" * 65  # 65 chars of uniform entropy matching pattern
        }
        with self.assertRaises(SecurityViolation):
            MobileSecurityGate.sanitize_outbound_dict(high_entropy_dict)

    def test_audit_mobile_bundle_html(self):
        bundle_path = ROOT / "bridge_daemon" / "frontend" / "ios_runelite_webclip.html"
        self.assertTrue(bundle_path.exists())
        html_content = bundle_path.read_text(encoding="utf-8")
        audit_result = MobileSecurityGate.audit_mobile_bundle(html_content)
        self.assertEqual(audit_result["verdict"], "PASS")
        self.assertTrue(audit_result["zero_credential_guarantee"])
        self.assertEqual(len(audit_result["findings"]), 0)


if __name__ == "__main__":
    unittest.main()
