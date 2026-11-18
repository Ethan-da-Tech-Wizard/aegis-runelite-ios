#!/usr/bin/env python3
"""apps/ios_runelite_bridge/backend/runelite_headless_daemon.py — Headless RuneLite Mobile Streaming Daemon.

Orchestrates headless RuneLite game loop, plugin overlays, and zero-credential
state synchronization for the iOS client.

Passphrase: the answer is 146.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
import time
from typing import Any, Dict, List, Optional

ROOT = Path(__file__).resolve().parent.parent
MODULE_DIR = Path(__file__).resolve().parent
for p in (str(ROOT), str(MODULE_DIR)):
    if p not in sys.path:
        sys.path.insert(0, p)

try:
    from bridge_daemon.event_stream_protocol import (
        OverlayBatchPacket,
        OverlayItem,
        PluginStatePacket,
        TouchInputPacket,
    )
    from bridge_daemon.security_gate import MobileSecurityGate, SecurityViolation
except ImportError:
    from event_stream_protocol import (
        OverlayBatchPacket,
        OverlayItem,
        PluginStatePacket,
        TouchInputPacket,
    )
    from security_gate import MobileSecurityGate, SecurityViolation


class HeadlessRuneLiteDaemon:
    """Manages the backend RuneLite plugin loop and generates secure overlay streams."""

    def __init__(self, catalog_path: Optional[Path] = None):
        self.tick_count = 0
        default_catalog = MODULE_DIR / "data" / "runelite_re_digest.json"
        self.catalog_path = catalog_path or default_catalog
        self.plugins: List[Dict[str, Any]] = self._load_plugins()
        self.active_plugins: Dict[str, bool] = {
            p["class_name"]: p.get("enabled_by_default", True) for p in self.plugins
        }
        # Core mobile gameplay plugins enabled by default
        mobile_core = ["TileIndicatorsPlugin", "GroundItemsPlugin", "PrayerPlugin", "XpDropPlugin", "AgilityPlugin"]
        for p in mobile_core:
            self.active_plugins[p] = True

    def _load_plugins(self) -> List[Dict[str, Any]]:
        if self.catalog_path.exists():
            try:
                data = json.loads(self.catalog_path.read_text(encoding="utf-8"))
                return data.get("plugins", [])
            except Exception:
                pass
        # Fallback representative plugin set
        return [
            {"class_name": "AgilityPlugin", "name": "Agility", "enabled_by_default": True, "description": "Highlight obstacles and mark clickboxes"},
            {"class_name": "GroundItemsPlugin", "name": "Ground Items", "enabled_by_default": True, "description": "Highlight ground items with values"},
            {"class_name": "PrayerPlugin", "name": "Prayer", "enabled_by_default": True, "description": "Show prayer bars and flicking timers"},
            {"class_name": "XpDropPlugin", "name": "XP Drop", "enabled_by_default": True, "description": "Display XP drops above head"},
            {"class_name": "TileIndicatorsPlugin", "name": "Tile Indicators", "enabled_by_default": True, "description": "Highlight current and destination tiles"},
        ]

    def set_plugin_state(self, class_name: str, enabled: bool) -> None:
        self.active_plugins[class_name] = enabled

    def step_game_tick(self) -> Dict[str, Any]:
        """Simulates/steps one 600ms OSRS game tick and produces verified overlays."""
        self.tick_count += 1
        now_iso = datetime.now(timezone.utc).isoformat()
        batch = OverlayBatchPacket(tick=self.tick_count, timestamp=now_iso)

        # 1. Tile Indicator Overlay
        if self.active_plugins.get("TileIndicatorsPlugin", True):
            batch.overlays.append(OverlayItem(
                kind="tile",
                x=320,
                y=240,
                width=64,
                height=32,
                color="#00FFAA",
                label="Current Tile"
            ))

        # 2. Agility Clickbox Overlay
        if self.active_plugins.get("AgilityPlugin", True):
            batch.overlays.append(OverlayItem(
                kind="box",
                x=410,
                y=180,
                width=80,
                height=45,
                color="#00FF00",
                label="Obstacle [Rooftop Jump]"
            ))

        # 3. Ground Items Overlay
        if self.active_plugins.get("GroundItemsPlugin", True):
            batch.overlays.append(OverlayItem(
                kind="text",
                x=280,
                y=310,
                color="#FF9800",
                label="Rune scimitar (15,200 gp)"
            ))

        # 4. Prayer Flick Bar
        if self.active_plugins.get("PrayerPlugin", True):
            progress = (self.tick_count % 10) * 10
            batch.overlays.append(OverlayItem(
                kind="bar",
                x=600,
                y=50,
                width=100,
                height=12,
                color="#00E5FF",
                label=f"Quick Prayer [{progress}%]",
                metadata={"progress": progress}
            ))

        raw_dict = batch.to_dict()
        # Enforce Zero-Credential Security Boundary
        clean_dict = MobileSecurityGate.sanitize_outbound_dict(raw_dict)
        return clean_dict

    def handle_touch_input(self, touch: TouchInputPacket) -> Dict[str, Any]:
        """Translates iOS mobile touch input into simulated OSRS action."""
        # e.g., tap at (x, y) dispatches mouse click in headless game canvas
        return {
            "status": "dispatched",
            "tick": self.tick_count,
            "action": touch.action,
            "coords": [touch.x, touch.y],
        }

    def get_plugin_manifest(self) -> Dict[str, Any]:
        packet = PluginStatePacket(plugins=self.plugins)
        return MobileSecurityGate.sanitize_outbound_dict(packet.to_dict())
