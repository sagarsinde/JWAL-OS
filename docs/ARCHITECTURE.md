# JWAL OS — System Architecture Specification

## 1. Executive Architecture Summary

**JWAL OS** is an independent, lean Linux operating system engineered specifically for television displays (10-foot viewing distance). Unlike conventional Smart TV operating systems that wrap resource-heavy web frameworks or Android runtimes, JWAL OS uses a native, compiled stack designed for deterministic latency, zero telemetry, and rapid cold boot.

```
+-------------------------------------------------------------------------+
|                         JWAL TV SHELL (Flutter)                         |
|     Home • Search • Settings • Browser Launcher                         |
|     10-Foot Design • D-pad Focus Engine • Dark Theme / #FF6D00 Accent   |
+------------------------------------+------------------------------------+
                                     | Wayland Protocol
+------------------------------------v------------------------------------+
|                       CAGE COMPOSITOR (Wayland)                         |
|         Single-application kiosk compositor (wlroots-based)             |
+---+------------------------------------+---+----------------------------+
    |                                    |   |
    v  JSON IPC                          v   v  Wayland surfaces
+-----------------------+  +---------------------------+
|      MPV Engine       |  |  WPE WebKit + Cog         |
| Hardware Decode, Subs |  |  (Primary TV Browser)     |
| & Audio Stream Switch |  |  Spatial Nav, Ad Filter   |
+-----------------------+  +---------------------------+
                                                        +------------------+
                                                        | Chromium (Fallback|
                                                        | Kiosk mode)      |
                                                        +------------------+
+-------------------------------------------------------------------------+
|                         jwald (Core Rust Daemon)                        |
|  - Process Supervisor     - Settings & Session DB  - Search Aggregator  |
|  - Source Health Scorer   - Local Cache Manager    - OTA Coordinator    |
|  - DNS Ad/Tracker Filter  - CEC/IR/BT Input Bridge                      |
+-------------------+--------------------------------+--------------------+
                    |                                |
         JSON-RPC/stdio                  JSON-RPC/stdio (Isolated Subprocesses)
+-----------------------+           +-------------------------------------+
| libcec (HDMI-CEC)     |           |          Python Source Plugins      |
| lirc   (IR remotes)   |           |  - Internet Archive (Legal Core)    |
| bluez  (Bluetooth)    |           |  - M3U Playlists   (Legal Core)    |
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
  - `default`: Networking (`wpa_supplicant`, `dhcpcd`), `jwald` daemon, `cec-bridge` input service, and `cage` compositor launching the Flutter shell.
- **Autologin:** Automatic login on `tty1` running as unprivileged user `jwal`.

### 2.2 Display Server & Compositor
- **Protocol:** Pure Wayland. No legacy X11 components.
- **Compositor:** `cage` (a lightweight Wayland kiosk compositor built on `wlroots`).
- **Function:** Launches and constrains the JWAL TV Shell to fullscreen resolution (baseline 1080p, with 4K scaling where supported) without window decorations, desktop taskbars, or window management overhead.
- **Multi-surface:** `cage` manages the Flutter shell as primary surface and can overlay additional Wayland clients (MPV, WPE/Cog browser) as child surfaces controlled by the shell.

### 2.3 Shell UI (Flutter / flutter-elinux)
- **Framework:** Flutter compiled for embedded Linux (`flutter-elinux`) targeting Wayland.
- **Language:** Modern, null-safe Dart.
- **Design Language:**
  - **10-Foot Television UX:** High-contrast text, oversized card targets, generous padding, and clear visual hierarchy visible from 3–4 meters.
  - **Color System:** Deep neutral background (`#121212`), elevated surfaces (`#1E1E1E`), text high-contrast white (`#FFFFFF`), with signature flame accent (`#FF6D00`).
  - **Navigation:** Spatial D-pad input handling (Up, Down, Left, Right, Select/Enter, Back/Escape). Focus is explicitly indicated by scaling animations and bright outline borders.
- **IPC Interface:** Communicates directly with the `jwald` daemon over Unix domain sockets using standard JSON messages.
- **Browser Launcher:** Dedicated screen for launching the built-in web browser (WPE/Cog) with a URL bar, bookmarks, and history — all navigable by D-pad/remote.

### 2.4 Core Daemon (`jwald`)
- **Language & Runtime:** Rust, compiled statically against musl libc. Statically linked binary with zero external runtime dependencies and no garbage collection overhead.
- **Memory Footprint:** Budgeted at <15 MB RSS during steady-state operation.
- **Core Responsibilities:**
  1. **Plugin Supervisor:** Discovers, spawns, monitors, and terminates isolated plugin processes. Enforces process sandboxing, execution timeouts, and crash recovery.
  2. **Search Aggregator:** Dispatches search queries concurrently across registered sources with a strict timeout budget (8 seconds), deduplicating results and enriching metadata via a local TMDB cache.
  3. **Source Health Scorer:** Tracks source reliability, latency, HTTP success rates, and stream resolution health locally. This telemetry is stored strictly on device and never broadcast.
  4. **Settings & State Storage:** Manages local user configurations, watch history, playback checkpoints, and UI state using embedded SQLite.
  5. **OTA Manager:** Atomic, A/B partition OS updates and plugin updates verification.
  6. **DNS Ad/Tracker Filter:** Intercepts DNS queries and blocks known advertising, tracking, and malware domains using curated blocklists (StevenBlack/hosts, OISD). See §2.9.
  7. **CEC/IR/BT Input Bridge:** Translates HDMI-CEC, IR, and Bluetooth remote control signals into Linux `uinput` key events. See §2.8.

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

### 2.7 Web Browser Engine
The TV browser provides general web browsing from the living room, navigable entirely by remote control.

