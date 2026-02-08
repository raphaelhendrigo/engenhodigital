import unittest
from pathlib import Path


def parse_buildozer_spec(path: str = "buildozer.spec") -> dict[str, str]:
    values: dict[str, str] = {}
    in_app = False

    for raw in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            in_app = line == "[app]"
            continue
        if not in_app or "=" not in line:
            continue
        key, value = [x.strip() for x in line.split("=", 1)]
        values[key] = value

    return values


class BuildozerSpecTests(unittest.TestCase):
    def test_package_name_is_present(self) -> None:
        spec = parse_buildozer_spec()
        self.assertIn("package.domain", spec)
        self.assertIn("package.name", spec)

        package_name = f"{spec['package.domain']}.{spec['package.name']}"
        self.assertTrue(package_name)
        self.assertIn(".", package_name)

    def test_release_artifact_is_aab(self) -> None:
        spec = parse_buildozer_spec()
        self.assertEqual(spec.get("android.release_artifact", "").strip().lower(), "aab")

    def test_target_api_is_35_or_higher(self) -> None:
        spec = parse_buildozer_spec()
        self.assertIn("android.api", spec)

        api_raw = spec.get("android.api", "").strip()
        self.assertTrue(api_raw.isdigit(), f"android.api must be numeric (got: {api_raw!r})")
        self.assertGreaterEqual(int(api_raw), 35)


if __name__ == "__main__":
    unittest.main()
