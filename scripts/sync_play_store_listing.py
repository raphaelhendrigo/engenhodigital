#!/usr/bin/env python3
"""
Sync Play Store listing (text + images/screenshots) using the Android Publisher API directly.

Why not Fastlane supply here?
- `supply`/`upload_to_play_store` can try to update track releases even when only syncing listing assets,
  which fails for apps still in "draft" state (and can also default to `production` track).
- This script only touches listing resources (listings/details/images) and avoids track/release changes.

Auth:
- Uses the same credential file already produced by GitHub Actions WIF (`PLAY_JSON_KEY_PATH`), or the
  fallback service account JSON file path.
"""

from __future__ import annotations

import argparse
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

ANDROIDPUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"


@dataclass(frozen=True)
class ListingInputs:
    package_name: str
    locale: str
    title: str
    short_description: str
    full_description: str
    images_root: Path


def _read_text(path: Path) -> str:
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        raise SystemExit(f"Empty file: {path.as_posix()}")
    return text


def _require_file(path: Path) -> None:
    if not path.is_file():
        raise SystemExit(f"Missing required file: {path.as_posix()}")


def _iter_sorted_images(dir_path: Path) -> list[Path]:
    if not dir_path.is_dir():
        return []
    files = [p for p in dir_path.iterdir() if p.is_file() and p.suffix.lower() in {".png", ".jpg", ".jpeg"}]
    return sorted(files, key=lambda p: p.name)


def _load_listing_inputs(metadata_root: Path, locale: str, package_name: str) -> ListingInputs:
    locale_dir = metadata_root / locale
    title = _read_text(locale_dir / "title.txt")
    short_description = _read_text(locale_dir / "short_description.txt")
    full_description = _read_text(locale_dir / "full_description.txt")

    images_root = locale_dir / "images"
    _require_file(images_root / "icon.png")
    _require_file(images_root / "featureGraphic.png")

    # Phone screenshots are required by Play (min 2). The generator ensures at least 2 exist.
    phone_screens = _iter_sorted_images(images_root / "phoneScreenshots")
    if len(phone_screens) < 2:
        raise SystemExit(
            f"Need at least 2 phone screenshots under: {(images_root / 'phoneScreenshots').as_posix()}"
        )

    return ListingInputs(
        package_name=package_name,
        locale=locale,
        title=title,
        short_description=short_description,
        full_description=full_description,
        images_root=images_root,
    )


def _get_creds_path(args_json_key_path: str) -> str:
    candidates: list[str] = []
    if args_json_key_path:
        candidates.append(args_json_key_path)
    if os.getenv("PLAY_JSON_KEY_PATH"):
        candidates.append(os.environ["PLAY_JSON_KEY_PATH"])
    if os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
        candidates.append(os.environ["GOOGLE_APPLICATION_CREDENTIALS"])

    for c in candidates:
        p = Path(c)
        if p.is_file():
            return str(p)
    raise SystemExit(
        "Could not locate credentials file. Provide --json-key-path or set PLAY_JSON_KEY_PATH/GOOGLE_APPLICATION_CREDENTIALS."
    )


def _mime_for(path: Path) -> str:
    ext = path.suffix.lower()
    if ext == ".png":
        return "image/png"
    if ext in {".jpg", ".jpeg"}:
        return "image/jpeg"
    return "application/octet-stream"


def _upload_images(
    service,
    *,
    package_name: str,
    edit_id: str,
    locale: str,
    image_type: str,
    files: Iterable[Path],
    dry_run: bool,
) -> None:
    from googleapiclient.http import MediaFileUpload  # type: ignore

    files = list(files)
    if not files:
        return

    if dry_run:
        print(f"[dry-run] deleteall {image_type} ({locale})")
    else:
        service.edits().images().deleteall(
            packageName=package_name,
            editId=edit_id,
            language=locale,
            imageType=image_type,
        ).execute()

    for f in files:
        if dry_run:
            print(f"[dry-run] upload {image_type} ({locale}): {f.as_posix()}")
            continue
        media = MediaFileUpload(str(f), mimetype=_mime_for(f), resumable=False)
        service.edits().images().upload(
            packageName=package_name,
            editId=edit_id,
            language=locale,
            imageType=image_type,
            media_body=media,
        ).execute()


