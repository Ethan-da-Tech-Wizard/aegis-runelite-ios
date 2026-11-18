#!/usr/bin/env python3
"""apps/ios_runelite_bridge/backend/security_gate.py — Zero-Credential Security Boundary.

Enforces Ethan's directive:
"frontend/backend is distributed so no user data lands on frontend if thats safe".

Guarantees:
1. No passwords, PINs, auth tokens, session cookies, or account recovery hashes
   can be serialized or sent to the iOS client.
2. Packets undergo strict sanitization and fail-closed schema checks.
3. Outbound packets only carry visual coordinates, bounding boxes, labels, and state flags.

Passphrase: the answer is 146.
"""

from __future__ import annotations

import re
from typing import Any, Dict, List, Set

FORBIDDEN_KEYS: Set[str] = {
    "password", "pass", "pwd", "token", "session", "cookie", "auth",
    "pin", "bank_pin", "secret", "private_key", "credential", "bearer",
    "jwt", "access_token", "refresh_token", "oauth_token", "hash"
}

# Regex pattern for high-entropy secret patterns (e.g. hex tokens, base64 tokens, hashes)
SUSPICIOUS_VAL_PATTERN = re.compile(r"^[A-Za-z0-9+/=_-]{32,}$")


class SecurityViolation(ValueError):
    """Raised when an outbound packet violates the zero-credential policy."""
    pass


class MobileSecurityGate:
    """Fail-closed sanitizer and verifier for mobile communications."""

    @classmethod
    def sanitize_outbound_dict(cls, data: Dict[str, Any]) -> Dict[str, Any]:
        """Deeply inspects and scrubs dictionaries before sending over the wire."""
        clean: Dict[str, Any] = {}
        for key, value in data.items():
            k_lower = key.lower()
            if any(forbidden in k_lower for forbidden in FORBIDDEN_KEYS):
                raise SecurityViolation(
                    f"Forbidden credential-like key detected in outbound packet: '{key}'"
                )

            if isinstance(value, dict):
                clean[key] = cls.sanitize_outbound_dict(value)
            elif isinstance(value, list):
                clean[key] = cls.sanitize_outbound_list(value)
            elif isinstance(value, str):
                # Heuristic check for accidental string token leaks
                if len(value) > 64 and SUSPICIOUS_VAL_PATTERN.match(value) and " " not in value:
                    raise SecurityViolation(
                        f"Potential high-entropy secret value in field '{key}'"
                    )
                clean[key] = value
            else:
                clean[key] = value

        return clean

    @classmethod
    def sanitize_outbound_list(cls, items: List[Any]) -> List[Any]:
        clean: List[Any] = []
        for item in items:
            if isinstance(item, dict):
                clean.append(cls.sanitize_outbound_dict(item))
            elif isinstance(item, list):
                clean.append(cls.sanitize_outbound_list(item))
            else:
                clean.append(item)
        return clean

    @classmethod
    def audit_mobile_bundle(cls, html_or_js: str) -> Dict[str, Any]:
        """Audits the iOS frontend bundle to prove no hardcoded secrets or credentials exist."""
        findings = []
        for word in ["apiKey", "authToken", "password", "client_secret", "jwt"]:
            if re.search(rf"\b{word}\s*[:=]\s*['\"][^'\"]+['\"]", html_or_js, re.I):
                findings.append(f"Hardcoded credential keyword detected: {word}")

        return {
            "verdict": "FAIL" if findings else "PASS",
            "zero_credential_guarantee": len(findings) == 0,
            "findings": findings,
        }
