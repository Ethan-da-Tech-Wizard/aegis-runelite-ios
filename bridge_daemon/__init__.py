# ==============================================================================
# Program: bridge_daemon/__init__.py
# Programmer: Ethan-da-Tech-Wizard
# Course: CIS 156 / Advanced Systems
# Last Modified: November 18, 2026
# Purpose: Headless Streaming Bridge Daemon Package Initializer.
#          Defines the public interface for the zero-credential local streaming
#          bridge that connects desktop RuneLite sessions to mobile iOS/iPadOS
#          clients over low-latency event stream sockets.
# ==============================================================================

"""Aegis RuneLite iOS - Headless Streaming Bridge Daemon.

==============================================================================
CIS 156 Educational Architecture Overview:
==============================================================================
In introductory computer science (CIS 156), client-server architecture forms
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
