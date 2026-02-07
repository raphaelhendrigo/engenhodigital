from __future__ import annotations

import argparse
import os
import re
from datetime import datetime, timezone
from pathlib import Path

SEMVER_TAG_RE = re.compile(r"^v?(?P<ver>\d+\.\d+\.\d+)(?:[-+].*)?$")


def _append_env(env_file: Path, key: str, value: str) -> None:
    env_file.parent.mkdir(parents=True, exist_ok=True)
    with env_file.open("a", encoding="utf-8", newline="\n") as f:
        f.write(f"{key}={value}\n")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Set ANDROID_VERSION_NAME / ANDROID_NUMERIC_VERSION based on CI context (tag/run)."
    )
    parser.add_argument(
        "--env-file",
        default=os.getenv("GITHUB_ENV", ""),
        help="File to append environment variables to (default: $GITHUB_ENV).",
    )
    parser.add_argument(
        "--ref-name",
        default=os.getenv("GITHUB_REF_NAME", ""),
        help="Git ref name (default: $GITHUB_REF_NAME).",
    )
    parser.add_argument(
        "--run-number",
        type=int,
        default=int(os.getenv("GITHUB_RUN_NUMBER", "0") or 0),
        help="GitHub run number (default: $GITHUB_RUN_NUMBER).",
    )
    parser.add_argument(
        "--version-name",
        default="",
        help="Optional versionName override (e.g., 1.2.3 or v1.2.3).",
    )
    parser.add_argument(
        "--version-code",
        type=int,
        default=0,
        help="Optional versionCode override (integer).",
    )

    args = parser.parse_args()

    env_file = Path(args.env_file) if args.env_file else None
    if env_file is None:
        raise SystemExit("Missing --env-file (or $GITHUB_ENV).")

    version_name = (args.version_name or "").strip()
    if version_name:
        m = SEMVER_TAG_RE.match(version_name)
        if not m:
            raise SystemExit(f"Invalid --version-name: {version_name!r}. Expected X.Y.Z or vX.Y.Z.")
        version_name = m.group("ver")
    else:
        m = SEMVER_TAG_RE.match((args.ref_name or "").strip())
        if m:
            version_name = m.group("ver")

    if args.version_code:
        version_code = args.version_code
    else:
        # Keep versionCode < 2_147_483_647:
        # YYYYMMDD * 100 + (run_number % 100)  -> up to ~2_099_123_199
        date_code = int(datetime.now(timezone.utc).strftime("%Y%m%d"))
        run_mod = (args.run_number or 0) % 100
        version_code = date_code * 100 + run_mod

    _append_env(env_file, "ANDROID_NUMERIC_VERSION", str(version_code))
    if version_name:
        _append_env(env_file, "ANDROID_VERSION_NAME", version_name)

    print(f"ANDROID_NUMERIC_VERSION={version_code}")
    if version_name:
        print(f"ANDROID_VERSION_NAME={version_name}")


if __name__ == "__main__":
    main()

