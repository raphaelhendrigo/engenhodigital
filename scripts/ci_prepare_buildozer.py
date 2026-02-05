from __future__ import annotations

import os
from pathlib import Path

SPEC_PATH = Path(__file__).resolve().parents[1] / "buildozer.spec"

REQUIRED_ENV = {
    "ANDROID_KEYSTORE_PATH": "android.release_keystore",
    "ANDROID_KEYSTORE_PASSWORD": "android.release_keystore_pass",
    "ANDROID_KEY_ALIAS": "android.release_keyalias",
    "ANDROID_KEY_ALIAS_PASSWORD": "android.release_keyalias_pass",
}

OPTIONAL_ENV = {
    "ANDROID_SDK_PATH": "android.sdk_path",
    "ANDROID_NDK_PATH": "android.ndk_path",
    "ANDROID_NUMERIC_VERSION": "android.numeric_version",
    "ANDROID_VERSION_NAME": "version",
}


def main() -> None:
    missing = [key for key in REQUIRED_ENV if not os.getenv(key)]
    if missing:
        raise SystemExit(f"Missing environment variables: {', '.join(missing)}")

    set_numeric = bool(os.getenv("ANDROID_NUMERIC_VERSION"))
    set_version_name = bool(os.getenv("ANDROID_VERSION_NAME"))
    set_sdk_path = bool(os.getenv("ANDROID_SDK_PATH"))
    set_ndk_path = bool(os.getenv("ANDROID_NDK_PATH"))

    lines = SPEC_PATH.read_text(encoding="utf-8").splitlines()

    # Remove existing release signing lines to avoid duplicates.
    def is_release_line(line: str) -> bool:
        stripped = line.strip()
        return stripped.startswith("android.release_")

    def is_sdk_line(line: str) -> bool:
        stripped = line.strip()
        return (
            (set_sdk_path and stripped.startswith("android.sdk_path"))
            or (set_ndk_path and stripped.startswith("android.ndk_path"))
            or (set_numeric and stripped.startswith("android.numeric_version"))
            or (set_version_name and stripped.startswith("version ="))
        )

    filtered: list[str] = [line for line in lines if not is_release_line(line) and not is_sdk_line(line)]

    # Find [app] section boundaries
    try:
        app_start = next(i for i, line in enumerate(filtered) if line.strip() == "[app]")
    except StopIteration as exc:
        raise SystemExit("Missing [app] section in buildozer.spec") from exc

    next_section = next(
        (i for i in range(app_start + 1, len(filtered)) if filtered[i].strip().startswith("[")),
        len(filtered),
    )

    insert_index = next_section

    release_lines = [
        f"{REQUIRED_ENV['ANDROID_KEYSTORE_PATH']} = {os.environ['ANDROID_KEYSTORE_PATH']}",
        f"{REQUIRED_ENV['ANDROID_KEYSTORE_PASSWORD']} = {os.environ['ANDROID_KEYSTORE_PASSWORD']}",
        f"{REQUIRED_ENV['ANDROID_KEY_ALIAS']} = {os.environ['ANDROID_KEY_ALIAS']}",
        f"{REQUIRED_ENV['ANDROID_KEY_ALIAS_PASSWORD']} = {os.environ['ANDROID_KEY_ALIAS_PASSWORD']}",
    ]

    sdk_lines: list[str] = []
    for env_key, spec_key in OPTIONAL_ENV.items():
        value = os.getenv(env_key)
        if value:
            sdk_lines.append(f"{spec_key} = {value}")

    output = filtered[:insert_index] + release_lines + sdk_lines + filtered[insert_index:]
    SPEC_PATH.write_text("\n".join(output) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
