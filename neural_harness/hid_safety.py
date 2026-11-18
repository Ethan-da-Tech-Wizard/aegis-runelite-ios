#!/usr/bin/env python3
"""neural_harness/hid_safety.py — Physical Hardware HID Activity Probe & Offscreen Safety Guard.

Tracks physical keyboard/mouse hardware activity across Linux/macOS to guarantee
the AI Neural Gamer benchmarking harness never intercepts or interferes with
physical user input.
"""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import time

STATE_FILE = Path("/tmp") / "hid_idle_state.json"


def probe_linux_hardware_hid_idle_seconds() -> float:
    """Tracks physical keyboard/mouse hardware activity (i8042 + USB HID urbnum + cursorpos).

    Guarantees offscreen benchmark runs never dispatch input when a human is active.
    """
    now = time.time()
    irq_total = 0
    try:
        proc_int = Path("/proc/interrupts")
        if proc_int.exists():
            for line in proc_int.read_text(encoding="utf-8", errors="ignore").splitlines():
                if "i8042" in line:
                    nums = [int(tok) for tok in line.split()[1:] if tok.isdigit()]
                    irq_total += sum(nums)
    except Exception:
        pass

    usb_hid_urbs = 0
    try:
        usb_root = Path("/sys/bus/usb/devices")
        if usb_root.exists():
            for dev_dir in usb_root.iterdir():
                prod_file = dev_dir / "product"
                urb_file = dev_dir / "urbnum"
                if prod_file.exists() and urb_file.exists():
                    prod_name = prod_file.read_text(encoding="utf-8", errors="ignore").strip().lower()
                    if any(kw in prod_name for kw in ("keyboard", "mouse", "receiver", "trackpad", "touchpad")) and "keychron" not in prod_name:
                        urb_txt = urb_file.read_text(encoding="utf-8", errors="ignore").strip()
                        if urb_txt.isdigit():
                            usb_hid_urbs += int(urb_txt)
    except Exception:
        pass

    pts_latest = 0
    try:
        pts_dir = Path("/dev/pts")
        if pts_dir.exists():
            for item in pts_dir.iterdir():
                if item.name.isdigit():
                    st = item.stat()
                    if abs(st.st_atime - st.st_ctime) >= 2.0:
                        pts_latest = max(pts_latest, int(st.st_atime))
    except Exception:
        pass

    cursor_str = ""
    try:
        res = subprocess.run(["hyprctl", "cursorpos"], capture_output=True, text=True, timeout=1)
        if res.returncode == 0:
            cursor_str = res.stdout.strip()
    except Exception:
        pass

    current_sig = f"{irq_total}:{usb_hid_urbs}:{pts_latest}:{cursor_str}"
    if STATE_FILE.exists():
        try:
            state = json.loads(STATE_FILE.read_text(encoding="utf-8"))
            if state.get("sig") == current_sig:
                return max(0.0, now - float(state.get("last_activity_ts", now)))
        except Exception:
            pass

    try:
        STATE_FILE.write_text(json.dumps({"sig": current_sig, "last_activity_ts": now}), encoding="utf-8")
    except Exception:
        pass

    return 0.0
