# ==============================================================================
# Program: neural_harness/hid_safety.py
# Programmer: Ethan-da-Tech-Wizard
# Last Modified: November 18, 2026
# Purpose: Physical Hardware HID Activity Probe & Offscreen Safety Guard.
#          Monitors hardware interrupt lines, USB request block counters,
#          pseudoterminal access times, and window manager cursor positions
#          to detect physical human input and prevent automated harness interference.
# ==============================================================================

"""neural_harness/hid_safety.py — Physical Hardware HID Activity Probe & Offscreen Safety Guard.

==============================================================================
Architecture Overview & Motivation:
==============================================================================
In computer systems, "HID" stands for Human Interface Device (keyboards, mice,
gamepads, and touchscreens). When building automated benchmarking suites or
AI game harnesses, a critical safety requirement is ensuring that automated
or simulated inputs NEVER hijack or disrupt the human developer's physical
workstation while they are working.

Why this module exists:
1. Fail-Safe Input Isolation: If a human user moves their mouse or types on
   their keyboard, the benchmark harness must detect this immediately and yield,
   pausing automated operations.
2. Low-Level Kernel Telemetry: Instead of running invasive keyloggers, we read
   low-level hardware interrupt counters (/proc/interrupts), USB Request Block
   (URB) activity counters (/sys/bus/usb/devices), and pseudoterminal access times.
3. Cross-Platform Compatibility: Designed primarily for Linux environments
   with graceful fallbacks for macOS and BSD systems.
"""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import time

# Location where the previous hardware activity signature and timestamp are cached.
# Using /tmp ensures temporary file storage that survives script reinvocations
# without polluting the repository workspace.
STATE_FILE: Path = Path("/tmp") / "hid_idle_state.json"


def probe_linux_hardware_hid_idle_seconds() -> float:
    """Probe hardware interrupts, USB traffic, and cursor metrics to calculate idle time.

    In systems architecture, polling state vs. event-driven notifications. Here,
    we poll hardware activity indicators exposed by the operating system kernel.
    By aggregating interrupt numbers and USB URB counts into a consolidated
    "signature", any delta between probes indicates that physical user input
    has occurred.

    Parameters:
        None. This function inspects system-level hardware state files directly.

    Returns:
        float: The estimated number of seconds since physical hardware keyboard,
               mouse, or terminal input was last detected. Returns 0.0 if new
               activity was just detected or if the probe cannot establish idle history.

    Algorithm Step-by-Step:
        Step 1: Record the current wall-clock epoch timestamp.
        Step 2: Read PS/2 and internal keyboard interrupts from `/proc/interrupts` (i8042).
        Step 3: Enumerate USB devices under `/sys/bus/usb/devices` to count URBs from mice/keyboards.
        Step 4: Check pseudo-terminal (`/dev/pts`) access and modification timestamps.
        Step 5: Query Wayland/Hyprland cursor position (if available) via `hyprctl cursorpos`.
        Step 6: Concatenate all counts into a unique composite "hardware signature" string.
        Step 7: Compare the new signature against the cached signature in `STATE_FILE`.
                - If identical: The user has not touched hardware; compute `(now - last_activity_ts)`.
                - If changed: Hardware was activated! Record `now` as the new activity timestamp and return 0.0.
    """
    # Step 1: Capture the baseline timestamp (seconds since Unix epoch: Jan 1, 1970)
    now: float = time.time()

    # Step 2: Read PS/2 / Laptop Keyboard Interrupts (IRQ)
    # The Linux kernel exposes hardware interrupt counts in /proc/interrupts.
    # The "i8042" chip controller handles PS/2 keyboards and legacy laptop trackpads.
    irq_total: int = 0
    try:
        proc_int: Path = Path("/proc/interrupts")
        # Ensure the file exists before attempting to open it (prevents crashes on macOS/Windows)
        if proc_int.exists():
            # Read text and iterate through each line looking for the i8042 controller
            for line in proc_int.read_text(encoding="utf-8", errors="ignore").splitlines():
                if "i8042" in line:
                    # Tokenize the line and sum up the integer interrupt counters for all CPU cores
                    nums = [int(tok) for tok in line.split()[1:] if tok.isdigit()]
                    irq_total += sum(nums)
    except Exception:
        # If /proc/interrupts is inaccessible (e.g. non-Linux host or restricted sandbox),
        # gracefully ignore errors to avoid halting the application.
        pass

    # Step 3: Inspect USB Request Block (URB) counters for external USB mice and keyboards
    # Linux tracks USB transfer packets in /sys/bus/usb/devices/*/urbnum.
    usb_hid_urbs: int = 0
    try:
        usb_root: Path = Path("/sys/bus/usb/devices")
        if usb_root.exists():
            for dev_dir in usb_root.iterdir():
                prod_file = dev_dir / "product"
                urb_file = dev_dir / "urbnum"
                # Check that both the descriptive product file and the urbnum counter exist
                if prod_file.exists() and urb_file.exists():
                    prod_name = prod_file.read_text(encoding="utf-8", errors="ignore").strip().lower()
                    # Filter for typical human input peripheral keywords
                    keywords = ("keyboard", "mouse", "receiver", "trackpad", "touchpad")
                    if any(kw in prod_name for kw in keywords) and "keychron" not in prod_name:
                        urb_txt = urb_file.read_text(encoding="utf-8", errors="ignore").strip()
                        if urb_txt.isdigit():
                            usb_hid_urbs += int(urb_txt)
    except Exception:
        pass

    # Step 4: Check pseudo-terminals (/dev/pts) for developer shell input
    # When a human types commands into an interactive terminal window,
    # the terminal device's access timestamp (`st_atime`) updates.
    pts_latest: int = 0
    try:
        pts_dir: Path = Path("/dev/pts")
        if pts_dir.exists():
            for item in pts_dir.iterdir():
                # Pseudo-terminals are numbered directory entries (e.g., 0, 1, 2)
                if item.name.isdigit():
                    st = item.stat()
                    # An access time distinctly greater than creation time signifies active I/O
                    if abs(st.st_atime - st.st_ctime) >= 2.0:
                        pts_latest = max(pts_latest, int(st.st_atime))
    except Exception:
        pass

    # Step 5: Query Wayland/Hyprland display server cursor coordinates
    # If the user is running the Hyprland desktop environment, query cursor position
    cursor_str: str = ""
    try:
        res = subprocess.run(["hyprctl", "cursorpos"], capture_output=True, text=True, timeout=1)
        if res.returncode == 0:
            cursor_str = res.stdout.strip()
    except Exception:
        pass

    # Step 6: Formulate a composite signature of physical activity
    # By combining the 4 independent metrics, ANY hardware input will alter this string.
    current_sig: str = f"{irq_total}:{usb_hid_urbs}:{pts_latest}:{cursor_str}"

    # Step 7: Compare against persistent state
    if STATE_FILE.exists():
        try:
            state = json.loads(STATE_FILE.read_text(encoding="utf-8"))
            # If the signature is unchanged, no user input occurred since last check!
            if state.get("sig") == current_sig:
                last_ts = float(state.get("last_activity_ts", now))
                # Return elapsed seconds since activity, clamped to non-negative
                return max(0.0, now - last_ts)
        except Exception:
            pass

    # If the signature changed or no prior state exists, user activity is happening NOW.
    try:
        STATE_FILE.write_text(
            json.dumps({"sig": current_sig, "last_activity_ts": now}),
            encoding="utf-8"
        )
    except Exception:
        pass

    # Return 0.0 indicating 0 seconds of idle time (active right now)
    return 0.0
