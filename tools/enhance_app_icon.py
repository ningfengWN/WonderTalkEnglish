#!/usr/bin/env python3
"""Sharpen the EXISTING WonderTalk bunny/panda app icon, without redrawing it.

The original asset is pinned to a Git blob, making this operation repeatable
and preventing repeated sharpening. The resulting 1024x1024 PNG replaces the
existing AppIcon image referenced by Assets.xcassets/Contents.json.

Usage:
    python3 -m pip install Pillow
    python3 tools/enhance_app_icon.py
"""
from __future__ import annotations

import io
import subprocess
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ICON = ROOT / "WonderTalkEnglish/Assets.xcassets/AppIcon.appiconset/WonderTalkCrayonBunnyPanda.png"

# This is the ORIGINAL committed bunny-and-panda image, not the newly drawn
# replacement. Always enhance this exact source to preserve its composition.
ORIGINAL_BLOB_SHA = "f1b7928a2b9d178c0b7cf8e5ec935ed43e81f4cd"


def main() -> None:
    try:
        original = subprocess.check_output(
            ["git", "-C", str(ROOT), "cat-file", "blob", ORIGINAL_BLOB_SHA]
        )
    except subprocess.CalledProcessError as exc:
        raise SystemExit(
            "Original icon blob is unavailable. Fetch full history with "
            "git fetch --unshallow (or git fetch --all) and retry."
        ) from exc

    with Image.open(io.BytesIO(original)) as image:
        if image.size != (1024, 1024):
            raise SystemExit(f"Unexpected original icon dimensions: {image.size}")
        # Gentle, detail-preserving sharpening: no change of illustration,
        # colors, character shapes, layout, or background.
        result = image.convert("RGB").filter(
            ImageFilter.UnsharpMask(radius=1.35, percent=160, threshold=2)
        )
        ICON.parent.mkdir(parents=True, exist_ok=True)
        result.save(ICON, format="PNG", optimize=True)

    print(f"Enhanced original icon in-place: {ICON} (1024x1024)")


if __name__ == "__main__":
    main()
