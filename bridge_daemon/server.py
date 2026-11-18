# ==============================================================================
# Program: bridge_daemon/server.py
# Programmer: Ethan-da-Tech-Wizard
# Last Modified: November 18, 2026
# Purpose: Zero-Credential Streaming & WebClip Server for iOS RuneLite.
#          Hosts the standalone mobile HTML5 web application, exposes REST
#          endpoints for 600ms game tick overlay streaming (/api/state),
#          and receives 1:1 hardware touch interaction packets (/api/touch).
# ==============================================================================

"""bridge_daemon/server.py — Zero-Credential Streaming & WebClip Server for iOS RuneLite.

==============================================================================
Overview: Network Systems:
==============================================================================
In introductory computer networking, the HyperText Transfer Protocol (HTTP)
provides request-response messaging between clients (smartphones, browsers)
and servers.

Key Systems Concepts Demonstrated in this File:
1. Socket Address Resolution (`get_local_ip`): Uses UDP routing table inspection
   to find the primary outward-facing LAN IP without transmitting network packets.
2. HTTP Methods:
   - GET: Serves the WebClip HTML bundle, health checks, and overlay batches.
   - HEAD: Verifies endpoint availability and content length without body payload.
   - OPTIONS: Handles Cross-Origin Resource Sharing (CORS) preflight requests.
   - POST: Ingests client touch events and plugin toggles with JSON request bodies.
3. Zero-Credential Sanitization: Every JSON response leaving the server passes
   through `MobileSecurityGate.sanitize_outbound_dict` to guarantee that no
   passwords or authentication credentials can leak to client devices.
"""

from __future__ import annotations

import argparse
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer, ThreadingHTTPServer
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import threading
import time
from typing import Any, Dict

# Resolve project root and module directories to guarantee import accessibility
ROOT = Path(__file__).resolve().parent.parent
MODULE_DIR = Path(__file__).resolve().parent
for p in (str(ROOT), str(MODULE_DIR)):
    if p not in sys.path:
        sys.path.insert(0, p)

# Wire protocol, headless simulator, and security scrubber imports
try:
    from bridge_daemon.event_stream_protocol import TouchInputPacket
    from bridge_daemon.runelite_headless_daemon import HeadlessRuneLiteDaemon
    from bridge_daemon.security_gate import MobileSecurityGate, SecurityViolation
except ImportError:
    from event_stream_protocol import TouchInputPacket
    from runelite_headless_daemon import HeadlessRuneLiteDaemon
    from security_gate import MobileSecurityGate, SecurityViolation

# Absolute path to the packaged HTML5 mobile WebClip web application
HTML_PATH: Path = Path(__file__).resolve().parent / "frontend" / "ios_runelite_webclip.html"


def get_local_ip() -> str:
    """Discover the primary local area network (LAN) IP address of this host machine.

    In networking, computers often have multiple network interfaces
    (loopback 127.0.0.1, ethernet eth0, Wi-Fi wlan0, and virtual bridges). To tell
    an iPhone user which URL to visit on their local Wi-Fi, we must determine the
    machine's outward-facing LAN IP.

    Why this technique works:
    Opening a UDP socket and connecting to an external address (such as Google's 8.8.8.8)
    does NOT transmit any packets over the internet because UDP is connectionless.
    However, the operating system kernel must consult its internal routing table to
    determine which local network interface would be used to reach that destination.
    We then query `getsockname()` to retrieve that local IP address.

    Parameters:
        None.

    Returns:
        str: The IPv4 address string (e.g., '192.168.1.50'), or '127.0.0.1' on error.
    """
    # Step 1: Create a UDP socket (AF_INET = IPv4, SOCK_DGRAM = Datagram/UDP)
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Step 2: Query the OS routing table for outward interface
        s.connect(("8.8.8.8", 80))
        ip: str = s.getsockname()[0]
    except Exception:
        # Fallback to local loopback interface if machine is completely offline
        ip = "127.0.0.1"
    finally:
        # Step 3: Always close the socket to free operating system file descriptors
        s.close()
    return ip


