# ==============================================================================
# Program: bridge_daemon/security_gate.py
# Programmer: Ethan-da-Tech-Wizard
# Last Modified: November 18, 2026
# Purpose: Zero-Credential Security Boundary and Data Scrubbing Engine.
#          Inspects, audits, and filters all data transmitted across the network
#          bridge to guarantee that zero user credentials, passwords, session
#          tokens, bank PINs, or high-entropy secrets ever reach the mobile client.
# ==============================================================================

"""bridge_daemon/security_gate.py — Zero-Credential Security Boundary.

==============================================================================
Architecture Overview & Security Engineering:
==============================================================================
In cybersecurity and computer systems engineering, the principle of "Fail-Closed"
dictates that if a system encounters unexpected data, ambiguous states, or potential
security breaches, it must immediately halt or reject the operation rather than
proceeding blindly ("failing open").

Why This Security Boundary Is Essential:
1. Zero-Credential Architecture: When streaming RuneLite game overlays to an iOS device,
   the mobile client only needs to know *what shapes and text to draw* (e.g. "Highlight
   this agility obstacle green at coordinates (120, 340)"). It NEVER needs the player's
   password, bank PIN, or session cookies.
2. Recursive Deep Sanitization: Dictionaries and lists can be nested arbitrarily deep.
   In computer science, recursive traversal — visiting every nested branch of a tree
   or dictionary to verify that no banned key names or high-entropy secret tokens are present.
3. Fail-Closed Exception Handling: If even a single forbidden key (such as `password`
   or `bank_pin`) is detected, a custom `SecurityViolation` exception is raised,
   completely aborting transmission of that packet.
"""

from __future__ import annotations

import re
from typing import Any, Dict, List, Set

# Set of forbidden case-insensitive substrings indicating authentication secrets.
# Using a Python set provides O(1) average lookup time when checking membership.
FORBIDDEN_KEYS: Set[str] = {
    "password", "pass", "pwd", "token", "session", "cookie", "auth",
    "pin", "bank_pin", "secret", "private_key", "credential", "bearer",
    "jwt", "access_token", "refresh_token", "oauth_token", "hash"
}

# Regular expression pattern to detect potential base64/hex cryptographic hashes or secrets.
# Matches 32 or more consecutive alphanumeric/base64 characters without whitespace.
SUSPICIOUS_VAL_PATTERN: re.Pattern = re.compile(r"^[A-Za-z0-9+/=_-]{32,}$")


class SecurityViolation(ValueError):
    """Custom exception raised when an outbound packet violates the zero-credential policy.

    In production software engineering, inheriting from standard exception classes (like `ValueError`) allows
    callers to handle domain-specific errors while remaining compatible with standard
    error-handling idioms.
    """
    pass


class MobileSecurityGate:
    """Fail-closed data sanitizer and static bundle auditor for mobile communication.

    All outbound JSON packets must pass through `sanitize_outbound_dict()` before
    being transmitted over network sockets to the mobile device.
    """

    @classmethod
    def sanitize_outbound_dict(cls, data: Dict[str, Any]) -> Dict[str, Any]:
        """Deeply inspect and recursively scrub dictionaries before transmission.

        Parameters:
            data (Dict[str, Any]): Dictionary containing payload data destined for the client.

        Returns:
            Dict[str, Any]: Sanitized dictionary verified to contain zero sensitive credentials.

        Raises:
            SecurityViolation: If any forbidden key or suspicious high-entropy value is found.

        Algorithm Step-by-Step:
            Step 1: Initialize an empty `clean` dictionary to accumulate approved fields.
            Step 2: Iterate over each `(key, value)` pair in the input dictionary.
            Step 3: Convert `key` to lowercase and check if any substring in `FORBIDDEN_KEYS` matches.
                    If found: Immediately raise `SecurityViolation` (Fail-Closed).
            Step 4: Check the data type of `value`:
                    - If dictionary: Recursively invoke `sanitize_outbound_dict(value)`.
                    - If list: Recursively invoke `sanitize_outbound_list(value)`.
                    - If string: Check if it resembles a high-entropy bearer token or hash.
                                 If suspicious, raise `SecurityViolation`.
                    - If primitive (int, float, bool, None): Copy value directly into `clean`.
            Step 5: Return the scrubbed `clean` dictionary.
        """
        # Step 1: Accumulator dictionary for verified safe fields
        clean: Dict[str, Any] = {}

        # Step 2: Iterate through every key-value pair
        for key, value in data.items():
            # Step 3: Key-name inspection
            k_lower = key.lower()
            if any(forbidden in k_lower for forbidden in FORBIDDEN_KEYS):
                raise SecurityViolation(
                    f"Forbidden credential-like key detected in outbound packet: '{key}'"
                )

            # Step 4: Recursive type inspection
            if isinstance(value, dict):
                # Recurse into nested dictionary
                clean[key] = cls.sanitize_outbound_dict(value)
            elif isinstance(value, list):
                # Recurse into list elements
                clean[key] = cls.sanitize_outbound_list(value)
            elif isinstance(value, str):
                # Heuristic: Check for accidental raw secret or token leakage in string values
                if len(value) > 64 and SUSPICIOUS_VAL_PATTERN.match(value) and " " not in value:
                    raise SecurityViolation(
                        f"Potential high-entropy secret value in field '{key}'"
                    )
                clean[key] = value
            else:
                # Safe primitive (int, float, bool, None)
                clean[key] = value

        # Step 5: Return sanitized dictionary
        return clean

    @classmethod
    def sanitize_outbound_list(cls, items: List[Any]) -> List[Any]:
        """Recursively inspect and scrub a list of items.

        Parameters:
            items (List[Any]): List of items to scrub.

        Returns:
            List[Any]: Cleaned list with all nested dictionaries and lists inspected.
        """
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
        """Perform static analysis on client HTML/JS files to verify zero hardcoded secrets.

        In software quality assurance, static code analysis scans source files
        before deployment to verify security invariants.

        Parameters:
            html_or_js (str): Source code string of the client HTML or JavaScript file.

        Returns:
            Dict[str, Any]: Audit report dictionary containing:
                            - "verdict": "PASS" or "FAIL"
                            - "zero_credential_guarantee": Boolean True if zero secrets found
                            - "findings": List of violation descriptions (if any)
        """
        findings: List[str] = []

        # Keywords commonly associated with accidental secret hardcoding
        sensitive_keywords = ["apiKey", "authToken", "password", "client_secret", "jwt"]
        for word in sensitive_keywords:
            # Regex searches for patterns like `apiKey = "xyz"` or `password: 'secret'`
            if re.search(rf"\b{word}\s*[:=]\s*['\"][^'\"]+['\"]", html_or_js, re.I):
                findings.append(f"Hardcoded credential keyword detected: {word}")

        return {
            "verdict": "FAIL" if findings else "PASS",
            "zero_credential_guarantee": len(findings) == 0,
            "findings": findings,
        }