- **Primary Engine: WPE WebKit + Cog**
  - [WPE WebKit](https://wpewebkit.org/) is a WebKit port purpose-built for embedded and TV devices by Igalia.
  - **Cog** is WPE's official minimal browser shell — a single-window, no-chrome launcher for Wayland kiosk environments.
  - Memory footprint: ~50–80 MB (vs ~300–500 MB for full Chromium).
  - Native Wayland rendering via `wpe-backend-fdo`.
  - Hardware-accelerated video decode (DMABuf/V4L2) for YouTube and streaming sites.
  - Built-in spatial navigation support for D-pad/arrow key focus traversal.
  - User-script injection for content-level ad filtering (uBlock-style CSS/JS rules).

- **Fallback Engine: Chromium (Kiosk Mode)**
  - Available via `apk add chromium` on Alpine aarch64.
  - Launched with flags: `--kiosk --enable-spatial-navigation --no-first-run --disable-infobars`.
  - Used when sites explicitly require Chrome/Blink rendering (e.g., some Google services).
  - Higher memory cost — intended as user-selectable fallback, not the default.

- **Why Not Brave?**
  - Brave Browser requires glibc and does not provide musl/Alpine packages.
  - Brave's ARM64 Linux builds target only Debian/Ubuntu/Fedora.
  - Ad-blocking is handled at the OS level (DNS filter, §2.9) which is superior — invisible to anti-adblock detection scripts.

### 2.8 Input & Remote Control Subsystem
JWAL OS supports three remote control input methods, all translated to standard Linux `uinput` key events so the Flutter shell and browser receive them as ordinary keyboard input.

- **HDMI-CEC (Primary — Zero Extra Hardware)**
  - The Raspberry Pi 4 (and most TV boxes) have CEC hardware built into the HDMI port.
  - When connected via HDMI, the **TV's own remote** sends directional, select, back, play, pause, and volume commands through the HDMI cable.
  - `libcec` + `cec-client` receives CEC frames; `jwald`'s CEC bridge module translates them to `uinput` events.
  - Standard CEC button mapping:
    | CEC Button | Linux Key | Shell Action |
    |-----------|-----------|--------------|
    | Up / Down / Left / Right | `KEY_UP` / `KEY_DOWN` / `KEY_LEFT` / `KEY_RIGHT` | Spatial navigation |
    | Select / OK | `KEY_ENTER` | Activate focused element |
    | Exit / Back | `KEY_BACK` | Navigate back |
    | Play / Pause / Stop | `KEY_PLAY` / `KEY_PAUSE` / `KEY_STOP` | Media controls |
    | Volume +/- | `KEY_VOLUMEUP` / `KEY_VOLUMEDOWN` | Volume control |
    | Number 0–9 | `KEY_0` – `KEY_9` | Quick input |

- **IR (Infrared)**
  - Supported via `lirc` or the kernel `rc` subsystem (`ir-keytable`).
  - Requires a USB IR receiver (~$5) or board-integrated IR sensor.
  - Keymap files define the mapping from IR protocol codes to Linux key events.
  - Common protocols supported: NEC, RC5, RC6, Sony SIRC.

- **Bluetooth**
  - Supported via `bluez` (included in Alpine repos).
  - Raspberry Pi 4 has integrated Bluetooth 5.0.
  - Compatible with standard BT HID remotes (e.g., Amazon Fire TV Stick remote, generic Android TV remotes).
  - Pairing managed via a Flutter settings UI screen.

- **Browser Remote Navigation**
  - Arrow keys drive spatial navigation in WPE WebKit (native support) and Chromium (`--enable-spatial-navigation` flag).
  - Long-press OK/Select toggles a **virtual mouse cursor** mode where arrows move a pointer and OK clicks — for websites that require precise pointing.
  - On-screen keyboard appears automatically when a text field is focused.

### 2.9 DNS Ad/Tracker Filter
JWAL OS blocks advertising and tracking at the DNS level within `jwald`, providing system-wide protection across the browser, media player, and all network-connected components.

- **Mechanism:** `jwald` runs a lightweight DNS resolver that intercepts all outbound DNS queries from the device. Queries matching entries in the blocklist are resolved to `0.0.0.0` (sinkholed), preventing the connection entirely.
- **Blocklist Sources:**
  - [StevenBlack/hosts](https://github.com/StevenBlack/hosts) — unified hosts file with ad + malware domains.
  - [OISD Blocklist](https://oisd.nl/) — curated, false-positive-minimized ad/tracker list.
  - Lists are cached locally and updated periodically via OTA (daily, configurable).
- **Advantages Over Browser-Level Blocking:**
  1. **Invisible to websites:** No `navigator.brave` fingerprint, no detectable extension, no DOM modifications. Anti-adblock scripts cannot detect DNS-level blocking.
  2. **System-wide:** Protects not just the browser but also MPV (pre-roll ads in some streams), yt-dlp requests, and any plugin network activity.
  3. **Zero CPU overhead in browser:** No JavaScript content-script running per page — blocking happens before the TCP connection is established.
- **User Controls:** Whitelist specific domains via the Settings UI (e.g., if a legitimate site is accidentally blocked). Toggle the filter on/off globally.
- **Content-Level Filtering (Browser Only):** In addition to DNS blocking, WPE WebKit supports user-style and user-script injection for cosmetic filtering (hiding ad containers that loaded from non-blocked first-party domains). This is the equivalent of uBlock Origin's cosmetic filters.

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
5. **DNS Ad/Tracker Blocking:** All advertising, tracking, and known malware domains are blocked at the DNS level before any network connection is established. This filter is enabled by default and operates transparently with zero user configuration required.
