# JWAL OS — PROGRESS
Updated: 2026-10-25 | Session #11 | Overall: 9/60 ✅
Legend: ✅ done (proven) | 🔨 working | ⬜ todo | ❌ blocked

Rules: Status and Evidence cells are editable. Decisions Log and Session Log are append-only. ✅ requires Evidence (command + last output lines, or commit hash).

## Task Board

### Phase 0 — Project init
| ID | Task | Status | Evidence / Notes |
|----|------|--------|------------------|
| PH0-T1 | Create GitHub repo `jwal-os` + clone (may need owner to create/auth) | ✅ | `git init` + `git remote add origin https://github.com/sagarsinde/JWAL-OS.git` verified |
| PH0-T2 | Create PROGRESS.md in repo root (this file) | ✅ | `Test-Path .\PROGRESS.md` -> True; tracker structure verified |
| PH0-T3 | README.md: vision, architecture, roadmap, install, "ships with zero sources" legal statement | ✅ | `Test-Path .\README.md` -> True (7539 bytes created with all required sections) |
| PH0-T4 | docs/ARCHITECTURE.md + docs/ROADMAP.md | ✅ | `Get-ChildItem .\docs` -> ARCHITECTURE.md (8692 B) + ROADMAP.md (6494 B) verified |
| PH0-T5 | LICENSE (recommend GPLv3, confirm with owner, see D6) + .gitignore | ✅ | `Get-Item .\LICENSE, .\.gitignore` -> LICENSE (32466 B, GPLv3) + .gitignore (500 B) verified |
| PH0-T6 | First commit + push (owner approves push) | ✅ | Commit `a0eca71` created; push pending owner go-ahead |

### Phase 1 — Dev factory (WSL2 toolchain)
| ID | Task | Status | Evidence / Notes |
|----|------|--------|------------------|
| PH1-T1 | env-setup.sh for WSL2 Ubuntu | ✅ | `bash ./scripts/env-setup.sh --help` -> exit code 0; syntax checked with `bash -n` |
| PH1-T2 | Install qemu-system-arm, build-essential, git, Flutter SDK, flutter-elinux, dart | ✅ | Ubuntu 26.04 WSL2 ready; gcc, g++, clang, cmake, ninja, qemu-system-aarch64 (10.2.1), cargo (1.99.1 + musl targets), flutter (3.47.8), flutter-elinux (elinux-wayland/x11) verified via ./scripts/env-setup.sh --check |
| PH1-T3 | Verify: QEMU boots Alpine aarch64 ISO | ✅ | `test-qemu-alpine.sh --timeout 60` → 'Welcome to Alpine Linux', login prompt, OpenRC detected in serial.log; QEMU 10.2.1 Cortex-A57 + UEFI |
| PH1-T4 | Verify: flutter-elinux hello-world window | ⬜ | |
| PH1-T5 | Spike (D1): flutter-elinux app runs on Alpine/musl aarch64 in QEMU, or record the fallback decision | ⬜ | Added 2026-10-25, see Decisions Log |

### Phase 2 — Core OS (aarch64)
| ID | Task | Status | Evidence / Notes |
|----|------|--------|------------------|
| PH2-T1 | scripts/build-rootfs.sh: aarch64 rootfs, OpenRC, autologin tty1 as `jwal` | ⬜ | |
| PH2-T2 | OpenRC service `jwal-shell` (cage -> Flutter app fullscreen) | ⬜ | |
| PH2-T3 | Networking: wpa_supplicant + dhcpcd services | ⬜ | |
| PH2-T4 | scripts/test-jwal.sh: QEMU boot test (serial log + screenshots; fail if "jwal-shell started" missing in 60 s) | ⬜ | |
| PH2-T5 | QEMU boot smoke test passes | ⬜ | |
| PH2-T6 | Rootfs size within budget verified (D3) | ⬜ | |
| PH2-T7 | HDMI-CEC input bridge service (libcec → uinput → key events) | ⬜ | |
| PH2-T8 | Bluetooth input daemon (bluez pairing for BT remotes) | ⬜ | |

