#!/data/data/com.termux/files/usr/bin/bash
# freebuffT — forwarder (compatibilidad ex-proot)
export FREEBUFF_BINARY_TARGET="linux-arm64"
unset LD_LIBRARY_PATH
unset LD_PRELOAD
if [ -x "$PREFIX/bin/freebuff" ]; then
  exec "$PREFIX/bin/freebuff" "$@"
fi
CONFIG_BIN="$HOME/.config/manicode/freebuff"
GLIBC_LD="/data/data/com.termux/files/usr/glibc/lib/ld-linux-aarch64.so.1"
if [ -f "$CONFIG_BIN" ]; then
  exec "$GLIBC_LD" "$CONFIG_BIN" "$@"
fi
echo "freebuff no encontrado. Ejecuta: bash $HOME/storage/proyectos/freebuffT/install.sh" >&2
exit 1
