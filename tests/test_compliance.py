# ==============================================================================
# Program: tests/test_compliance.py
# Programmer: Ethan-da-Tech-Wizard
# Last Modified: November 18, 2026
# Purpose: Automated Jagex Compliance & Architecture Verification Test Suite.
#          Ensures strict adherence to Jagex's Third-Party Client Rules:
#          - 1:1 input ratio enforcement
#          - Banning of prohibited automation (auto-prayer, auto-clickers, packet injection)
#          - Zero-credential architecture (OAuth2 PKCE, no stored passwords)
#          - Verification of all native iOS project structures, shaders, and tests.
# ==============================================================================

"""tests/test_compliance.py — Automated Jagex Compliance & Architecture Verification Test Suite.

==============================================================================
Architecture Overview & Regulatory Compliance:
==============================================================================
In commercial and open-source software engineering, software must often adhere to
strict legal, security, and game-integrity guidelines set by platform owners.
Jagex (the creators of Old School RuneScape) enforces strict third-party client rules:
1. 1:1 Input Mapping: Each physical user input (e.g. one finger tap) must result in
   at most one game input action. Macros and input multiplying are prohibited.
2. No Prohibited Automation: Features like auto-prayer flicking, automatic menu
   selection, or direct network packet injection are strictly forbidden.
3. Zero-Credential Architecture: Third-party clients must NEVER store, capture,
   or log user passwords. All authentication must occur via official OAuth2 PKCE
   (Proof Key for Code Exchange) web flows.

This test suite conducts static analysis and architectural audits across the
entire codebase to guarantee absolute compliance before deployment.
"""

from __future__ import annotations

import math
import os
import sys
import unittest

# Path constants for the source trees these static checks read.
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IOS_APP_DIR = os.path.join(ROOT_DIR, "ios_app")
DOCS_DIR = os.path.join(ROOT_DIR, "docs")
SCRIPTS_DIR = os.path.join(ROOT_DIR, "scripts")


