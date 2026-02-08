from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def _git_ls_files_json(repo_root: Path) -> tuple[list[Path], bool]:
    try:
        out = subprocess.check_output(
            ["git", "ls-files", "-z", "--", "*.json"],
            cwd=str(repo_root),
        )
    except (OSError, subprocess.CalledProcessError):
        return ([], False)

    paths: list[Path] = []
    for raw in out.decode("utf-8", errors="replace").split("\0"):
        if not raw:
            continue
        paths.append((repo_root / raw).resolve())
    return (paths, True)


def _walk_json_files(repo_root: Path) -> list[Path]:
    excluded = {
        ".git",
        ".venv",
        "__pycache__",
        ".buildozer",
        "bin",
        "keystore",
        "play_upload",
    }

    results: list[Path] = []
    for root, dirs, files in os.walk(repo_root):
        # Prune excluded directories
        dirs[:] = [d for d in dirs if d not in excluded]
        for name in files:
            if not name.lower().endswith(".json"):
                continue
            results.append((Path(root) / name).resolve())
    return results


def _looks_like_service_account_key(text: str) -> bool:
    # CI-oriented heuristic: fail fast if a tracked JSON file contains "private_key".
    # This catches committed Google service account keys (and other likely secrets).
    return '"private_key"' in text


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Scan tracked JSON files for patterns that look like Google service account keys. "
            "This is meant to fail CI if secrets are accidentally committed."
        )
    )
    parser.add_argument(
        "--paths",
        nargs="*",
        default=None,
        help="Optional explicit paths to scan. If omitted, scans tracked *.json files via git.",
    )
    args = parser.parse_args(argv)

    if args.paths:
        candidates = [(REPO_ROOT / p).resolve() for p in args.paths]
    else:
        candidates, ok = _git_ls_files_json(REPO_ROOT)
        if not ok:
            # Fallback (e.g., running outside git). In CI, checkout normally includes git metadata.
            candidates = _walk_json_files(REPO_ROOT)

    offenders: list[Path] = []
    for path in candidates:
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        if _looks_like_service_account_key(text):
            offenders.append(path)

    if offenders:
        rel = [str(p.relative_to(REPO_ROOT)) for p in offenders]
        print("ERROR: Potential Google service account key detected in tracked JSON file(s):", file=sys.stderr)
        for p in rel:
            print(f"- {p}", file=sys.stderr)
        print("", file=sys.stderr)
        print("Fix:", file=sys.stderr)
        print("- Remove the file(s) from git history if needed (and from the repo working tree).", file=sys.stderr)
        print("- Rotate/revoke the leaked key(s) in Google Cloud immediately.", file=sys.stderr)
        print("- Keep real keys out of the repo (use GitHub Secrets or WIF/OIDC).", file=sys.stderr)
        return 2

    print("OK: no committed service account keys detected in tracked JSON files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
