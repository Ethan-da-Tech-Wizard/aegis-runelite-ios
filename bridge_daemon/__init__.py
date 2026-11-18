# Program: aegis-runelite-ios - __init__.py
# Programmer: Ethan-da-Tech-Wizard (written with Claude, an AI assistant)
# Last Modified: 2026-11-18
# Purpose: Package initializer describing the local streaming bridge that connects a desktop RuneLite session to mobile iOS/iPadOS clients.

"""Aegis RuneLite iOS - Headless Streaming Bridge Daemon.

==============================================================================
Architecture overview:
==============================================================================
In introductory computer science, client-server architecture forms
the foundation of networked systems. In this architecture:
1. Server (Desktop Daemon): Runs headless Old School RuneScape logic and RuneLite
   plugins at a strict 600ms tick rate (the internal engine heartbeat of RuneScape).
2. Protocol (Event Stream): Encapsulates game overlays (ground items, agility helpers,
   tile markers) into strongly typed, serialized JSON data packets.
3. Security Boundary (SecurityGate): Enforces a "Fail-Closed" zero-credential policy.
   No passwords, session cookies, auth tokens, or bank PINs are permitted to cross
   the bridge to mobile devices.
4. Client (iOS Device): Renders visual overlays on top of the native display and
   sends back 1:1 hardware touch inputs (taps, drags, holds).
"""

from .event_stream_protocol import (
    # Protocol Version Constant: Ensures client and server versions match
    PROTOCOL_VERSION,
    # Data Model: Batch container holding multiple visual overlay primitives
    OverlayBatchPacket,
    # Data Model: Single graphical overlay primitive (text, tile, polygon, circle)
    OverlayItem,
    # Data Model: Configuration packet enabling or disabling specific plugins
    PluginStatePacket,
    # Data Model: Touch gesture packet carrying screen coordinates and duration
    TouchInputPacket,
)
from .runelite_headless_daemon import HeadlessRuneLiteDaemon
from .security_gate import MobileSecurityGate, SecurityViolation

# Explicitly export the public symbols for external consumers
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