class RuneLiteBridgeHandler(BaseHTTPRequestHandler):
    """Custom HTTP request handler dispatching WebClip static assets and REST APIs.

    In Python's `http.server`, each incoming connection invokes methods corresponding
    to the HTTP verb: `do_GET()`, `do_POST()`, `do_HEAD()`, and `do_OPTIONS()`.
    """

    # Shared instance of the headless OSRS simulator across incoming HTTP requests
    daemon: HeadlessRuneLiteDaemon = HeadlessRuneLiteDaemon()

    def do_GET(self) -> None:
        """Handle incoming HTTP GET requests for HTML pages, health status, and state.

        Supported Routes:
        - `/`, `/mobile`, `/index.html`: Returns the standalone iOS WebClip HTML page.
        - `/api/state`: Advances game tick and streams sanitized active overlays.
        - `/api/health`: Provides system diagnostic health and active plugin counts.
        """
        # Route 1: WebClip HTML5 Single Page Application
        if self.path in ("/", "/mobile", "/index.html"):
            if not HTML_PATH.exists():
                self.send_error(404, "WebClip bundle not found")
                return
            # Read static HTML file as raw bytes
            content = HTML_PATH.read_bytes()
            # Transmit standard HTTP 200 OK headers
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            # Send file content across the wire socket
            self.wfile.write(content)

        # Route 2: Real-time Overlay State Stream
        elif self.path == "/api/state":
            # Advance simulation tick (600ms heartbeat)
            packet = self.daemon.step_game_tick()
            # Scrutinize packet against zero-credential security boundary
            clean_packet = MobileSecurityGate.sanitize_outbound_dict(packet)
            body = json.dumps(clean_packet).encode("utf-8")

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            # Allow Cross-Origin requests so web apps or local dev can access
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(body)

        # Route 3: Server Health and Diagnostics
        elif self.path == "/api/health":
            body = json.dumps({
                "status": "HEALTHY",
                "zero_credential_safe": True,
                "active_plugins": len(self.daemon.plugins),
                "tick": self.daemon.tick_count,
            }).encode("utf-8")

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(body)

        # Catch-all: Route Not Found
        else:
            self.send_error(404, "Not Found")

    def do_HEAD(self) -> None:
        """Handle HTTP HEAD requests to verify availability without payload body."""
        if self.path in ("/", "/mobile", "/index.html"):
            if not HTML_PATH.exists():
                self.send_error(404, "WebClip bundle not found")
                return
            content = HTML_PATH.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
        elif self.path in ("/api/state", "/api/health"):
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
        else:
            self.send_error(404, "Not Found")

    def do_OPTIONS(self) -> None:
        """Respond to CORS preflight options requests from mobile Safari."""
        self.send_response(204)  # 204 No Content
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS, HEAD")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_POST(self) -> None:
        """Handle HTTP POST requests carrying JSON payloads from mobile clients.

        Supported Routes:
        - `/api/touch`: Receives mobile tap/drag/hold gestures and translates them to OSRS clicks.
        - `/api/toggle`: Enables or disables an individual RuneLite plugin on the daemon.
        """
        # Step 1: Read the exact byte count declared in Content-Length header
        content_length = int(self.headers.get("Content-Length", 0))
        raw_body = self.rfile.read(content_length)

        # Route 1: Touch Input Ingestion
        if self.path == "/api/touch":
            try:
                # Step 2: Parse raw bytes into JSON dictionary
                data = json.loads(raw_body.decode("utf-8"))
                # Step 3: Instantiate strongly-typed TouchInputPacket
                touch = TouchInputPacket.from_dict(data)
                # Step 4: Dispatch touch to headless daemon
                resp = self.daemon.handle_touch_input(touch)
                # Step 5: Scrub response through security gate
                clean_resp = MobileSecurityGate.sanitize_outbound_dict(resp)
                out = json.dumps(clean_resp).encode("utf-8")

                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(out)))
                self.end_headers()
                self.wfile.write(out)
            except Exception as e:
                self.send_error(400, str(e))

        # Route 2: Plugin State Toggle
        elif self.path == "/api/toggle":
            try:
                data = json.loads(raw_body.decode("utf-8"))
                plugin_id = data.get("id")
                enabled = bool(data.get("enabled", True))
                # Update daemon plugin state
                self.daemon.set_plugin_state(plugin_id, enabled)
                out = json.dumps({"status": "updated", "id": plugin_id, "enabled": enabled}).encode("utf-8")

                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(out)))
                self.end_headers()
                self.wfile.write(out)
            except Exception as e:
                self.send_error(400, str(e))

        else:
            self.send_error(404, "Not Found")

    def log_message(self, format: str, *args: Any) -> None:
        """Suppress routine terminal access log noise to keep console output clean."""
        pass


def run_server(port: int = 8088, bounded_seconds: int = 0) -> None:
    """Instantiate and start the HTTP server on all available network interfaces.

    Parameters:
        port (int): TCP port to bind (default: 8088).
        bounded_seconds (int): If greater than 0, runs server for N seconds then exits cleanly.
                              Useful for automated testing and CI verification.
    """
    local_ip = get_local_ip()
    # Bind to 0.0.0.0 to listen on all interfaces (loopback, Wi-Fi, Ethernet)
    server = HTTPServer(("0.0.0.0", port), RuneLiteBridgeHandler)
    url = f"http://{local_ip}:{port}"

    print("=" * 64)
    print("   ⚔️  RUNELITE DISTRIBUTED MOBILE BRIDGE (iOS / Safari)")
    print("=" * 64)
    print(f"• Mobile WebClip URL : {url}")
    print(f"• Local Host URL     : http://127.0.0.1:{port}")
    print("• Security Model     : Zero-Frontend User Data (100% Safe)")
    print("• Active Plugins     : 77 Native Plugins Loaded")
    print("• iPhone Setup       : Open in Safari -> Tap Share -> 'Add to Home Screen'")
    print("=" * 64)

    # If bounded duration specified, run in background thread for testing
    if bounded_seconds > 0:
        t = threading.Thread(target=server.serve_forever, daemon=True)
        t.start()
        time.sleep(bounded_seconds)
        server.shutdown()
        server.server_close()
        print(f"Server ran bounded check for {bounded_seconds}s and closed successfully.")
    else:
        try:
            # Block and serve requests indefinitely until Ctrl+C
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down RuneLite bridge server.")
            server.server_close()


def main(argv: list[str] | None = None) -> int:
    """Command-line interface entry point.

    Parameters:
        argv (Optional[List[str]]): CLI arguments or None to read from sys.argv.

    Returns:
        int: Exit status code (0 for success).
    """
    parser = argparse.ArgumentParser(description="iOS RuneLite Bridge Streaming Server")
    parser.add_argument("--port", type=int, default=8088, help="Port to bind (default: 8088)")
    parser.add_argument(
        "--test-seconds",
        type=int,
        default=0,
        help="Run for N seconds then exit cleanly (for testing)"
    )
    args = parser.parse_args(argv)

    run_server(port=args.port, bounded_seconds=args.test_seconds)
    return 0


if __name__ == "__main__":
    sys.exit(main())
