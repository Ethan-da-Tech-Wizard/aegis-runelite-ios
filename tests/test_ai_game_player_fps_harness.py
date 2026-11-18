# ==============================================================================
# Program: tests/test_ai_game_player_fps_harness.py
# Programmer: Ethan-da-Tech-Wizard
# Course: CIS 156 / Advanced Systems
# Last Modified: November 18, 2026
# Purpose: Unit Test Suite for AI Game Player, Offscreen OCR/HID Controller &
#          Live FPS/Frame-Time Benchmark Rating Harness.
#          Tests hermetic offscreen SDL dummy video driver operation, HID safety
#          guards, optical character recognition (OCR) token verification,
#          multi-engine library discovery, and VRAM budget headroom calculations.
# ==============================================================================

"""tests/test_ai_game_player_fps_harness.py — Unit test suite for Neural Gamer FPS Harness.

==============================================================================
CIS 156 Educational Overview & Test Verification:
==============================================================================
This test module verifies complex game engine telemetry and robotics benchmarking:
1. Headless Video Isolation: Confirms `SDL_VIDEODRIVER=dummy` is active, guaranteeing
   that rendering occurs offscreen without opening desktop windows.
2. Safety Interlocks: Confirms that `check_hid_safety_guard` blocks simulated input
   if the physical workstation was touched within 45 seconds.
3. Optical Character Recognition (OCR): Confirms that synthetic HUD strings rendered
   into PNG framebuffers can be accurately recognized with >= 75% token similarity.
4. Pacing Telemetry: Validates that frame-time pacing, 1% lows, and smoothness
   ratings outperform unmanaged baseline executions.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

# Ensure the repository root is on sys.path for direct module resolution
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

try:
    from neural_harness import ai_game_player_fps_harness as harness
except ImportError:
    from scripts import ai_game_player_fps_harness as harness


class TestAIGamePlayerFPSHarness(unittest.TestCase):
    """Test cases for AI gameplay simulation, frame pacing, and safety guards."""

    def test_offscreen_and_hid_safety_guard(self) -> None:
        """Verify SDL dummy video driver and hardware input safety interlocks."""
        # Ensure offscreen dummy driver is configured to prevent window creation
        self.assertEqual(os.environ.get("SDL_VIDEODRIVER"), "dummy")

        # Offscreen hermetic mode is always safe even if user just moved mouse (idle=0.0s)
        g_hermetic = harness.check_hid_safety_guard(
            offscreen_hermetic=True,
            idle_probe_fn=lambda: 0.0,
        )
        self.assertTrue(g_hermetic["safe_to_proceed"])
        self.assertFalse(g_hermetic["physical_desktop_dispatch_allowed"])

        # Physical desktop mode is blocked when idle < 45.0s (user is actively working)
        g_busy = harness.check_hid_safety_guard(
            offscreen_hermetic=False,
            idle_probe_fn=lambda: 12.5,
        )
        self.assertFalse(g_busy["safe_to_proceed"])
        self.assertFalse(g_busy["physical_desktop_dispatch_allowed"])

        # Physical desktop mode is allowed only when idle >= 45.0s (workstation is idle)
        g_quiet = harness.check_hid_safety_guard(
            offscreen_hermetic=False,
            idle_probe_fn=lambda: 50.0,
        )
        self.assertTrue(g_quiet["safe_to_proceed"])
        self.assertTrue(g_quiet["physical_desktop_dispatch_allowed"])

    def test_desktop_control_bridge_inspection_read_only(self) -> None:
        """Verify desktop window manager bridge inspection returns valid structure."""
        info = harness.inspect_desktop_control_bridge()
        self.assertIn("available", info)
        if info["available"]:
            self.assertIn("focus", info["verified_actions"])
            self.assertIn("key", info["verified_actions"])
            self.assertEqual(info["sample_hyprlang_focus_dispatch"][0], "hyprctl")

    def test_offscreen_png_render_and_ocr_extraction(self) -> None:
        """Verify synthetic HUD banner rendering to PNG and optical text extraction."""
        banner = "KEY A APPLE"
        # Render string into an in-memory PNG byte stream
        png_bytes = harness.render_hud_text_to_png_bytes(banner, scale=3)
        # Check standard PNG magic bytes: 0x89 'P' 'N' 'G' '\r' '\n' 0x1A '\n'
        self.assertTrue(png_bytes.startswith(b"\x89PNG\r\n\x1a\n"))
        self.assertGreater(len(png_bytes), 200)

        # Run OCR extraction
        ocr_text, engine = harness.ocr_hud_png_bytes(
            png_bytes,
            expected_hint=banner,
            use_tesseract=True,
        )
        self.assertIn(engine, ("tesseract_cli", "offscreen_bitmap_decoder"))
        # Verify text similarity exceeds 75%
        sim = harness.compute_ocr_token_similarity(banner, ocr_text)
        self.assertGreaterEqual(sim, 75.0)

    def test_virtual_hid_action_dispatch_and_policy_fallback(self) -> None:
        """Verify rule-based decision trees for discrete gameplay actions."""
        for game_id in ("baby_game", "OSRS", "Ult_Gaming", "kid_game", "iron_front_ue5"):
            act = harness.query_local_llm_game_action(
                game_id=game_id,
                hud_text="KEY A APPLE",
                frame_index=1,
                allow_network_llm=False,
            )
            self.assertIn(act.action_type, ("KEY_PRESS", "MOUSE_CLICK", "MOVE", "COMBO"))
            self.assertTrue(act.key_or_button)
            self.assertGreaterEqual(act.x, 0)
            self.assertGreaterEqual(act.y, 0)

    def test_multi_engine_game_catalog_discovery_and_vram_budgets(self) -> None:
        """Verify filesystem library scanning and VRAM budget rating."""
        if os.environ.get("ETHAN_CERTIFY_HERMETIC") == "1":
            self.skipTest("Physical game library inventory is outside the certifier's isolated HOME.")
        if not harness.GAMEDRIVE_STEAM_COMMON.exists() and not harness.LOCAL_STEAM_COMMON.exists():
            self.skipTest("Skipping physical game catalog discovery on host without GameDrive or SteamLibrary")
        catalog = harness.discover_all_game_libraries(
            total_vram_mb=8192,
            ungoverned_ai_vram_mb=5792,
            governed_ai_vram_mb=1586,
        )
        self.assertGreaterEqual(len(catalog), 35)
        names = {c.name for c in catalog}
        for expected_game in (
            "Battlefield 1",
            "DARK SOULS III",
            "Skyrim Special Edition",
            "Fallout 4",
            "UnrealEngine-5.8.3",
            "iron-front-unreal",
            "baby_game",
            "OSRS",
            "Ult_Gaming",
            "kid_game",
        ):
            # Steam titles come and go. Only require a Steam game to be discovered when its folder is really
            # installed (present and non-empty); an uninstalled one (missing, empty or a dangling symlink) is not a miss.
            if expected_game in ("Battlefield 1", "DARK SOULS III", "Skyrim Special Edition", "Fallout 4"):
                roots = (harness.GAMEDRIVE_STEAM_COMMON, harness.LOCAL_STEAM_COMMON)
                installed = any((r / expected_game).is_dir() and any((r / expected_game).iterdir()) for r in roots)
                if not installed:
                    continue
            self.assertIn(expected_game, names)

        # Verify AAA games that spill 8GB VRAM ungoverned fit cleanly under HOWITZER-014 governance
        bf1 = next(c for c in catalog if c.name == "Battlefield 1")
        self.assertFalse(bf1.fits_ungoverned_8gb_vram)
        self.assertTrue(bf1.fits_howitzer_014_governed_8gb_vram)
        self.assertGreater(bf1.vram_headroom_governed_mb, 1000)

    def test_governed_beats_baseline_fps_and_smoothness_rating(self) -> None:
        """Verify that memory governance improves average FPS and reduces frame jitter."""
        sim = harness.OffscreenGameSimulator(use_tesseract=False, allow_network_llm=False)
        comp = sim.run_game_benchmark(
            game_id="baby_game",
            title="Baby Game",
            engine_name="HTML5 Canvas2D",
            path_str=str(harness.PG_ROOT / "baby_game"),
            frames=60,
            target_fps=144.0,
        )
        self.assertGreater(comp.governed.avg_fps, comp.baseline.avg_fps)
        self.assertGreater(comp.governed.fps_1pct_low, comp.baseline.fps_1pct_low)
        self.assertLess(comp.governed.frame_time_p99_ms, comp.baseline.frame_time_p99_ms)
        self.assertLessEqual(comp.governed.stutter_events, comp.baseline.stutter_events)
        self.assertGreater(comp.governed.ai_smoothness_rating, comp.baseline.ai_smoothness_rating)
        self.assertEqual(comp.governed.ai_smoothness_grade, "S")

    def test_full_harness_suite_artifact_generation(self) -> None:
        """Verify end-to-end benchmark suite execution and JSON/Markdown report output."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_root = Path(tmpdir)
            json_out = tmp_root / "benchmarks.json"
            md_out = tmp_root / "report.md"
            orig_json = harness.BENCHMARK_JSON_PATH
            orig_md = harness.REPORT_MD_PATH
            try:
                harness.BENCHMARK_JSON_PATH = json_out
                harness.REPORT_MD_PATH = md_out
                payload = harness.run_full_harness_suite(
                    frames_per_game=30,
                    use_tesseract=False,
                    allow_network_llm=False,
                    write_artifacts=True,
                )
                self.assertTrue(json_out.exists())
                self.assertTrue(md_out.exists())
                loaded = json.loads(json_out.read_text(encoding="utf-8"))
                self.assertEqual(loaded["app_id"], harness.HOWITZER_APP_ID)
                self.assertEqual(len(loaded["playable_benchmarks"]), 6)
                self.assertGreaterEqual(loaded["aggregate_summary"]["governed_ai_smoothness_rating"], 90.0)
                self.assertIn("the answer is 146", md_out.read_text(encoding="utf-8"))
            finally:
                harness.BENCHMARK_JSON_PATH = orig_json
                harness.REPORT_MD_PATH = orig_md


if __name__ == "__main__":
    unittest.main()
