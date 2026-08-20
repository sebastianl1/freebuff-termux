import re
from pathlib import Path

ROOT = Path(__file__).parent.parent


def test_installer_has_set_e():
    src = (ROOT / "install.sh").read_text()
    assert re.search(r"^set -[a-zA-Z]*e", src, re.M), "install.sh debe usar set -e"


def test_no_http_plain_downloads():
    src = (ROOT / "install.sh").read_text()
    bad = [ln for ln in src.splitlines() if "curl" in ln and "http://" in ln]
    assert not bad, f"curl con http:// encontrado: {bad}"


def test_curl_use_proto_https():
    src = (ROOT / "install.sh").read_text()
    curl_lines = [ln for ln in src.splitlines() if re.search(r"curl\s+-[A-Za-z]", ln)]
    assert curl_lines, "debe haber descargas con curl"
    without_proto = [ln for ln in curl_lines if "--proto" not in ln]
    assert not without_proto, f"curl sin --proto =https: {without_proto}"


def test_freebuff_target():
    src = (ROOT / "launcher.c").read_text()
    assert "FREEBUFF_BINARY_TARGET" in src, "launcher.c debe manejar FREEBUFF_BINARY_TARGET"
    assert "linux-arm64" in src, "launcher.c debe usar target linux-arm64"


def test_glibc_handling():
    src = (ROOT / "install.sh").read_text()
    assert "glibc" in src.lower(), "install.sh debe manejar glibc"
    assert "ld-linux-aarch64.so.1" in src, "install.sh debe referenciar el loader glibc"


def test_launcher_exists_and_compiles():
    assert (ROOT / "launcher.c").exists(), "launcher.c debe existir"
    src = (ROOT / "launcher.c").read_text()
    assert "GLIBC_LOADER" in src, "launcher.c debe definir GLIBC_LOADER"
    assert "FREEBUFF" in src, "launcher.c debe ser para Freebuff"


def test_launcher_cleans_env():
    src = (ROOT / "launcher.c").read_text()
    assert 'unsetenv("LD_PRELOAD")' in src, "launcher.c debe limpiar LD_PRELOAD"
    assert 'unsetenv("LD_LIBRARY_PATH")' in src, "launcher.c debe limpiar LD_LIBRARY_PATH"


def test_installer_handles_mirror_and_cache():
    src = (ROOT / "install.sh").read_text()
    assert "CACHE_DIR" in src or "cache" in src.lower(), "install.sh debe manejar caché"
    assert "MIRROR" in src or "codebuff.com" in src, "install.sh debe manejar descarga directa"
