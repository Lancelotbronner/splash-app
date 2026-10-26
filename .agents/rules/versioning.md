# Regla de Versionado — SplashMonitor

## Esquema: SemVer `MAJOR.MINOR.PATCH-beta`

| Número | Cuándo sube | Ejemplos |
|---|---|---|
| **PATCH** `1.0.X` | Fixes, nuevos modelos, mejoras en UI existente, compatibilidad Splash | Agregar Ornith/Flint, Menu Bar Mode, fix de bug |
| **MINOR** `1.X.0` | Feature nueva significativa (pantalla nueva, integración nueva) | Nueva sección completa, sistema de perfiles |
| **MAJOR** `X.0.0` | Cambio radical, incompatibilidad hacia atrás | Reescritura de arquitectura |

## Reglas de release

1. **No crear release por cada commit** — acumular 2-4 mejoras antes de un bump.
2. **Toda release requiere**: bump en `Version.swift` → build release → DMG → tag git → `gh release create`.
3. La versión vive **únicamente** en `Sources/SplashMonitor/Services/Version.swift` (`SplashVersion.current`). No editar en ningún otro lugar.
4. El `buildNumber` sube en cada release (entero, correlativo).
5. Mientras la app sea beta, usar sufijo `-beta`. Cuando salga estable, eliminarlo.
