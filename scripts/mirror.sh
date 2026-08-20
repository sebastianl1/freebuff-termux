#!/data/data/com.termux/files/usr/bin/bash
#
# mirror.sh - Sincroniza la copia de seguridad del binario de Freebuff
#
# Descarga el binario linux-arm64 desde el registry npm (freebuff)
# o desde codebuff.com, lo verifica y lo sube como release asset a este
# mismo repositorio (sebastianl1/freebuff-termux), de modo que si npm
# falla o desaparece, el instalador sigue funcionando con el mirror.
#
# Uso:
#   bash scripts/mirror.sh              Sincroniza con la última versión de npm
#   bash scripts/mirror.sh 0.0.152      Sincroniza una versión concreta
#
# Requisitos: gh autenticado, curl, tar, sha256sum.

set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO="sebastianl1/freebuff-termux"
NPM_PKG="freebuff"
ASSET="freebuff-linux-arm64.tar.gz"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cd "$DIR"

# 1. Determinar versión
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "==> Consultando última versión en npm..."
    VERSION=$(curl -fsSL "https://registry.npmjs.org/${NPM_PKG}/latest" \
        | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4)
fi
[ -n "$VERSION" ] || { echo "ERROR: no se pudo determinar la versión."; exit 1; }
echo "    Versión: $VERSION"

TARBALL="$WORK/$ASSET"

# 2. Descargar desde codebuff.com (fuente primaria real)
echo "==> Descargando freebuff@${VERSION} desde codebuff.com..."
CODEBUFF_URL="https://codebuff.com/api/releases/download/${VERSION}/freebuff-linux-arm64.tar.gz"
if curl -fsSL --proto =https -o "$TARBALL" "$CODEBUFF_URL"; then
    echo "    Descargado desde codebuff.com"
else
    echo "    Falló codebuff.com, intentando npm..."
    TARBALL_URL=$(curl -fsSL "https://registry.npmjs.org/${NPM_PKG}/${VERSION}" \
        | grep -o '"tarball":"[^"]*"' | cut -d'"' -f4)
    [ -n "$TARBALL_URL" ] || { echo "ERROR: no se encontró el tarball en npm."; exit 1; }
    curl -fsSL --proto =https "$TARBALL_URL" -o "$TARBALL"
fi

# 3. Verificar integridad
echo "==> Verificando integridad..."
gzip -t "$TARBALL" || { echo "ERROR: gzip corrupto."; exit 1; }
[ "$(head -c 2 "$TARBALL" | od -An -tx1 | tr -d ' \n')" = "1f8b" ] || { echo "ERROR: no es gzip."; exit 1; }

mkdir -p "$WORK/out"
tar -xzf "$TARBALL" -C "$WORK/out"
# Buscar binario freebuff dentro del tarball
BIN_PATH=$(find "$WORK/out" -name "freebuff" -type f | head -1)
if [ -z "$BIN_PATH" ]; then
    BIN_PATH=$(find "$WORK" -name "freebuff" -type f | head -1)
fi
[ -n "$BIN_PATH" ] || { echo "ERROR: no se encontró binario freebuff en el tarball."; exit 1; }
[ "$(head -c 4 "$BIN_PATH" | od -An -tx1 | tr -d ' \n')" = "7f454c46" ] || { echo "ERROR: freebuff no es un binario ELF."; exit 1; }
SIZE=$(wc -c < "$BIN_PATH")
[ "$SIZE" -ge 100000000 ] || { echo "ERROR: freebuff demasiado pequeño ($SIZE bytes)."; exit 1; }
file "$BIN_PATH" | grep -qi 'aarch64' || { echo "ERROR: freebuff no es aarch64."; exit 1; }

# Repack como tarball plano (freebuff + tree-sitter.wasm si existe)
echo "==> Empaquetando binario plano..."
if [ -f "$WORK/out/tree-sitter.wasm" ]; then
    tar -czf "$WORK/flat.tar.gz" -C "$WORK/out" freebuff tree-sitter.wasm
else
    tar -czf "$WORK/flat.tar.gz" -C "$(dirname "$BIN_PATH")" "$(basename "$BIN_PATH")"
fi
mv "$WORK/flat.tar.gz" "$TARBALL"

SHA=$(sha256sum "$TARBALL" | awk '{print $1}')
echo "    SHA256: $SHA"

# 4. Subir al release del propio repo
TAG="freebuff-${VERSION}"
echo "==> Subiendo a ${REPO}:${TAG}..."
if ! gh release view "$TAG" -R "$REPO" &>/dev/null; then
    gh release create "$TAG" -R "$REPO" \
        --title "Freebuff binary mirror $VERSION" \
        --notes "Copia de seguridad del binario de freebuff $VERSION. SHA256: $SHA"
fi
gh release upload "$TAG" -R "$REPO" "$TARBALL" --clobber

# 5. Actualizar versions.json
echo "==> Actualizando versions.json..."
cat > "$DIR/versions.json" <<EOF
{
  "version": "$VERSION",
  "sha256": "$SHA",
  "urls": [
    "https://registry.npmjs.org/freebuff/-/freebuff-${VERSION}.tgz",
    "https://codebuff.com/api/releases/download/${VERSION}/freebuff-linux-arm64.tar.gz",
    "https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"
  ]
}
EOF

echo ""
echo "✔ Mirror sincronizado: $VERSION ($SHA)"
echo "  No olvides commitear y pushear versions.json si cambió:"
echo "    git add versions.json && git commit -m \"mirror: actualizar a $VERSION\" && git push"
