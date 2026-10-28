<div align="center">
<a href="https://inco.ai/blog/splash/">
  <img src=".github/App Icon.png" width="128" alt="App Icon" />
</a>

# 🌊 Splash Monitor

**[🇬🇧 English](README.md)** &nbsp;·&nbsp; **[🇪🇸 Español](.github/README.es.md)**

The first native macOS desktop app for [Inco AI's Splash][splash-article] local inference engine.

[![macOS](https://img.shields.io/badge/macOS%2026.4+-black?logo=apple&logoColor=F0F0F0)](#)
[![Apple Silicon](https://img.shields.io/badge/Silicon%20M3+-black?logo=apple&logoColor=F0F0F0)](#)
[![Swift](https://img.shields.io/badge/Swift%206.4-F54A2A?logo=swift&logoColor=white)](#)
[![MIT License](https://img.shields.io/badge/MIT%20License-FFFFFF)](#)

![Splash Monitor dashboard](screenshots/splash-monitor-dashboard.png)

</div>

### Why?

Until now, [Splash][splash-article] could only be operated from the command line. **Splash Monitor** transforms that experience into a complete visual suite for macOS: real-time metrics monitoring, one-click Hugging Face model management, and code agent launchers — all from a menu bar icon or a native desktop window.

### ✨ Key Features

- **Real-time token dashboard** — prefill and decode speeds in `tok/s` with sparkline charts, KV cache hit rate, DFlash 2 speculative acceptance rate, TTFT/ITL latency, and Apple Neural Engine acceleration ratio
- **Metal unified memory gauge** — live memory bar, automatic chip/GPU detection, macOS kernel memory-pressure alerts with on-demand flush
- **Model manager** — local catalog with disk footprint, live [Hugging Face](https://huggingface.co/incoai) / `mlx-community` / official **NVIDIA (NVFP4 / FP8)** explorer, real-time download telemetry, GGUF variants and gated-repository guidance
- **Server controls** — one-click start/stop, model hot-swapping, port and LAN bind options, advanced Splash flags, and one-click copy of the OpenAI-compatible endpoint
- **Code agent launchers** — Claude Code, Claude Cowork, OpenCode, Codex, Hermes, Pi Agent, and DeepSeek Harness
- **Connected clients** — recognizes the apps talking to the inference port (Claude Desktop, Cursor, VS Code, chatbots) with their native macOS icons
- **Native macOS experience** — menu bar extra with 4 display modes and 1-click memory flush

### 📥 Installation

**Prerequisite — the Splash engine.** Splash Monitor is a graphical monitor for [Inco AI's Splash][splash-repo] local inference engine. Install it first:

```bash
brew install incoai/tap/splash
```

**Splash Monitor.** Grab the latest version from the [GitHub Releases page](https://github.com/Lancelotbronner/splash-app/releases).

**Developers.** See [docs/building.md](docs/building.md) to build from source.

> ℹ️ **Disclaimer**: Splash Monitor is an independent project **not affiliated with, sponsored by, or endorsed by Inco AI**. "Splash" is a trademark of Inco AI.

[splash-article]: https://inco.ai/blog/splash/
[splash-repo]: https://github.com/incoai/splash
