# Program: aegis-runelite-ios - runelite_headless_daemon.py
# Programmer: Ethan-da-Tech-Wizard (written with Claude, an AI assistant)
# Last Modified: 2026-11-18
# Purpose: Headless daemon that simulates the 600ms game tick loop, manages overlay plugins, renders overlay boxes and text, and handles mobile touch input.

"""bridge_daemon/runelite_headless_daemon.py — Headless RuneLite Mobile Streaming Daemon.

==============================================================================
Overview: Game Loop Architecture:
==============================================================================
A "game loop" is the core iterative cycle of every video game engine. It performs
three primary stages in sequence:
1. Input Processing: Capturing player actions (touch taps, drags, mouse clicks).
2. World Simulation Update: Calculating entity positions, collisions, and state changes.
3. Rendering: Drawing the updated visual scene or generating HUD overlay batches.

Why 600ms Tick Rate for Old School RuneScape:
Unlike modern high-refresh action games that update physics at 60 Hz or 144 Hz,
Old School RuneScape was originally designed in 2001 (RuneScape 2 / Java engine)
to run on a fixed 0.6-second (600 millisecond) server cycle. Every 600 milliseconds,
the server processes a single "tick" of player combat, movement, food eating, and
prayer toggling. Our headless daemon synchronizes with this exact 600ms timing
pulse (`step_game_tick`) to match official game mechanics accurately.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
import time
from typing import Any, Dict, List, Optional

# Determine directory paths to enable modular local package importing
ROOT = Path(__file__).resolve().parent.parent
MODULE_DIR = Path(__file__).resolve().parent
for p in (str(ROOT), str(MODULE_DIR)):
    if p not in sys.path:
        sys.path.insert(0, p)

# Import wire protocol packets and zero-credential security boundary
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
    """Manages the backend RuneLite plugin loop and generates secure overlay streams.

    This class serves as the virtual engine, loading plugin metadata from a JSON
    catalog, tracking enabled/disabled plugin states, executing per-tick overlay
    synthesis, and routing touch inputs received from iOS devices.
    """

    def __init__(self, catalog_path: Optional[Path] = None) -> None:
        """Initialize the headless daemon, plugin state dictionary, and tick counter.

        Parameters:
            catalog_path (Optional[Path]): Filepath to the plugin reverse-engineering
                                           digest JSON file. If None, defaults to
                                           `bridge_daemon/data/runelite_re_digest.json`.
        """
        # Step 1: Initialize game tick counter to zero
        self.tick_count: int = 0

        # Step 2: Establish the path to the plugin catalog database
        default_catalog = MODULE_DIR / "data" / "runelite_re_digest.json"
        self.catalog_path: Path = catalog_path or default_catalog

        # Step 3: Load available plugins from catalog (or fallback list)
        self.plugins: List[Dict[str, Any]] = self._load_plugins()

        # Step 4: Map plugin class names to their active boolean states
        self.active_plugins: Dict[str, bool] = {
            p["class_name"]: p.get("enabled_by_default", True) for p in self.plugins
        }

        # Step 5: Explicitly enable essential core mobile gameplay plugins
        mobile_core = [
            "TileIndicatorsPlugin",
            "GroundItemsPlugin",
            "PrayerPlugin",
            "XpDropPlugin",
            "AgilityPlugin"
        ]
        for p in mobile_core:
            self.active_plugins[p] = True

    def _load_plugins(self) -> List[Dict[str, Any]]:
        """Load plugin metadata catalog from disk, falling back to core built-in defaults.

        Returns:
            List[Dict[str, Any]]: List of plugin descriptor dictionaries.
        """
        # Check if the external JSON catalog file exists on disk
        if self.catalog_path.exists():
            try:
                data = json.loads(self.catalog_path.read_text(encoding="utf-8"))
                return data.get("plugins", [])
            except Exception:
                # If reading or JSON parsing fails, fall through to default list
                pass

        # Built-in representative fallback plugin list for standalone testing
        return [
            {
                "class_name": "AgilityPlugin",
                "name": "Agility",
                "enabled_by_default": True,
                "description": "Highlight obstacles and mark clickboxes",
            },
            {
                "class_name": "GroundItemsPlugin",
                "name": "Ground Items",
                "enabled_by_default": True,
                "description": "Highlight ground items with values",
            },
            {
                "class_name": "PrayerPlugin",
                "name": "Prayer",
                "enabled_by_default": True,
                "description": "Show prayer bars and flicking timers",
            },
            {
                "class_name": "XpDropPlugin",
                "name": "XP Drop",
                "enabled_by_default": True,
                "description": "Display XP drops above head",
            },
            {
                "class_name": "TileIndicatorsPlugin",
                "name": "Tile Indicators",
                "enabled_by_default": True,
                "description": "Highlight current and destination tiles",
            },
        ]

    def set_plugin_state(self, class_name: str, enabled: bool) -> None:
        """Toggle an individual plugin on or off by its class name.

        Parameters:
            class_name (str): Identifier name of the plugin (e.g. 'TileIndicatorsPlugin').
            enabled (bool): True to activate the plugin, False to deactivate.
        """
        self.active_plugins[class_name] = enabled

    def step_game_tick(self) -> Dict[str, Any]:
        """Simulate one discrete 600ms OSRS game tick and generate sanitized overlays.

        Here we cover how complex systems build up visual scenes by
        querying individual component subsystems. Here, each active plugin
        contributes its visual overlay elements to the batch packet.

        Returns:
            Dict[str, Any]: Scrubbed JSON dictionary containing active overlays,
                            tick index, and timestamp, verified by `MobileSecurityGate`.
        """
        # Step 1: Advance the discrete engine tick counter
        self.tick_count += 1

        # Step 2: Capture the current UTC timestamp for frame latency metrics
        now_iso = datetime.now(timezone.utc).isoformat()

        # Step 3: Instantiate a fresh batch packet for this game tick
        batch = OverlayBatchPacket(tick=self.tick_count, timestamp=now_iso)

        # Step 4: Synthesize Overlay 1 — Tile Indicators
        # Draws a cyan parallelogram/tile outline indicating where the character is standing
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

        # Step 5: Synthesize Overlay 2 — Agility Obstacle Clickbox
        # Draws a high-visibility green bounding box around an obstacle (e.g. Rooftop Jump)
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

        # Step 6: Synthesize Overlay 3 — Ground Items Text Label
        # Displays the item name and Grand Exchange trade value on the ground
        if self.active_plugins.get("GroundItemsPlugin", True):
            batch.overlays.append(OverlayItem(
                kind="text",
                x=280,
                y=310,
                color="#FF9800",
                label="Rune scimitar (15,200 gp)"
            ))

        # Step 7: Synthesize Overlay 4 — Quick Prayer Bar Meter
        # Displays dynamic progress of the player's quick prayer flicking timer
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

        # Step 8: Convert dataclass batch to dictionary
        raw_dict = batch.to_dict()

        # Step 9: Enforce Zero-Credential Security Boundary
        # Any accidental secret keys are scrubbed or raise an exception before output
        clean_dict = MobileSecurityGate.sanitize_outbound_dict(raw_dict)
        return clean_dict

    def handle_touch_input(self, touch: TouchInputPacket) -> Dict[str, Any]:
        """Translate incoming iOS mobile touch gestures into game actions.

        In 1:1 input compliance, a mobile tap event maps directly to an in-game click
        at the specified virtual canvas coordinates.

        Parameters:
            touch (TouchInputPacket): Validated touch event received from the iOS client.

        Returns:
            Dict[str, Any]: Status dictionary indicating the input was dispatched.
        """
        return {
            "status": "dispatched",
            "tick": self.tick_count,
            "action": touch.action,
            "coords": [touch.x, touch.y],
        }

    def get_plugin_manifest(self) -> Dict[str, Any]:
        """Generate a complete manifest of all available plugins for client discovery.

        Returns:
            Dict[str, Any]: Sanitized plugin state dictionary.
        """
        packet = PluginStatePacket(plugins=self.plugins)
        return MobileSecurityGate.sanitize_outbound_dict(packet.to_dict())
