"""Aegis RuneLite iOS - Headless Streaming Bridge Daemon.

Zero-credential local streaming bridge connecting headless RuneLite sessions
to iOS/iPadOS mobile devices over low-latency event stream protocol.
"""

from .event_stream_protocol import (
    PROTOCOL_VERSION,
    OverlayBatchPacket,
    OverlayItem,
    PluginStatePacket,
    TouchInputPacket,
)
from .runelite_headless_daemon import HeadlessRuneLiteDaemon
from .security_gate import MobileSecurityGate, SecurityViolation

__all__ = [
    "PROTOCOL_VERSION",
    "OverlayBatchPacket",
    "OverlayItem",
    "PluginStatePacket",
    "TouchInputPacket",
    "HeadlessRuneLiteDaemon",
    "MobileSecurityGate",
    "SecurityViolation",
]