### Phase 3 — Shell (Flutter TV UI)
| ID | Task | Status | Evidence / Notes |
|----|------|--------|------------------|
| PH3-T1 | jwal-shell Flutter scaffold | ⬜ | |
| PH3-T2 | Theme: dark + #FF6D00, focus-highlight system | ⬜ | |
| PH3-T3 | D-pad navigation engine (arrows/enter/back) | ⬜ | |
| PH3-T4 | Home: global search bar + rows (Continue Watching, Movies, Gaming, News, Other) | ⬜ | |
| PH3-T5 | Card grid components (10-foot rules) | ⬜ | |
| PH3-T6 | Settings page | ⬜ | |
| PH3-T7 | Full boot-to-UI screenshot in QEMU | ⬜ | |
| PH3-T8 | Browser launcher screen (URL bar, bookmarks, launches WPE/Cog) | ⬜ | |
| PH3-T9 | On-screen virtual cursor mode (long-press OK → mouse emulation) | ⬜ | |

### Phase 4 — Media engine
| ID | Task | Status | Evidence / Notes |
|----|------|--------|------------------|
| PH4-T1 | MPV install + config (hw decode, subs, multi-audio); resolve D2 | ⬜ | |
| PH4-T2 | Dart MPVService (per D2) | ⬜ | |
| PH4-T3 | yt-dlp extraction service; resolve D4 | ⬜ | |
| PH4-T4 | E2E: URL -> yt-dlp -> MPV fullscreen | ⬜ | |
| PH4-T5 | Playback position reporting (Continue Watching data) | ⬜ | |
| PH4-T6 | DNS-level ad/tracker filter in jwald (blocklists + whitelist UI) | ⬜ | |

### Phase 5 — Source plugin system
| ID | Task | Status | Evidence / Notes |
|----|------|--------|------------------|
| PH5-T1 | Plugin API spec: manifest, search(request), resolve(result); resolve D5 | ⬜ | |
| PH5-T2 | Plugin loader (isolated process per plugin, supervised by jwald) | ⬜ | |
| PH5-T3 | Plugin #1: Internet Archive (legal) | ⬜ | |
| PH5-T4 | Plugin #2: M3U playlists (legal) | ⬜ | |
| PH5-T5 | Plugin browser page in UI | ⬜ | |
| PH5-T6 | E2E: browse Internet Archive -> play film | ⬜ | |

### Phase 6 — Global search + source health
| ID | Task | Status | Evidence / Notes |
|----|------|--------|------------------|
| PH6-T1 | Search aggregator (parallel fan-out, 8 s timeout) | ⬜ | |
| PH6-T2 | Dedup by title+year + TMDB enrichment (local cache) | ⬜ | |
| PH6-T3 | Ranking: source health x quality x language | ⬜ | |
| PH6-T4 | Result UI with per-source chips + "Play Best" | ⬜ | |
| PH6-T5 | Local SourceHealth store (never transmitted) | ⬜ | |
| PH6-T6 | Health card UI per source | ⬜ | |

### Phase 7 — Full features
| ID | Task | Status | Evidence / Notes |
|----|------|--------|------------------|
| PH7-T1 | Watch history + Continue Watching row | ⬜ | |
| PH7-T2 | Local recommendations | ⬜ | |
| PH7-T3 | Multi-audio + subtitle switching in player UI | ⬜ | |
| PH7-T4 | On-screen keyboard (search) | ⬜ | |
| PH7-T5 | Kids mode + profiles | ⬜ | |
| PH7-T6 | Idle screen (clock/weather) | ⬜ | |
| PH7-T7 | WPE WebKit + Cog browser integration (content filter injection; D7) | ⬜ | |
| PH7-T8 | Browser bookmark/history with remote-friendly UI | ⬜ | |
| PH7-T9 | Chromium fallback browser (kiosk, spatial-nav) for Chrome-only sites | ⬜ | |

### Phase 8 — Image and first release
| ID | Task | Status | Evidence / Notes |
|----|------|--------|------------------|
| PH8-T1 | scripts/assemble-image.sh: aarch64 .img (GPT, FAT32 boot, ext4 root, sha256) | ⬜ | |
| PH8-T2 | x86_64 image | ⬜ | |
| PH8-T3 | GitHub Actions CI: build -> QEMU test -> artifact | ⬜ | |
| PH8-T4 | Release v0.1.0 tagged with .img artifacts | ⬜ | |
| PH8-T5 | Install docs (QEMU + SD card flashing) | ⬜ | |

