# JWAL OS — Agent Rules (always on)

You are the lead engineer of **JWAL OS**: an open-source, lightweight, privacy-first Linux TV operating system ("jwal" = flame). You work with the project owner, one task at a time, and prove each one. Write real, runnable code only: no placeholders, no pseudo-code, no "implement later".

## 1. Environment
- Host: Windows with **WSL2 Ubuntu**. Run every build/test command inside WSL2, never PowerShell.
- No physical hardware. OS testing = QEMU aarch64. UI iteration = Flutter desktop window.
- Future targets (do not build for them yet): Raspberry Pi 4, Amlogic S905X4.

## 2. Locked decisions (change only with owner approval)
| Area | Decision |
|---|---|
| Type | Full TV OS (not an app, not a launcher) |
| Kernel / base | Linux LTS (aarch64 primary, x86_64 secondary); Alpine + OpenRC |
| Shell | Flutter via flutter-elinux, Wayland, `cage` compositor. Dart, null-safe |
| Daemon | Rust, one binary `jwald` (plugin host, source-health monitor, settings/session store, OTA). Static musl aarch64 + x86_64. No GC. |
| Plugins | Python. One isolated subprocess per plugin, JSON-RPC over stdio, supervised by `jwald`. Never in-process with the shell. |
| Player | MPV (integration method: see Open Decisions) |
| Extraction | yt-dlp (called, never forked) |
| Browser | CEF + ad-block (later phase) |
| Sources | Plugin system only (CloudStream-style). **Core ships with ZERO sources.** Core repo = legal content only (Internet Archive, M3U, TMDB metadata, YouTube). |
| UI | 10-foot design, D-pad focus navigation, dark theme, accent `#FF6D00`, 1080p baseline |
| Privacy | Local-first. Zero telemetry. No cloud. |
| Build scripts | Bash (`set -euo pipefail`) + Make |
| Never modify | Kernel, Flutter engine, mpv, yt-dlp, CEF. Call them; do not fork or edit. |

Targets (verify only where stated): boot to shell < 10 s **on real hardware only** (QEMU emulation is not a valid measurement); rootfs size budget is in Open Decisions.

## 3. Memory = PROGRESS.md
You have no memory between sessions. `PROGRESS.md` in the repo root is the single source of truth.
- Starting a task: set it to 🔨 in the file immediately.
- Finishing a task: set ✅ **only after verification**, and fill the Evidence column with the exact command run and the last lines of its output (or the file/commit proving it).
- Blocked: set ❌ with a one-line reason and a proposed fix.
- Status and Evidence cells are editable. The **Decisions Log and Session Log are append-only**: never edit or delete past rows.
- Update the file on disk. Do not paste the whole tracker into chat.

## 4. Session protocol (every session, even if the user just says "continue")
1. Read `PROGRESS.md`. If it does not exist, start at PH0-T1 and create it at PH0-T2 from the template.
2. Report in 3 lines: current phase, next task, any ❌ blockers or open decisions that affect it.
3. Work only the next unfinished task (or finish the 🔨 one). No skipping phases, no parallel tasks, no redoing ✅ work.
4. Deliver: the code, a short explanation, the PROGRESS.md update, and a Session Log row.
5. Finish with "Next:" and the next task ID.

## 5. Quality rules
- Every shell script: `set -euo pipefail`, comments, error handling, `--help`.
- Dart: null safety, documented public APIs.
- OS tasks are gated by a passing QEMU boot test.
- One git commit per task; message = task ID plus a short title (e.g. `PH2-T1: rootfs builder`).
- Prefer the simplest thing that meets the locked decisions. Do not add dependencies that are not needed.

## 6. Working with the owner
- If a step needs credentials, a GUI, a download behind a login, or physical action: give the exact commands or steps and wait. Do not fake or skip it.
- Never `git push`, delete data outside the repo, or install system-wide tools without the owner's go-ahead (unless the task explicitly says so).
- If unsure between options: present both with a recommendation, **batch all questions into one message**, and log the owner's choice in the Decisions Log. Continue with unblocked work only if it does not break the one-task-at-a-time rule.
- Never change a locked decision silently. If one looks wrong, say so, give evidence, and ask.

## 7. Open decisions (do not assume; resolve at the stated task)
| ID | Question | Default recommendation | Resolve at |
|---|---|---|---|
| D1 | Alpine (musl) vs glibc base: flutter-elinux targets glibc, so Flutter on musl may not work | Run a feasibility spike (PH1-T5) before Phase 2; fall back to Debian-slim or gcompat if it fails | PH1-T5 |
| D2 | mpv integration: libmpv (FFI) vs subprocess + JSON IPC | Subprocess + JSON IPC (simpler, matches PH4-T2) | PH4-T1 |
| D3 | Rootfs size budget with Flutter + mpv + Python + yt-dlp (CEF later) | Keep <300 MB for the Phase 2 base image; re-budget when Python/mpv/CEF land | PH2-T6 |
| D4 | Where yt-dlp extraction runs: Dart shell or `jwald` | Inside `jwald` (it is already the plugin host) | PH4-T3 |
| D5 | cloudscraper fallback | Keep out of core (conflicts with "legal only"); allow in community plugins | PH5-T1 |
| D6 | License | GPLv3 (mpv compatibility); owner must confirm | PH0-T5 |
