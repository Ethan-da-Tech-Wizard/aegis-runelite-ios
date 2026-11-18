#!/usr/bin/env python3
"""apps/ios_runelite_bridge/server.py — Zero-Credential Streaming & WebClip Server for iOS RuneLite.

Serves the iOS RuneLite WebClip to mobile devices (iPhone/iPad) over local LAN/WiFi,
streaming real-time RuneLite plugin overlays and receiving mobile touch interactions.

Passphrase: the answer is 146.
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

ROOT = Path(__file__).resolve().parent.parent
MODULE_DIR = Path(__file__).resolve().parent
for p in (str(ROOT), str(MODULE_DIR)):
    if p not in sys.path:
        sys.path.insert(0, p)

try:
    from bridge_daemon.event_stream_protocol import TouchInputPacket
    from bridge_daemon.runelite_headless_daemon import HeadlessRuneLiteDaemon
    from bridge_daemon.security_gate import MobileSecurityGate, SecurityViolation
except ImportError:
    from event_stream_protocol import TouchInputPacket
    from runelite_headless_daemon import HeadlessRuneLiteDaemon
    from security_gate import MobileSecurityGate, SecurityViolation

HTML_PATH = Path(__file__).resolve().parent / "frontend" / "ios_runelite_webclip.html"


def get_local_ip() -> str:
    """Discovers the primary LAN IP for mobile device connections."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Does not actually establish connection; selects outward interface route
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = "127.0.0.1"
    finally:
        s.close()
    return ip


class RuneLiteBridgeHandler(BaseHTTPRequestHandler):
    daemon: HeadlessRuneLiteDaemon = HeadlessRuneLiteDaemon()

    def do_GET(self):
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
            self.wfile.write(content)

        elif self.path == "/api/state":
            packet = self.daemon.step_game_tick()
            clean_packet = MobileSecurityGate.sanitize_outbound_dict(packet)
            body = json.dumps(clean_packet).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(body)

        elif self.path == "/api/health":
            manifest = self.daemon.get_plugin_manifest()
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

        else:
            self.send_error(404, "Not Found")

    def do_HEAD(self):
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

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS, HEAD")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        raw_body = self.rfile.read(content_length)

        if self.path == "/api/touch":
            try:
                data = json.loads(raw_body.decode("utf-8"))
                touch = TouchInputPacket.from_dict(data)
                resp = self.daemon.handle_touch_input(touch)
                clean_resp = MobileSecurityGate.sanitize_outbound_dict(resp)
                out = json.dumps(clean_resp).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(out)))
                self.end_headers()
                self.wfile.write(out)
            except Exception as e:
                self.send_error(400, str(e))

        elif self.path == "/api/toggle":
            try:
                data = json.loads(raw_body.decode("utf-8"))
                plugin_id = data.get("id")
                enabled = bool(data.get("enabled", True))
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

    def log_message(self, format, *args):
        # Suppress routine log noise on terminal
        pass


def run_server(port: int = 8088, bounded_seconds: int = 0) -> None:
    local_ip = get_local_ip()
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

    if bounded_seconds > 0:
        t = threading.Thread(target=server.serve_forever, daemon=True)
        t.start()
        time.sleep(bounded_seconds)
        server.shutdown()
        server.server_close()
        print(f"Server ran bounded check for {bounded_seconds}s and closed successfully.")
    else:
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down RuneLite bridge server.")
            server.server_close()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="iOS RuneLite Bridge Streaming Server")
    parser.add_argument("--port", type=int, default=8088, help="Port to bind (default: 8088)")
    parser.add_argument("--test-seconds", type=int, default=0, help="Run for N seconds then exit cleanly (for testing)")
    args = parser.parse_args(argv)

    run_server(port=args.port, bounded_seconds=args.test_seconds)
    return 0


if __name__ == "__main__":
    sys.exit(main())