def main() -> None:
    parser = argparse.ArgumentParser(description="Sync Play Store listing assets via Android Publisher API.")
    parser.add_argument("--package-name", default=os.getenv("PLAY_PACKAGE_NAME", ""), help="Android package name")
    parser.add_argument(
        "--json-key-path",
        default="",
        help="Credentials file path (WIF external_account JSON or service account JSON). Defaults to PLAY_JSON_KEY_PATH/GOOGLE_APPLICATION_CREDENTIALS.",
    )
    parser.add_argument("--locale", default="pt-BR", help="Play listing locale (default: pt-BR)")
    parser.add_argument(
        "--metadata-root",
        default="fastlane/metadata/android",
        help="Fastlane metadata root (default: fastlane/metadata/android)",
    )
    parser.add_argument("--dry-run", action="store_true", help="Do not call the API; only validate and print actions.")
    args = parser.parse_args()

    package_name = (args.package_name or "").strip()
    if not package_name:
        raise SystemExit("Missing --package-name (or env PLAY_PACKAGE_NAME).")

    repo_root = Path(__file__).resolve().parent.parent
    metadata_root = (repo_root / args.metadata_root).resolve()
    listing = _load_listing_inputs(metadata_root, args.locale, package_name)

    if args.dry_run:
        print(f"[dry-run] package={listing.package_name} locale={listing.locale} metadata_root={metadata_root.as_posix()}")
        print(f"[dry-run] title: {listing.title}")

    creds_path = _get_creds_path(args.json_key_path)
    if args.dry_run:
        print(f"[dry-run] creds: {creds_path}")

    from google.auth import load_credentials_from_file  # type: ignore
    from googleapiclient.discovery import build  # type: ignore

    creds, _ = load_credentials_from_file(creds_path, scopes=[ANDROIDPUBLISHER_SCOPE])
    service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)

    if args.dry_run:
        edit_id = "dry-run-edit"
    else:
        edit = service.edits().insert(packageName=listing.package_name, body={}).execute()
        edit_id = edit["id"]

    # 1) Ensure listing exists / update required text fields
    listing_body = {
        "title": listing.title,
        "shortDescription": listing.short_description,
        "fullDescription": listing.full_description,
    }
    if args.dry_run:
        print(f"[dry-run] listings.update ({listing.locale})")
    else:
        service.edits().listings().update(
            packageName=listing.package_name,
            editId=edit_id,
            language=listing.locale,
            body=listing_body,
        ).execute()

    # 2) Upload images/screenshots (replace existing)
    images_root = listing.images_root
    _upload_images(
        service,
        package_name=listing.package_name,
        edit_id=edit_id,
        locale=listing.locale,
        image_type="icon",
        files=[images_root / "icon.png"],
        dry_run=args.dry_run,
    )
    _upload_images(
        service,
        package_name=listing.package_name,
        edit_id=edit_id,
        locale=listing.locale,
        image_type="featureGraphic",
        files=[images_root / "featureGraphic.png"],
        dry_run=args.dry_run,
    )

    for folder, image_type in [
        ("phoneScreenshots", "phoneScreenshots"),
        ("sevenInchScreenshots", "sevenInchScreenshots"),
        ("tenInchScreenshots", "tenInchScreenshots"),
    ]:
        _upload_images(
            service,
            package_name=listing.package_name,
            edit_id=edit_id,
            locale=listing.locale,
            image_type=image_type,
            files=_iter_sorted_images(images_root / folder),
            dry_run=args.dry_run,
        )

    # 3) Commit
    if args.dry_run:
        print("[dry-run] edits.commit")
    else:
        service.edits().commit(packageName=listing.package_name, editId=edit_id).execute()
        print(f"Synced Play Store listing for {listing.package_name} ({listing.locale}).")


if __name__ == "__main__":
    main()

