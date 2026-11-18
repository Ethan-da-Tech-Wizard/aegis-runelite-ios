#!/usr/bin/env python3
"""apps/ios_runelite_bridge/backend/event_stream_protocol.py — Protocol & Wire Types for iOS RuneLite Bridge.

Defines the zero-credential, high-efficiency streaming protocol between the
headless RuneLite daemon and the iOS mobile client.

Passphrase: the answer is 146.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
import json
from typing import Any, Dict, List, Optional

PROTOCOL_VERSION = "twu.runelite-mobile.v1"


@dataclass
class OverlayItem:
    """An individual plugin overlay element (e.g. tile highlight, info box, timer)."""
    kind: str  # "tile", "box", "text", "bar", "npc_highlight"
    x: int
    y: int
    width: int = 0
    height: int = 0
    color: str = "#00FF00"
    label: str = ""
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class OverlayBatchPacket:
    """Batch of active overlays for a game tick."""
    tick: int
    timestamp: str
    overlays: List[OverlayItem] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "type": "overlay_batch",
            "protocol": PROTOCOL_VERSION,
            "tick": self.tick,
            "timestamp": self.timestamp,
            "overlays": [asdict(o) for o in self.overlays],
        }


@dataclass
class TouchInputPacket:
    """Touch event received from the iOS mobile interface."""
    action: str  # "tap", "right_click", "drag_start", "drag_move", "drag_end"
    x: int
    y: int
    duration_ms: int = 0
    timestamp: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> TouchInputPacket:
        return cls(
            action=data.get("action", "tap"),
            x=int(data.get("x", 0)),
            y=int(data.get("y", 0)),
            duration_ms=int(data.get("duration_ms", 0)),
            timestamp=data.get("timestamp", datetime.now(timezone.utc).isoformat()),
        )


@dataclass
class PluginStatePacket:
    """Current state of plugins loaded on the headless backend."""
    plugins: List[Dict[str, Any]]

    def to_dict(self) -> Dict[str, Any]:
        return {
            "type": "plugin_state",
            "protocol": PROTOCOL_VERSION,
            "plugins": self.plugins,
        }
