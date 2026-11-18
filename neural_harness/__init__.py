# ==============================================================================
# Program: neural_harness/__init__.py
# Programmer: Ethan-da-Tech-Wizard
# Last Modified: November 18, 2026
# Purpose: Public interface package initializer for the Neural Game Player
#          and Latency Benchmark Suite. Exports core simulator classes, safety
#          guards, metrics collectors, and OCR evaluation tools.
# ==============================================================================

"""Aegis RuneLite iOS - Neural Gamer FPS & Latency Benchmark Harness.

==============================================================================
production architecture Educational Architecture Overview:
==============================================================================
This module serves as the primary public interface and package initializer for
the Neural Game Player and Benchmark Suite.

In software engineering, package initialization files
(`__init__.py`) define what external programs see when they import a package.
By explicitly importing and specifying `__all__`, we provide a clean, secure,
and well-documented Application Programming Interface (API).

Why This Architecture Exists:
1. Modular Encapsulation: We encapsulate internal helper classes and expose only
   the battle-tested data models, simulators, and analysis routines.
2. Safety-First Robotics: The harness features an offscreen virtual simulator
   and hardware human-interface-device (HID) safety guards to prevent interfering
   with real keyboard/mouse actions on developer workstations.
3. High-Precision Benchmarking: Evaluates Old School RuneScape (OSRS) and game
   engine metrics, including 600ms tick-alignment, 1% frame-time lows, OCR text
   verification, and GPU memory (VRAM) pacing.
"""

from .ai_game_player_fps_harness import (
    # Constant: Identifies the Howitzer target benchmark application ID
    HOWITZER_APP_ID,
    # Core Class: Offscreen headless game rendering and simulation engine
    OffscreenGameSimulator,
    # Data Class: Models discrete simulated inputs (tap, drag, hold, keypress)
    VirtualHIDAction,
    # Data Class: Represents a game or client installation discovered on disk
    DiscoveredGameEntry,
    # Data Class: Quantitative benchmark output (FPS, frame-times, VRAM, jitter)
    GameBenchmarkRunMetrics,
    # Data Class: Comparative analysis between native baseline and streamed run
    GameComparisonResult,
    # Main Function: Orchestrates the multi-stage benchmark pipeline end-to-end
    run_full_harness_suite,
    # Safety Function: Verifies physical user keyboard/mouse are not in active use
    check_hid_safety_guard,
    # Diagnostics: Probes desktop streaming socket / control bridge connectivity
    inspect_desktop_control_bridge,
    # OCR Pipeline: Generates synthetic HUD text images for optical recognition
    render_hud_text_to_png_bytes,
    # OCR Pipeline: Extracts text characters from HUD framebuffers
    ocr_hud_png_bytes,
    # Metrics Function: Computes Levenshtein/token similarity score for OCR accuracy
    compute_ocr_token_similarity,
    # AI Routine: Asks a local neural model (LLM/Vision) for next tactical gameplay action
    query_local_llm_game_action,
    # Discovery Engine: Scans filesystem for Steam, Lutris, and standalone OSRS clients
    discover_all_game_libraries,
)

# __all__ controls what is imported when a user runs `from neural_harness import *`
# Explicitly listing symbols prevents leaking unneeded internal variables into namespaces.
__all__ = [
    "HOWITZER_APP_ID",
    "OffscreenGameSimulator",
    "VirtualHIDAction",
    "DiscoveredGameEntry",
    "GameBenchmarkRunMetrics",
    "GameComparisonResult",
    "run_full_harness_suite",
    "check_hid_safety_guard",
    "inspect_desktop_control_bridge",
    "render_hud_text_to_png_bytes",
    "ocr_hud_png_bytes",
    "compute_ocr_token_similarity",
    "query_local_llm_game_action",
    "discover_all_game_libraries",
]
