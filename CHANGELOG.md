# Changelog

Todos los cambios notables de este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto adhiere al [Versionado Semántico](https://semver.org/lang/es/).

## [2.0.0] - 2026-08-20

### Cambiado
- Migración completa de `proot-distro Ubuntu` a **glibc nativo** con loader explícito
- Nuevo `launcher.c` nativo Android (Bionic) que evita SIGSEGV y limpia LD_PRELOAD/LD_LIBRARY_PATH
- `install.sh` profesional v2.0.0 con instalación multi-fuente (npm → directo → caché), verificación de integridad y caja de diálogo interactiva
- Descarga directa desde `codebuff.com` en vez de depender solo de npm
- Wrapper `$PREFIX/bin/freebuff` ahora es binario compilado, no script bash frágil

### Corregido
- **Symlink overwrite**: `cat > $PREFIX/bin/freebuff` ya no destruye `index.js`
- **Quoting**: rutas con espacios y `'` ya no rompen el wrapper
- **LD_LIBRARY_PATH global**: ya no rompe `file`/`grep`/`node` (ahora sin export global)
- **SIGSEGV Node→ELF**: launcher nativo evita el crash cuando Node es padre en Android
- **invalid ELF header**: limpieza de `LD_LIBRARY_PATH` que contenía `libc.so` script

## [1.0.0] - 2026-08-17

### Añadido
- Instalador inicial con `proot-distro Ubuntu` + `FREEBUFF_BINARY_TARGET=linux-arm64`
- Wrapper `freebuff` via `proot-distro login ubuntu`
- `run_freebuff.sh` como forwarder
- `README.md` y `package.json` iniciales

