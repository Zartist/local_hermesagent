#!/usr/bin/env python3
"""
Patch the ACP adapter to use a configurable approval timeout (default 600s
instead of the hardcoded 60s).

This is needed because the ACP adapter's make_approval_callback and
make_acp_edit_approval_requester both default to 60 seconds, which is too
short for browser-based approval via chat.php.

Run this after `hermes update` or `pip install --upgrade hermes-agent`.
"""
import sys
from pathlib import Path

VENV = Path(sys.prefix)
SITE = VENV / "lib" / f"python{sys.version_info.major}.{sys.version_info.minor}" / "site-packages"

FILES = [
    SITE / "acp_adapter" / "permissions.py",
    SITE / "acp_adapter" / "edit_approval.py",
]

OLD = "timeout: float = 60.0,"
NEW = 'timeout: float = float(__import__("os").environ.get("ACP_APPROVAL_TIMEOUT", "600")),'

patched = 0
for f in FILES:
    if not f.exists():
        print(f"SKIP: {f} not found")
        continue
    text = f.read_text()
    if NEW in text:
        print(f"OK: {f.name} already patched")
        patched += 1
        continue
    if OLD in text:
        text = text.replace(OLD, NEW)
        f.write_text(text)
        print(f"PATCHED: {f.name}")
        patched += 1
    else:
        # Check if it was patched with the old syntax
        if 'ACP_APPROVAL_TIMEOUT' in text:
            print(f"OK: {f.name} already patched (variant)")
            patched += 1
        else:
            print(f"WARN: {f.name} — could not find pattern to patch")

if patched == len(FILES):
    print("\nAll files patched successfully.")
else:
    print(f"\nWARNING: Only {patched}/{len(FILES)} files patched.")
    sys.exit(1)
