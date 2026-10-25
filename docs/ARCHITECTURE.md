# JWAL OS — System Architecture Specification

## 1. Executive Architecture Summary

**JWAL OS** is an independent, lean Linux operating system engineered specifically for television displays (10-foot viewing distance). Unlike conventional Smart TV operating systems that wrap resource-heavy web frameworks or Android runtimes, JWAL OS uses a native, compiled stack designed for deterministic latency, zero telemetry, and rapid cold boot.

```
+-------------------------------------------------------------------------+
|                         JWAL TV SHELL (Flutter)                         |
|     10-Foot Design • D-pad Focus Engine • Dark Theme / #FF6D00 Accent   |
+------------------------------------+------------------------------------+
                                     | Wayland Protocol
+------------------------------------v------------------------------------+
|                       CAGE COMPOSITOR (Wayland)                         |
|         Single-application kiosk compositor (wlroots-based)             |
+------------------------------------+------------------------------------+
                                     | Unix Domain Sockets / JSON-RPC
+------------------------------------v------------------------------------+
|                         jwald (Core Rust Daemon)                        |
|  - Process Supervisor     - Settings & Session DB  - Search Aggregator  |
|  - Source Health Scorer   - Local Cache Manager    - OTA Coordinator    |
+-------------------+--------------------------------+--------------------+
                    |                                |
         JSON IPC   v                 JSON-RPC/stdio v (Isolated Subprocesses)
+-----------------------+           +-------------------------------------+
|      MPV Engine       |           |          Python Source Plugins      |
| Hardware Decode, Subs |           |  - Internet Archive (Legal Core)    |
| & Audio Stream Switch |           |  - M3U Playlists   (Legal Core)    |
+-----------------------+           |  - Community Extensions (External)  |
                                    +-------------------------------------+
+-------------------------------------------------------------------------+
|                        ALPINE LINUX LTS (OpenRC)                        |
|        Linux Kernel LTS • aarch64 (Primary) / x86_64 (Secondary)        |
+-------------------------------------------------------------------------+
```

---

## 2. Core Subsystems

### 2.1 Operating System Base & Init
- **Distribution Base:** Alpine Linux LTS with OpenRC init. Selected for minimal rootfs footprint (<300 MB base budget), high security, and fast deterministic service initialization.
- **Architecture Priority:**
  1. `aarch64` (Primary target: ARM single-board computers, TV boxes, QEMU aarch64 virtualized development).
  2. `x86_64` (Secondary target: x86 mini PCs, development workstations).
- **Service Management:** Supervised via OpenRC runlevels:
  - `boot`: Core kernel modules, file systems, device nodes (`udev`/`mdev`).
  - `default`: Networking (`wpa_supplicant`, `dhcpcd`), `jwald` daemon, and `cage` compositor launching the Flutter shell.
- **Autologin:** Automatic login on `tty1` running as unprivileged user `jwal`.

### 2.2 Display Server & Compositor
- **Protocol:** Pure Wayland. No legacy X11 components.
- **Compositor:** `cage` (a lightweight Wayland kiosk compositor built on `wlroots`).
- **Function:** Launches and constrains the JWAL TV Shell to fullscreen resolution (baseline 1080p, with 4K scaling where supported) without window decorations, desktop taskbars, or window management overhead.

### 2.3 Shell UI (Flutter / flutter-elinux)
- **Framework:** Flutter compiled for embedded Linux (`flutter-elinux`) targeting Wayland.
- **Language:** Modern, null-safe Dart.
- **Design Language:**
  - **10-Foot Television UX:** High-contrast text, oversized card targets, generous padding, and clear visual hierarchy visible from 3–4 meters.
  - **Color System:** Deep neutral background (`#121212`), elevated surfaces (`#1E1E1E`), text high-contrast white (`#FFFFFF`), with signature flame accent (`#FF6D00`).
  - **Navigation:** Spatial D-pad input handling (Up, Down, Left, Right, Select/Enter, Back/Escape). Focus is explicitly indicated by scaling animations and bright outline borders.
