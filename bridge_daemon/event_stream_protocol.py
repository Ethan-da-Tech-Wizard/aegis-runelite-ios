# Program: aegis-runelite-ios - event_stream_protocol.py
# Programmer: Ethan-da-Tech-Wizard (written with Claude, an AI assistant)
# Last Modified: 2026-11-18
# Purpose: Defines the typed dataclasses for overlay elements, per-tick batch packets, touch input, and plugin state exchanged between the desktop daemon and the mobile client.

"""bridge_daemon/event_stream_protocol.py — Protocol & Wire Types for iOS RuneLite Bridge.

==============================================================================
Overview:
==============================================================================
In modern distributed computing, network communication requires an agreed-upon
"wire protocol" — a set of standard data structures and conventions that both
sender and receiver understand.

Why We Use Dataclasses in Python:
Python's `@dataclass` decorator automatically generates boilerplate methods like
`__init__()`, `__repr__()`, and `__eq__()`. This allows developers
to focus on defining clean, strongly-typed domain models
rather than repetitive constructor code.

Why Tick-Based Pacing:
Old School RuneScape (OSRS) operates on a discrete heartbeat loop where 1 tick
equals exactly 600 milliseconds (0.6 seconds). Every tick, the game engine
advances character movement, combat calculations, and environmental updates.
Our `OverlayBatchPacket` bundles all overlay updates for each 600ms tick so the
mobile client renders graphics in lockstep with the game state.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
import json
from typing import Any, Dict, List, Optional

# Protocol version identifier string used for handshake validation.
# When a client connects, comparing this string prevents version mismatch bugs.
PROTOCOL_VERSION: str = "twu.runelite-mobile.v1"


@dataclass
class OverlayItem:
    """An individual plugin visual overlay primitive.

    In graphical user interface (GUI) programming, complex HUDs (Heads-Up Displays)
    are composed of simple 2D primitives: bounding boxes, ground tiles, text labels,
    and progress bars.

    Attributes:
        kind (str): The visual primitive type:
                    - "tile": Isometric ground tile boundary highlight.
                    - "box": 2D rectangular bounding box (e.g. inventory or UI slot).
                    - "text": Floating string label (e.g. item names, hitpoints).
                    - "bar": Horizontal status/prayer/cooldown meter.
                    - "npc_highlight": Hull or bounding polygon around active monsters.
        x (int): Horizontal pixel coordinate on the virtual display canvas.
        y (int): Vertical pixel coordinate on the virtual display canvas.
        width (int): Width of the bounding area in pixels (defaults to 0 for point items).
        height (int): Height of the bounding area in pixels (defaults to 0 for point items).
        color (str): Hexadecimal RGB color string (e.g., "#00FF00" for bright green).
        label (str): Optional text string displayed inside or adjacent to the overlay.
        metadata (Dict[str, Any]): Dictionary of arbitrary plugin metadata (e.g. item values, IDs).
    """
    kind: str  # Type of graphical primitive to draw
    x: int  # X-coordinate on screen
    y: int  # Y-coordinate on screen
    width: int = 0  # Width of primitive
    height: int = 0  # Height of primitive
    color: str = "#00FF00"  # Default accent color: RuneScape high-visibility green
    label: str = ""  # Display text
    metadata: Dict[str, Any] = field(default_factory=dict)  # Extensible metadata dictionary


@dataclass
class OverlayBatchPacket:
    """Batch of active overlays generated during a single 600ms game tick.

    In game engine design, transmitting individual overlays over the network one by one
    would introduce massive TCP/HTTP overhead. Instead, we perform "batching" — grouping
    all active visual indicators for the current tick into a single network packet.

    Attributes:
        tick (int): Monotonically increasing game tick number (increments every 600ms).
        timestamp (str): ISO 8601 UTC timestamp of when the batch was synthesized.
        overlays (List[OverlayItem]): Collection of visual overlay items to render.
    """
    tick: int  # Current game tick counter
    timestamp: str  # Timestamp string for frame latency calculation
    overlays: List[OverlayItem] = field(default_factory=list)  # List of overlay elements

    def to_dict(self) -> Dict[str, Any]:
        """Serialize the packet into a Python dictionary ready for JSON transmission.

        Returns:
            Dict[str, Any]: A dictionary formatted for network transport over WebSockets
                            or HTTP Server-Sent Events (SSE).
        """
        # Step 1: Pack the outer envelope with protocol metadata and tick info
        # Step 2: Convert each internal OverlayItem dataclass to a dict using `asdict()`
        return {
            "type": "overlay_batch",
            "protocol": PROTOCOL_VERSION,
            "tick": self.tick,
            "timestamp": self.timestamp,
            "overlays": [asdict(o) for o in self.overlays],
        }


@dataclass
class TouchInputPacket:
    """Touch event received from the iOS mobile interface.

    In compliance with Jagex's strict 1:1 input rule, every physical touch gesture
    on the mobile screen maps to exactly one mouse action on the headless client.
    Macros, sequence generators, and multi-action buttons are strictly prohibited.

    Attributes:
        action (str): The physical touch gesture:
                      - "tap": Short finger tap (maps to Left Click).
                      - "right_click": 350ms long press with haptic feedback (maps to Right Click).
                      - "drag_start": Beginning of a 2-finger camera orbit or item drag.
                      - "drag_move": Delta movement updates during an ongoing drag.
                      - "drag_end": Finger release terminating the drag gesture.
        x (int): Horizontal touch coordinate on the mobile screen.
        y (int): Vertical touch coordinate on the mobile screen.
        duration_ms (int): Duration in milliseconds that the touch contact persisted.
        timestamp (str): ISO 8601 UTC timestamp generated when touch contact began.
    """
    action: str  # Gesture kind ("tap", "right_click", "drag_start", "drag_move", "drag_end")
    x: int  # Touch X position
    y: int  # Touch Y position
    duration_ms: int = 0  # Contact duration in milliseconds
    timestamp: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> TouchInputPacket:
        """Construct a TouchInputPacket instance from an incoming JSON dictionary.

        Parameters:
            data (Dict[str, Any]): Parsed JSON payload received from HTTP POST `/api/touch`.

        Returns:
            TouchInputPacket: Strongly-typed touch packet with type-sanitized fields.
        """
        # Step 1: Extract action string, falling back to safe "tap" default
        # Step 2: Safely cast coordinate numbers to integers
        # Step 3: Instantiate and return the validated TouchInputPacket
        return cls(
            action=data.get("action", "tap"),
            x=int(data.get("x", 0)),
            y=int(data.get("y", 0)),
            duration_ms=int(data.get("duration_ms", 0)),
            timestamp=data.get("timestamp", datetime.now(timezone.utc).isoformat()),
        )


@dataclass
class PluginStatePacket:
    """Current state of plugins loaded on the headless backend.

    Attributes:
        plugins (List[Dict[str, Any]]): Manifest of available plugins, containing their
                                       name, enabled status, description, and settings.
    """
    plugins: List[Dict[str, Any]]

    def to_dict(self) -> Dict[str, Any]:
        """Serialize plugin manifest into wire-ready dictionary.

        Returns:
            Dict[str, Any]: Dictionary representation including protocol version.
        """
        return {
            "type": "plugin_state",
            "protocol": PROTOCOL_VERSION,
            "plugins": self.plugins,
        }