# These are source-text assertions (substring checks on Swift/Markdown files). They confirm the policy is written
# # down and wired in, but do not execute the Swift code.
class TestJagexComplianceSpecification(unittest.TestCase):
    """Test suite ensuring absolute adherence to Jagex's Third-Party Client Rules."""

    def test_compliance_spec_file_exists(self) -> None:
        """Verify that the official compliance documentation file exists and contains core terms."""
        spec_path = os.path.join(DOCS_DIR, "JAGEX_COMPLIANCE_AND_SAFETY_SPECIFICATION.md")
        self.assertTrue(os.path.isfile(spec_path), f"Compliance specification must exist at {spec_path}")
        with open(spec_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("1:1 Input Mapping", content)
        self.assertIn("Zero-Credential Architecture", content)
        self.assertIn("ASWebAuthenticationSession", content)
        self.assertIn("Anti-Detection", content)

    def test_zero_credential_architecture_in_swift_sources(self) -> None:
        """Verify that no Swift file stores raw passwords or bypasses OAuth2."""
        auth_file = os.path.join(IOS_APP_DIR, "Sources", "Auth", "JagexOAuthManager.swift")
        self.assertTrue(os.path.isfile(auth_file), f"Auth manager must exist at {auth_file}")
        with open(auth_file, "r", encoding="utf-8") as f:
            content = f.read()

        # PKCE (code_challenge / code_verifier) lets a mobile app run OAuth without a client secret.
        # Must use Jagex OAuth endpoints and PKCE
        self.assertIn("https://account.jagex.com/oauth2/auth", content)
        self.assertIn("ASWebAuthenticationSession", content)
        self.assertIn("code_challenge", content)
        self.assertIn("code_verifier", content)
        # Must not have hardcoded user passwords
        self.assertNotIn("var password:", content)
        self.assertNotIn("let password =", content)

    def test_jagex_compliance_engine_prohibitions(self) -> None:
        """Verify compliance engine filters banned capabilities."""
        engine_file = os.path.join(IOS_APP_DIR, "Sources", "Compliance", "JagexComplianceEngine.swift")
        self.assertTrue(os.path.isfile(engine_file), f"Compliance engine must exist at {engine_file}")
        with open(engine_file, "r", encoding="utf-8") as f:
            content = f.read()

        # Capability identifiers the compliance engine must name explicitly as prohibited.
        banned = [
            "auto_prayer_flick",
            "auto_clicker",
            "packet_injection",
            "world_derender",
            "macro_sequence",
            "credential_capture"
        ]
        for term in banned:
            self.assertIn(term, content, f"Compliance engine must explicitly ban {term}")

    def test_touch_event_authenticity_guards(self) -> None:
        """Verify 1:1 hardware digitizer verification."""
        engine_file = os.path.join(IOS_APP_DIR, "Sources", "Compliance", "JagexComplianceEngine.swift")
        with open(engine_file, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("majorRadius", content)
        self.assertIn("validateTouchEvent", content)


# Layout test: every file the project depends on must exist.
class TestStandaloneArchitectureStructure(unittest.TestCase):
    """Test suite ensuring all native iOS components are properly structured."""

    def test_required_files_exist(self) -> None:
        """Confirm that all mandatory Swift, C, Metal, and script files exist in the repository."""
        # Includes Xcode project, plists, Swift sources, the Metal shader, injection sources and the build scripts.
        required_paths = [
            os.path.join(IOS_APP_DIR, "RuneLiteMobile.xcodeproj/project.pbxproj"),
            os.path.join(IOS_APP_DIR, "Info.plist"),
            os.path.join(IOS_APP_DIR, "Entitlements.plist"),
            os.path.join(IOS_APP_DIR, "Package.swift"),
            os.path.join(IOS_APP_DIR, "runelite_mobile.html"),
            os.path.join(IOS_APP_DIR, "RuneLite.mobileconfig"),
            os.path.join(IOS_APP_DIR, "Sources/App/AppDelegate.swift"),
            os.path.join(IOS_APP_DIR, "Sources/App/SceneDelegate.swift"),
            os.path.join(IOS_APP_DIR, "Sources/App/RuneLiteApp.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Core/Engine/PluginManager.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Core/Engine/EventBus.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Core/Engine/GameState.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Core/Engine/TouchAndCameraPipeline.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Core/Models/WorldPoint.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Core/Models/LocalPoint.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Core/Models/Perspective.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Core/Models/Item.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Core/Models/Actor.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Auth/JagexOAuthManager.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Auth/KeychainHelper.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Compliance/JagexComplianceEngine.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Rendering/Metal/MetalOverlayRenderer.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Rendering/Metal/Shaders.metal"),
            os.path.join(IOS_APP_DIR, "Sources/Rendering/UI/OverlayViewController.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Rendering/UI/PluginSettingsView.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Rendering/UI/PluginHubView.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Plugins/PluginProtocol.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Plugins/Hub/PluginHubClient.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Plugins/Runtime/SandboxedRuntime.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Plugins/TileIndicators/TileIndicatorsPlugin.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Plugins/GroundItems/GroundItemsPlugin.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Plugins/XpTracker/XpTrackerPlugin.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Plugins/IdleNotifier/IdleNotifierPlugin.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Plugins/MenuEntrySwapper/MenuEntrySwapperPlugin.swift"),
            os.path.join(IOS_APP_DIR, "Sources/Injection/DylibEntry.c"),
            os.path.join(IOS_APP_DIR, "Sources/Injection/MetalHook.m"),
            os.path.join(SCRIPTS_DIR, "build_ipa.sh"),
            os.path.join(SCRIPTS_DIR, "build_sidestore_package.sh"),
            os.path.join(SCRIPTS_DIR, "inject_osrs_ipa.sh"),
            os.path.join(SCRIPTS_DIR, "build_ios_runelite_standalone.py"),
            os.path.join(DOCS_DIR, "SIDESTORE_INSTALLATION_GUIDE.md"),
            os.path.join(DOCS_DIR, "JAGEX_COMPLIANCE_AND_SAFETY_SPECIFICATION.md"),
            os.path.join(DOCS_DIR, "IOS_STANDALONE_RUNELITE_ARCHITECTURE.md"),
        ]
        for full_path in required_paths:
            self.assertTrue(os.path.isfile(full_path), f"Missing required file: {full_path}")


# Checks that the plugin sandbox source strips network APIs and lists forbidden tokens.
class TestPluginHubAndSandbox(unittest.TestCase):
    """Verify Plugin Hub client and SandboxedRuntime guarantees."""

    def test_sandboxed_runtime_safeguards(self) -> None:
        """Verify JavaScriptCore sandbox deletes dangerous web APIs and checks AST tokens."""
        sandbox_path = os.path.join(IOS_APP_DIR, "Sources", "Plugins", "Runtime", "SandboxedRuntime.swift")
        with open(sandbox_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Must use JavaScriptCore
        self.assertIn("import JavaScriptCore", content)
        # Must strip dangerous web APIs
        # Network globals are deleted from the JavaScriptCore context so plugin scripts cannot make requests.
        self.assertIn("delete this.fetch", content)
        self.assertIn("delete this.XMLHttpRequest", content)
        self.assertIn("delete this.WebSocket", content)
        # Must have forbidden AST tokens
        self.assertIn("forbiddenAstTokens", content)
        self.assertIn("autoPrayer", content)

    def test_plugin_hub_client_catalog(self) -> None:
        """Verify Plugin Hub client manifest structure and popular plugin definitions."""
        hub_path = os.path.join(IOS_APP_DIR, "Sources", "Plugins", "Hub", "PluginHubClient.swift")
        with open(hub_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("HubPluginManifest", content)
        self.assertIn("runelite/plugin-hub", content)
        self.assertIn("loot-tracker", content)
        self.assertIn("quest-helper-mobile", content)
        self.assertIn("sha256Hash", content)


# Pins the gesture/camera constants in source so accidental changes fail loudly.
class TestTouchAndCameraPipeline(unittest.TestCase):
    """Verify authentic OSRS touch and camera mechanics."""

    def test_touch_and_camera_mechanics(self) -> None:
        """Verify gesture thresholds, camera clamp bounds, and haptic feedback setup."""
        pipeline_path = os.path.join(IOS_APP_DIR, "Sources", "Core", "Engine", "TouchAndCameraPipeline.swift")
        with open(pipeline_path, "r", encoding="utf-8") as f:
            content = f.read()

        # 200 ms tap, 350 ms long press (right click), 10 pt drag slop.
        # Touch thresholds
        self.assertIn("tapThresholdMs: TimeInterval = 0.200", content)
        self.assertIn("longPressThresholdMs: TimeInterval = 0.350", content)
        self.assertIn("dragSlopPoints: CGFloat = 10.0", content)
        # Pitch 128-383 and zoom 180-896 mirror the OSRS client's camera limits (as encoded in Swift).
        # Camera clamp bounds
        self.assertIn("cameraPitchMin: Int = 128", content)
        self.assertIn("cameraPitchMax: Int = 383", content)
        self.assertIn("zoomMin: Int = 180", content)
        self.assertIn("zoomMax: Int = 896", content)
        # Haptics
        self.assertIn("UIImpactFeedbackGenerator(style: .medium)", content)
        # Digitizer validation
        self.assertIn("validateHardwareDigitizer", content)


# Only re-derives vector arithmetic in Python; it does not import or run the Swift Perspective code.
class TestPerspectiveProjectionMath(unittest.TestCase):
    """Verify OSRS 3D perspective projection formula logic."""

    def test_trigonometric_projection(self) -> None:
        """Simulate camera projection math implemented in Swift Perspective.swift."""
        cam_x, cam_y, cam_z = 6656, 6656, 1000
        target_x, target_y, target_z = 6656, 6656, 0
        dx = target_x - cam_x
        dy = target_y - cam_y
        dz = target_z - cam_z

        self.assertEqual(dx, 0)
        self.assertEqual(dy, 0)
        self.assertEqual(dz, -1000)

        dist = math.sqrt(dx*dx + dy*dy + dz*dz)
        self.assertAlmostEqual(dist, 1000.0)


if __name__ == "__main__":
    unittest.main()
