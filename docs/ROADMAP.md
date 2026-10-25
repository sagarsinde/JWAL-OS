# JWAL OS — Project Roadmap & Delivery Plan

This roadmap outlines the phased development and verification schedule for **JWAL OS**. Every task is verified with runnable evidence before progression to ensure high software stability.

---

## Phase 0: Project Initialization & Governance (Current)
*Target: Clean repository foundation, design architecture, legal boundaries, and licensing.*

- **PH0-T1:** Repository initialization and remote configuration.
- **PH0-T2:** Progress tracking system (`PROGRESS.md`) and session ledger.
- **PH0-T3:** Master `README.md` containing vision, architecture, and legal disclaimer.
- **PH0-T4:** Technical documentation (`docs/ARCHITECTURE.md` and `docs/ROADMAP.md`).
- **PH0-T5:** Legal licensing (`LICENSE` under GPLv3) and `.gitignore` file.
- **PH0-T6:** Initial project commit and baseline tree verification.

---

## Phase 1: Developer Factory & Toolchain Setup
*Target: Fully reproducible local development environment under WSL2 Ubuntu with QEMU aarch64 emulation.*

- **PH1-T1:** Automated WSL2 environment provisioning script (`scripts/env-setup.sh`).
- **PH1-T2:** Package installation (`qemu-system-arm`, `build-essential`, `git`, Flutter SDK, `flutter-elinux`, `dart`).
- **PH1-T3:** Verification of QEMU booting an official Alpine aarch64 minimal kernel and initramfs.
- **PH1-T4:** Verification of `flutter-elinux` running a standalone Wayland window.
- **PH1-T5 (Spike D1):** Feasibility spike for Flutter engine running on musl libc (Alpine aarch64); determine if `gcompat` or Debian-slim base is required.

---

## Phase 2: Core Operating System (aarch64)
*Target: Minimal, functional Linux root filesystem booting in QEMU to an autologin Wayland session.*

- **PH2-T1:** Root filesystem generator (`scripts/build-rootfs.sh`) for aarch64 with OpenRC.
- **PH2-T2:** OpenRC service definition for `jwal-shell` (Wayland `cage` compositor launching shell).
- **PH2-T3:** Network daemon integration (`wpa_supplicant` for Wi-Fi and `dhcpcd` for wired Ethernet).
- **PH2-T4:** Automated QEMU integration test harness (`scripts/test-jwal.sh`) with serial logging and screen capture.
- **PH2-T5:** Smoke test verification of cold boot sequence in QEMU.
- **PH2-T6 (Metric D3):** Rootfs size budget verification (<300 MB for base image).

---

## Phase 3: TV Shell UI (Flutter / flutter-elinux)
*Target: 10-foot TV interface with D-pad navigation, dark/#FF6D00 styling, and TV card components.*

- **PH3-T1:** Flutter application scaffolding (`jwal-shell`) targeting embedded Linux.
- **PH3-T2:** Design system implementation (dark surface `#121212`, card `#1E1E1E`, flame `#FF6D00`, high-contrast focus rings).
- **PH3-T3:** Spatial D-pad navigation controller supporting remote control arrow keys, Enter, and Back.
- **PH3-T4:** TV Home dashboard: Global search bar, "Continue Watching", and categorized content shelves.
- **PH3-T5:** Reusable 10-foot TV card components with focus magnification and elevation shadows.
- **PH3-T6:** Settings interface for display, audio, network status, and plugin management.
- **PH3-T7:** QEMU screenshot verification demonstrating complete boot-to-UI cold start.

---

## Phase 4: Native Media Engine
*Target: Integrated MPV playback pipeline with hardware acceleration and yt-dlp stream extraction.*

- **PH4-T1 (Decision D2):** MPV installation, hardware acceleration configuration, and JSON IPC socket setup.
- **PH4-T2:** Dart MPV service client communicating over Unix domain sockets.
- **PH4-T3 (Decision D4):** `yt-dlp` stream extraction service integrated into `jwald`.
- **PH4-T4:** End-to-end integration: URL selection -> extraction -> MPV fullscreen playback.
- **PH4-T5:** Real-time playback position reporting (resuming playback for "Continue Watching").

---

## Phase 5: Isolated Source Plugin System
*Target: Supervised Python plugin runner over JSON-RPC stdio with standard legal plugins.*

- **PH5-T1 (Decision D5):** Plugin API specification: `manifest.json`, `search(query)`, and `resolve(item)`.
- **PH5-T2:** Isolated plugin process supervisor within `jwald` (subprocess lifecycle, memory limits, timeouts).
- **PH5-T3:** Standard Plugin #1: Internet Archive (public domain film and television catalog).
- **PH5-T4:** Standard Plugin #2: IPTV / M3U Playlist parser.
- **PH5-T5:** UI plugin management screen (enable, disable, status, error logging).
- **PH5-T6:** End-to-end verification: browse Internet Archive catalog -> select title -> stream in MPV.

---

## Phase 6: Global Federated Search & Health Engine
*Target: Concurrent search across sources with TMDB metadata caching and local health ranking.*

- **PH6-T1:** Parallel search dispatcher with strict 8-second timeout across active plugins.
- **PH6-T2:** Result deduplication (title + release year matching) with local TMDB metadata enrichment.
- **PH6-T3:** Local ranking algorithm factoring source latency, resolution, and availability score.
- **PH6-T4:** Search results UI featuring per-source badges and "Play Best Quality" smart action.
- **PH6-T5:** Local `SourceHealth` persistent database (tracking ping times, 4xx/5xx failures locally).
- **PH6-T6:** Source diagnostics and health breakdown interface.

---

## Phase 7: Complete Television OS Features
*Target: Production polish, user profiles, on-screen keyboard, and subtitle/audio selectors.*

- **PH7-T1:** Persistent watch history and dynamic "Continue Watching" shelf.
- **PH7-T2:** Offline, on-device recommendation engine based on local watch history.
- **PH7-T3:** In-player on-screen display (OSD) controls for multi-audio and subtitle selection.
- **PH7-T4:** TV-optimized on-screen virtual keyboard with D-pad navigation and autocomplete.
- **PH7-T5:** Multi-user profiles with pin-protected Kids Mode.
- **PH7-T6:** Ambient screensaver and idle display (current time, weather, and system diagnostics).

---

## Phase 8: System Image Assembly & First Release
*Target: Production-ready bootable disk images, automated GitHub CI build pipeline, and v0.1.0 release.*

- **PH8-T1:** Automated image packaging script (`scripts/assemble-image.sh`) generating GPT `.img` with FAT32 boot and ext4 root partitions.
- **PH8-T2:** Secondary `x86_64` image build and validation.
- **PH8-T3:** GitHub Actions workflow: automated matrix build, QEMU boot validation, and artifact generation.
- **PH8-T4:** Official `v0.1.0` release tag with verified SHA256 checksums and image downloads.
- **PH8-T5:** Comprehensive installation and SD card flashing documentation.
