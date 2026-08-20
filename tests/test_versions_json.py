import json
import re
from pathlib import Path

ROOT = Path(__file__).parent.parent


def load():
    return json.loads((ROOT / "versions.json").read_text())


def test_structure():
    d = load()
    assert d["version"]
    assert d["sha256"]
    assert isinstance(d["urls"], list) and len(d["urls"]) >= 1


def test_sha256_hex():
    assert re.fullmatch(r"[0-9a-f]{64}", load()["sha256"])


def test_urls_https():
    for u in load()["urls"]:
        assert u.startswith("https://")
