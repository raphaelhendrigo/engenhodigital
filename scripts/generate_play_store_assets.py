#!/usr/bin/env python3
"""
Generate Play Store listing assets for Fastlane Supply from existing app assets.

This is meant to unblock "zero day-to-day clicks" by ensuring required store listing
images exist in `fastlane/metadata/android/<locale>/images/...`.

Inputs (expected to exist in this repo):
- assets/store/icon_512.png (preferred) or assets/images/icon.png -> Play Store icon
- assets/images/presplash.png (1080x1920) -> used as a screenshot + to derive featureGraphic

Outputs (generated, safe to commit if you want, but not required):
- fastlane/metadata/android/<locale>/images/icon.png
- fastlane/metadata/android/<locale>/images/featureGraphic.png (1024x500)
- fastlane/metadata/android/<locale>/images/phoneScreenshots/{1,2}.png
- fastlane/metadata/android/<locale>/images/sevenInchScreenshots/{1,2}.png
- fastlane/metadata/android/<locale>/images/tenInchScreenshots/{1,2}.png
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path


def _require(path: Path) -> None:
    if not path.is_file():
        raise SystemExit(f"Missing required file: {path.as_posix()}")


def _copy(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)


def _generate_feature_graphic(presplash_png: Path, out_png: Path) -> None:
    # Pillow is intentionally imported lazily so the script can fail with a clear message.
    try:
        from PIL import Image  # type: ignore
    except Exception as e:  # pragma: no cover
        raise SystemExit(
            "Pillow is required to generate featureGraphic.png. Install it with: python -m pip install Pillow"
        ) from e

    with Image.open(presplash_png) as im:
        im = im.convert("RGBA")
        w, h = im.size
        target_w, target_h = 1024, 500

        if w < target_w or h < target_h:
            raise SystemExit(
                f"presplash too small ({w}x{h}). Need at least {target_w}x{target_h} to crop a feature graphic."
            )

        # Center-crop to 1024x500. This works well for typical splash screens with a centered logo.
        left = (w - target_w) // 2
        upper = (h - target_h) // 2
        cropped = im.crop((left, upper, left + target_w, upper + target_h))

        out_png.parent.mkdir(parents=True, exist_ok=True)
        cropped.save(out_png, format="PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Play Store listing images for Fastlane Supply.")
    parser.add_argument("--locale", default="pt-BR", help="Locale folder under fastlane/metadata/android (default: pt-BR)")
    parser.add_argument(
        "--metadata-root",
        default="fastlane/metadata/android",
        help="Fastlane metadata root (default: fastlane/metadata/android)",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    store_icon_src = repo_root / "assets" / "store" / "icon_512.png"
    fallback_icon_src = repo_root / "assets" / "images" / "icon.png"
    icon_src = store_icon_src if store_icon_src.is_file() else fallback_icon_src
    presplash_src = repo_root / "assets" / "images" / "presplash.png"
    _require(icon_src)
    _require(presplash_src)

    images_root = repo_root / args.metadata_root / args.locale / "images"

    # Core assets
    _copy(icon_src, images_root / "icon.png")
    _generate_feature_graphic(presplash_src, images_root / "featureGraphic.png")

    # Minimal screenshots: duplicate presplash to satisfy minimum counts.
    # You can replace these later with real app screenshots, keeping the same paths.
    for folder in ["phoneScreenshots", "sevenInchScreenshots", "tenInchScreenshots"]:
        _copy(presplash_src, images_root / folder / "1.png")
        _copy(presplash_src, images_root / folder / "2.png")

    print(f"Generated Play Store assets under: {images_root.as_posix()}")


if __name__ == "__main__":
    main()
