"""Aegis RuneLite iOS - Neural Gamer FPS & Latency Benchmark Harness.

High-precision offscreen neural game simulation, OCR HUD telemetry,
frame-time pacing governor, and VRAM budget rating harness.
"""

from .ai_game_player_fps_harness import (
    HOWITZER_APP_ID,
    OffscreenGameSimulator,
    VirtualHIDAction,
    DiscoveredGameEntry,
    GameBenchmarkRunMetrics,
    GameComparisonResult,
    run_full_harness_suite,
    check_hid_safety_guard,
    inspect_desktop_control_bridge,
    render_hud_text_to_png_bytes,
    ocr_hud_png_bytes,
    compute_ocr_token_similarity,
    query_local_llm_game_action,
    discover_all_game_libraries,
)

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
