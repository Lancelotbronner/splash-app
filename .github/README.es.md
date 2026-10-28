<div align="center">
<a href="https://inco.ai/blog/splash/">
  <img src=".github/App Icon.png" width="128" alt="App Icon" />
</a>

# 🌊 Splash Monitor

**[🇬🇧 English](README.md)** &nbsp;·&nbsp; **[🇪🇸 Español](.github/README.es.md)**

La primera app de escritorio nativa de macOS para el motor de inferencia local [Splash de Inco AI][splash-article].

[![macOS](https://img.shields.io/badge/macOS%2026.4+-black?logo=apple&logoColor=F0F0F0)](#)
[![Apple Silicon](https://img.shields.io/badge/Silicon%20M3+-black?logo=apple&logoColor=F0F0F0)](#)
[![Swift](https://img.shields.io/badge/Swift%206.4-F54A2A?logo=swift&logoColor=white)](#)
[![MIT License](https://img.shields.io/badge/MIT%20License-FFFFFF)](#)

![Splash Monitor dashboard](screenshots/splash-monitor-dashboard.png)

</div>

### ¿Por qué?

Hasta ahora, [Splash][splash-article] solo podía operarse desde la línea de comandos. **Splash Monitor** transforma esa experiencia en una suite visual completa para macOS: monitoreo de métricas en tiempo real, gestión de modelos de Hugging Face con un solo clic, y lanzadores de agentes de código — todo desde un ícono en la barra de menú o una ventana de escritorio nativa.

### ✨ Características Principales

- **Panel de métricas en tiempo real** — velocidades de prefill y decode en `tok/s` con gráficas sparkline, tasa de acierto del KV cache, tasa de aceptación especulativa DFlash 2, latencias TTFT/ITL y ratio de aceleración por Apple Neural Engine
- **Monitor de memoria unificada Metal** — barra de memoria en tiempo real, detección automática del chip/GPU, alertas de presión de memoria del kernel de macOS con purga bajo demanda
- **Gestor de modelos** — catálogo local con espacio en disco, explorador en vivo de [Hugging Face](https://huggingface.co/incoai) / `mlx-community` / oficiales de **NVIDIA (NVFP4 / FP8)**, telemetría de descargas en tiempo real, variantes GGUF y guía para repositorios protegidos
- **Control del servidor** — inicio/parada con un clic, cambio de modelo en caliente, opciones de puerto y red LAN, flags avanzados de Splash y copia en un clic del endpoint compatible con OpenAI
- **Lanzadores de agentes de código** — Claude Code, Claude Cowork, OpenCode, Codex, Hermes, Pi Agent y DeepSeek Harness
- **Clientes conectados** — reconoce las apps que se comunican con el puerto de inferencia (Claude Desktop, Cursor, VS Code, chatbots) con sus íconos nativos de macOS
- **Experiencia nativa de macOS** — menú de barra con 4 modos de visualización y purga de memoria en 1 clic

### 📥 Instalación

**Requisito previo — el motor Splash.** Splash Monitor es un monitor gráfico para el motor de inferencia local [Splash de Inco AI][splash-repo]. Instálalo primero:

```bash
brew install incoai/tap/splash
```

**Splash Monitor.** Descarga la última versión desde la [página de Releases de GitHub](https://github.com/Lancelotbronner/splash-app/releases).

**Desarrolladores.** Consulta [docs/building.md](docs/building.md) para compilar desde el código fuente.

> ℹ️ **Descargo de responsabilidad**: Splash Monitor es un proyecto independiente **sin afiliación, patrocinio ni respaldo de Inco AI**. "Splash" es una marca comercial de Inco AI.

[splash-article]: https://inco.ai/blog/splash/
[splash-repo]: https://github.com/incoai/splash
