# Regla de Documentación Bilingüe y Validación Continua

## 1. Documentación Siempre Bilingüe (Español 🇩🇴 / Inglés 🇬🇧)
- **Simetría Total**: Toda documentación técnica (`README.md`, `SECURITY.md`, `CHANGELOG.md`, notas de publicación / GitHub Releases) debe mantenerse estricta y simétricamente en ambos idiomas:
  - **Español Dominicano 🇩🇴**: Sección principal en español.
  - **Inglés 🇬🇧**: Sección equivalente en inglés (`## 🇬🇧 English`).
- **Atribuciones y Licencias**: Si se agrega, modifica o elimina un modelo, motor, acelerador especulativo o agente de código conectado en una tabla de licencias, debe actualizarse en ambas secciones simultáneamente.
- **Capturas y Referencias**: Asegurar que las referencias a imágenes, badges de versión y enlaces de descarga apunten a los mismos artefactos en ambas secciones.

## 2. Validación Obligatoria de Todos los Cambios
- **Pruebas Unitarias al 100%**: Ejecutar siempre `swift test` y verificar que el 100% de las pruebas pasen con 0 fallos antes de confirmar cualquier tarea.
- **Compilación en Release**: Ejecutar `./scripts/build_app.sh` para verificar que la aplicación compile limpiamente, se empaquete y firme correctamente en `Splash Monitor.app`.
- **Capturas de Pantalla Actualizadas**: Regenerar y verificar las capturas oficiales en `screenshots/` siempre que haya cambios visuales o de versión en la interfaz.
- **Empaquetado y Verificación de Integridad**: Si se crea o actualiza una release, generar el DMG con `./scripts/create_dmg.sh` y comprobar la suma `SHA256SUMS`.
- **Aprobación de Usuario**: Mostrar siempre un resumen claro de los cambios staged y esperar la aprobación explícita del usuario antes de realizar `git push`.
