# Contribuyendo a Freebuff para Termux

Gracias por querer contribuir. Este proyecto es open source (MIT) y su objetivo
es instalar Freebuff de forma nativa en Termux para Android ARM64.

## Formas de contribuir

- **Reportar bugs**: abre un issue describiendo el problema, tu dispositivo
  (SoC, RAM, version de Termux) y los pasos para reproducirlo.
- **Sugerir mejoras**: issues o PRs con propuestas claras.
- **Traducir**: la landing (`docs/lang/`) y el contenido del README.
- **Mantener el espejo**: cuando el paquete npm publique una version nueva,
  ejecuta `bash scripts/mirror.sh` para actualizar el espejo y `versions.json`.
- **Escribir codigo**: sigue las convenciones del proyecto.

## Flujo de trabajo

1. Haz fork y crea una rama: `git checkout -b feat/mi-mejora`.
2. Haz cambios pequenos y enfocados.
3. Verifica que todo pase (mismo conjunto que el CI de `.github/workflows/ci.yml`):
   ```bash
   bash -n install.sh scripts/mirror.sh
   for f in docs/lang/*.js; do node --check "$f"; done
   python3 -m pytest tests/ -q
   ```
4. Envia el PR describiendo que hace y como probarlo.

## Tests

- Los tests viven en `tests/` y cubren la validez de `versions.json`
  (sha256 hex, urls https), la completitud de claves i18n y que el instalador
  use `set -e` y descargas solo HTTPS.

## Convenciones

- Sin comentarios en el codigo salvo que aporten valor.
- Shebangs de Termux: `#!/data/data/com.termux/files/usr/bin/bash`.
- El launcher C se compila en la instalacion (`cc -O2 -DPREFIX=...`).
- `versions.json` es la unica fuente de verdad del pin de version + SHA256.
- Commits estilo Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`.
- Finales de linea LF (no CRLF).
- El autor de los commits: `Sebastian Laguna <sebasbele11@gmail.com>`.

## Reportes de seguridad

Lee `SECURITY.md`. Para vulnerabilidades, NO abras un issue publico;
contacta a los mantenedores en privado.