- **IPC Interface:** Communicates directly with the `jwald` daemon over Unix domain sockets using standard JSON messages.

### 2.4 Core Daemon (`jwald`)
- **Language & Runtime:** Rust, compiled statically against musl libc. Statically linked binary with zero external runtime dependencies and no garbage collection overhead.
- **Memory Footprint:** Budgeted at <15 MB RSS during steady-state operation.
- **Core Responsibilities:**
  1. **Plugin Supervisor:** Discovers, spawns, monitors, and terminates isolated plugin processes. Enforces process sandboxing, execution timeouts, and crash recovery.
  2. **Search Aggregator:** Dispatches search queries concurrently across registered sources with a strict timeout budget (8 seconds), deduplicating results and enriching metadata via a local TMDB cache.
  3. **Source Health Scorer:** Tracks source reliability, latency, HTTP success rates, and stream resolution health locally. This telemetry is stored strictly on device and never broadcast.
  4. **Settings & State Storage:** Manages local user configurations, watch history, playback checkpoints, and UI state using embedded SQLite.
  5. **OTA Manager:** Atomic, A/B partition OS updates and plugin updates verification.

### 2.5 Media Playback Engine (MPV)
- **Integration:** MPV executed and controlled via Unix Domain Socket IPC (JSON-RPC) or embedded via Wayland surface.
- **Capabilities:**
  - Hardware-accelerated video decoding (V4L2 M2M, VAAPI).
  - Multi-track audio switching (passthrough AC3, DTS, AAC).
  - Subtitle track extraction, formatting, and real-time synchronization.
  - Accurate playback position reporting (at 1-second intervals) back to `jwald` for the "Continue Watching" pipeline.

### 2.6 Stream Extraction (`yt-dlp`)
- Stream URLs requiring extraction are processed through `yt-dlp`.
- `yt-dlp` is treated as an immutable system dependency invoked externally; it is never forked, monkey-patched, or modified.
- Extraction execution is coordinated inside `jwald` to isolate heavy Python/network workloads from the Flutter UI thread.

---

## 3. Plugin Architecture & Legal Isolation

### 3.1 Zero-Source Core Doctrine
The JWAL OS core distribution deliberately includes **ZERO built-in scrapers, commercial streams, or unauthorized media sources**.
The core codebase ships only with:
1. Public domain archives (e.g., Internet Archive API).
2. User-provided IPTV playlists (standard M3U/M3U8).
3. Free public metadata providers (TMDB API for posters/synopses).
4. Public YouTube video extraction via `yt-dlp`.

### 3.2 Process Isolation Model
```
+-----------------------------------------------------------+
|                 jwald (Rust Core Daemon)                  |
+-----------------------------+-----------------------------+
                              | Stdio Pipe (JSON-RPC 2.0)
+-----------------------------v-----------------------------+
|                Supervised Python Subprocess               |
|  +-----------------------------------------------------+  |
|  |                 Plugin Interface SDK                |  |
|  |   manifest.json  •  search()  •  resolve()          |  |
|  +-----------------------------------------------------+  |
+-----------------------------------------------------------+
```
- Each plugin executes in its own unprivileged Python subprocess.
- Communication with `jwald` occurs exclusively over standard input/output using JSON-RPC 2.0.
- Plugins are strictly isolated from the Flutter shell memory space. A malformed response, memory leak, or crash in a plugin process cannot destabilize the system or cause UI freezes.
- Strict CPU and memory limits are enforced via Linux cgroups.

---

## 4. Privacy & Security Model

1. **Local-First Architecture:** All watch history, custom source lists, search history, and settings are stored locally in an on-device SQLite database.
2. **Zero Telemetry:** JWAL OS contains no analytical beacons, crash telemetry pings, remote usage trackers, or third-party ads.
3. **No Mandatory Accounts:** The system is fully operational immediately upon first boot without an email address, login credential, or cloud handshake.
4. **Read-Only System Partition:** The base OS root filesystem is mounted read-only during normal operation. User data, plugins, and cache reside on a dedicated persistent `/data` ext4 partition.
