from __future__ import annotations

from pathlib import Path


def main() -> None:
    spec_path = Path("buildozer.spec")
    if not spec_path.exists():
        raise SystemExit("buildozer.spec not found.")

    domain = ""
    name = ""
    in_app = False

    for raw in spec_path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            in_app = line == "[app]"
            continue
        if not in_app or "=" not in line:
            continue
        key, value = [x.strip() for x in line.split("=", 1)]
        if key == "package.domain":
            domain = value
        elif key == "package.name":
            name = value

    if not domain or not name:
        raise SystemExit("Could not detect package.domain/package.name in buildozer.spec")

    print(f"{domain}.{name}")


if __name__ == "__main__":
    main()