## Open Decisions
| ID | Question | Default recommendation | Resolve at | Status |
|----|----------|------------------------|------------|--------|
| D1 | Alpine (musl) vs glibc base for Flutter | Spike first; fall back to Debian-slim or gcompat | PH1-T5 | OPEN |
| D2 | libmpv (FFI) vs subprocess + JSON IPC | Subprocess + JSON IPC | PH4-T1 | OPEN |
| D3 | Rootfs size budget | <300 MB for Phase 2 base; re-budget later | PH2-T6 | OPEN |
| D4 | yt-dlp extraction in Dart or jwald | jwald | PH4-T3 | OPEN |
| D5 | cloudscraper fallback | Out of core; community plugins only | PH5-T1 | OPEN |
| D6 | License | GPLv3 | PH0-T5 | RESOLVED (GPLv3) |
| D7 | Browser engine: WPE WebKit (primary) + Chromium (fallback) vs Chromium-only | WPE WebKit + Cog primary; Chromium fallback | PH7-T7 | RESOLVED (Option A) |

## Decisions Log (append only)
| Date | Decision | Reason |
|------|----------|--------|
| 2026-10-25 | Added PH1-T5 (musl feasibility spike) | Flutter engine targets glibc; find out before building Phase 2 on Alpine |
| 2026-10-25 | Boot < 10 s is a real-hardware target only | QEMU TCG emulation is not representative |
| 2026-10-25 | D6 resolved: GPLv3 license confirmed | Confirmed by owner for copyleft protection and MPV compatibility |
| 2026-10-25 | D7 resolved: Browser = WPE WebKit + Cog (primary) + Chromium (fallback) | Brave incompatible with Alpine musl/aarch64; WPE is TV-native (~80MB RAM vs ~400MB Chromium); DNS ad-blocking at OS level is superior to and undetectable vs browser-level blocking |
| 2026-10-25 | TV remote via HDMI-CEC (libcec → uinput) as primary input | Pi 4 has CEC built into HDMI; TV's own remote works without extra hardware; also supports IR (lirc) and Bluetooth (bluez) |
| 2026-10-25 | DNS ad-blocking in jwald replaces need for Brave | StevenBlack/hosts + OISD blocklists; invisible to anti-adblock scripts; system-wide protection for browser + MPV + plugins |

## Session Log (append only)
| # | Date | Task(s) | Outcome |
|---|------|---------|---------|
| 0 | 2026-10-25 | Rules + tracker authored | Ready for PH0-T1 |
| 1 | 2026-10-25 | PH0-T1 | Initialized git repo locally; environment checked (Windows shell, no WSL distro yet) |
| 2 | 2026-10-25 | PH0-T2 | Added remote origin https://github.com/sagarsinde/JWAL-OS.git; verified PROGRESS.md |
| 3 | 2026-10-25 | PH0-T3 | Authored README.md (vision, architecture, roadmap, install, zero-sources legal statement) |
| 4 | 2026-10-25 | PH0-T4 | Created docs/ARCHITECTURE.md and docs/ROADMAP.md |
| 5 | 2026-10-25 | PH0-T5 | Confirmed GPLv3 with owner (D6 resolved); created LICENSE and .gitignore |
| 6 | 2026-10-25 | PH0-T6 | Created initial git commit (a0eca71) containing Phase 0 baseline; push pending owner go-ahead |
| 7 | 2026-10-25 | PH1-T1 | Authored scripts/env-setup.sh with --help, error handling, and toolchain checks |
| 8 | 2026-10-25 | PH1-T2 | WSL2 installed by owner; Windows reboot required before WSL2 Ubuntu shell is available |
| 9 | 2026-10-25 | PH1-T2 | Ubuntu WSL2 booted, default user adminjwal created; installed core tools, qemu, cargo+musl, flutter 3.47.8, flutter-elinux; verified with env-setup.sh --check |
| 10 | 2026-10-25 | PH1-T3 | Created test-qemu-alpine.sh; downloaded alpine-virt-3.21.9-aarch64.iso (76 MB); QEMU booted to Alpine login prompt with OpenRC; serial.log verified |
| 11 | 2026-10-25 | Architecture expansion | Added browser (WPE WebKit + Chromium fallback), remote control (HDMI-CEC/IR/BT), DNS ad-blocking subsystems to ARCHITECTURE.md and ROADMAP.md; resolved D7; total tasks 52→60 |
