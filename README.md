# JWAL OS 🔥

**JWAL OS** ("*jwal*" = flame in Sanskrit) is an open-source, ultra-lightweight, privacy-first Linux television operating system designed from scratch for the 10-foot living room experience.

It is a **complete operating system**, not an app or an Android launcher. JWAL OS boots directly from bare metal or hypervisor into an uncompromising, lean TV interface built with Flutter, powered by Wayland (`cage`), managed by a lightweight Rust daemon (`jwald`), and driven by MPV for media playback.

---

## 🎯 Vision & Guiding Principles

- **True TV Operating System:** Boots directly into a fullscreen TV experience without mobile baggage, bloated runtime engines, or unwanted OEM layers.
- **Privacy First & Local-Only:** Zero telemetry, no analytics, no mandatory cloud accounts, and no remote surveillance. Your watch history, preferences, and data remain strictly local.
- **10-Foot Lean UI:** Tailored for comfortable couch viewing with remote-control D-pad navigation, smooth focus transitions, high-contrast dark theme, and an accent color of `#FF6D00`.
- **Modularity via Isolation:** Core OS remains minimal, auditable, and resilient. Plugins run out-of-process in supervised subprocesses.

---

## ⚖️ Legal Disclaimer: "Ships With Zero Sources"

> [!IMPORTANT]
> **JWAL OS core ships with ZERO stream sources, trackers, or scrapers.**
>
> The JWAL OS core repository is strictly a media playback engine and UI shell. Out of the box, JWAL OS provides integrations solely with public domain and freely distributable services:
> - **Internet Archive** (public domain cinema, archival broadcasts)
> - **User-provided M3U playlists**
> - **The Movie Database (TMDB)** (metadata and poster caching)
> - **YouTube** (via `yt-dlp` extraction)
>
> Third-party community source plugins run in isolated, sandboxed Python subprocesses over standard I/O (JSON-RPC) supervised by `jwald`. The JWAL OS project does not host, curate, promote, or distribute any proprietary or infringing media sources.

---

## 🏗️ Architecture Overview

JWAL OS is built upon a layered, clean UNIX architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    JWAL Shell (Flutter)                     │
│           1080p Baseline • D-Pad Engine • Dark/#FF6D00      │
└──────────────────────────────┬──────────────────────────────┘
                               │ Wayland
┌──────────────────────────────▼──────────────────────────────┐
│                   Cage Compositor / Wayland                 │
└──────────────────────────────┬──────────────────────────────┘
                               │ JSON IPC / Unix Sockets
┌──────────────────────────────▼──────────────────────────────┐
│                    jwald (Core Rust Daemon)                 │
│   Plugin Host • Source Health Engine • Settings • OTA       │
├──────────────────────────────┬──────────────────────────────┤
│    MPV Engine (Player)       │   Isolated Plugin Host       │
│  HW Decode • Subs • Audio    │  Python Subprocesses (Stdio) │
└──────────────────────────────┴──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                   Alpine Linux LTS (OpenRC)                 │
│              aarch64 (primary) • x86_64 (secondary)         │
└─────────────────────────────────────────────────────────────┘
```

| Layer | Technology | Role |
|---|---|---|
| **Base OS** | Linux LTS / Alpine Linux + OpenRC | Minimal footprint, deterministic init, fast boot |
| **Compositor** | Cage (Wayland) | Single-application kiosk compositor |
| **Shell UI** | Flutter (`flutter-elinux`) | 60 FPS 10-foot TV UI, null-safe Dart, D-pad navigation |
| **Core Daemon** | Rust (`jwald`) | Single static musl binary supervising plugins, search, health |
| **Media Player** | MPV | Hardware-accelerated decoding, subtitle & audio stream switching |
| **Stream Extraction** | `yt-dlp` | Resolves public video feeds without modifying external libraries |
| **Plugin Runtime** | Python (JSON-RPC over stdio) | Supervised subprocesses isolated from shell and daemon |

---

## 🗺️ Roadmap & Phases

- [x] **Phase 0: Project Init** — Repository structure, governance rules, architectural specs, and legal documentation.
- [ ] **Phase 1: Dev Factory** — WSL2 Ubuntu build toolchain, QEMU aarch64 harness, and Flutter-elinux verification.
- [ ] **Phase 2: Core OS** — Rootfs build scripts (`build-rootfs.sh`), OpenRC services, cage compositor autologin, and QEMU boot test.
- [ ] **Phase 3: Shell (Flutter TV UI)** — 10-foot navigation engine, focus management, dark/#FF6D00 design system, and TV cards.
- [ ] **Phase 4: Media Engine** — MPV integration, yt-dlp extraction, fullscreen playback, and position tracking.
- [ ] **Phase 5: Source Plugin System** — Python plugin runner, JSON-RPC protocol, and default legal plugins (Internet Archive, M3U).
- [ ] **Phase 6: Global Search & Health** — Parallel federated search, TMDB local cache, and local source health metrics.
- [ ] **Phase 7: Full TV Features** — Continue watching, local recommendation engine, audio/subtitle selectors, and on-screen keyboard.
- [ ] **Phase 8: Release & Packaging** — GPT/FAT32/ext4 bootable images (`.img`), CI build pipeline, and flashing guides.

---

## 💻 Development & Installation

### Host Requirements
- **Development Host:** Windows 10/11 with **WSL2 (Ubuntu 22.04 LTS or newer)** or native Linux.
- **Testing:** QEMU for aarch64 emulation (no physical hardware required for development).
- **Target Hardware (future):** Raspberry Pi 4 (aarch64), Amlogic S905X4 TV boxes, and x86_64 mini PCs.

### Getting Started (WSL2 / Linux)
```bash
# Clone the repository
git clone https://github.com/sagarsinde/JWAL-OS.git
cd JWAL-OS

# Inspect progress and project rules
cat PROGRESS.md
cat jwal-os-rules.md
```

Detailed toolchain installation and QEMU setup instructions will be provided in `docs/` and `scripts/env-setup.sh` as Phase 1 begins.

---

## 📄 License & Community

- **License:** GPLv3 (pending final owner confirmation at PH0-T5 to ensure compatibility with MPV and system libraries).
- **Contributing:** Contributions must follow the project rules in [`jwal-os-rules.md`](jwal-os-rules.md) and progress tracking in [`PROGRESS.md`](PROGRESS.md).
