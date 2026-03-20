<p align="center">
  <img src="icon.png" width="128" height="128" alt="Desktop Sweep icon">
</p>

<h1 align="center">Desktop Sweep</h1>

<p align="center">
  <em>A lightweight macOS utility to keep your Desktop clean — automatically.</em>
</p>

---

macOS desktops tend to get messy with screenshots, temporary files, and stuff you're not sure you want to delete.

Desktop Sweep automatically moves old files from your Desktop into date-organized Archive folders. Configurable rules, scheduling, and skip lists — set it once and forget it. Never deletes anything, only moves.

## How It Works

- Scans `~/Desktop` for non-hidden files older than 30 days (by last-modified date)
- Moves them to `~/Desktop/Archive/YYYY-MM/` (e.g., `~/Desktop/Archive/2026-02/`)
- Skips hidden files, `.DS_Store`, and directories
- If a file already exists at the destination, appends a timestamp suffix to avoid overwrites
- **Never deletes anything** — only moves
- Logs all actions to `~/Desktop/Archive/archive.log`

## Option A: macOS App (Desktop Sweep.app)

A native SwiftUI settings app with an optional menu bar icon.

### Install from DMG

Download the latest `.dmg` from [Releases](https://github.com/axiomfolly/desktop-sweep/releases), open it, and drag **Desktop Sweep** to **Applications**.

On first launch the app automatically installs the shell script and launchd agent. All settings are managed through the GUI.

### Build from Source

```bash
git clone https://github.com/axiomfolly/desktop-sweep.git
cd desktop-sweep
./build.sh
```

Requires Xcode Command Line Tools (`xcode-select --install`). Produces `build/Desktop-Sweep-v1.0.0.dmg`.

### Features

- Enable/disable toggle (starts and stops the launchd schedule)
- Schedule picker (hour and minute)
- Age threshold (days to keep files on Desktop)
- Skip files and extensions lists
- Logging toggle
- Optional menu bar icon (off by default)
- Run Now / Dry Run buttons with live output

## Option B: Shell Script Only

If you prefer no GUI, the shell script and launchd agent work standalone.

### Install

```bash
cd ~/Documents/git/desktop-cleaner
./cli/install.sh
```

### Usage

```bash
~/scripts/archive-desktop.sh --dry-run   # preview
~/scripts/archive-desktop.sh             # run for real
```

### Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/net.axiomfolly.desktop-sweep.plist
rm ~/Library/LaunchAgents/net.axiomfolly.desktop-sweep.plist
rm ~/scripts/archive-desktop.sh
```

## What Gets Installed

| File | Location |
|------|----------|
| Archive script | `~/scripts/archive-desktop.sh` |
| LaunchAgent plist | `~/Library/LaunchAgents/net.axiomfolly.desktop-sweep.plist` |
| Config file | `~/Desktop/Archive/config.cfg` |
| Archive folder | `~/Desktop/Archive/` |
| Log file | `~/Desktop/Archive/archive.log` |

## Configuration

Edit `~/Desktop/Archive/config.cfg` to customize behavior (or use the app GUI).

| Setting | Default | Description |
|---------|---------|-------------|
| `ENABLED` | `true` | Master switch — pauses all archiving when `false` |
| `SCHEDULE_HOUR` | `9` | Hour to run (24h format) |
| `SCHEDULE_MINUTE` | `0` | Minute to run |
| `LOG_ENABLED` | `true` | Write actions to `archive.log` |
| `AGE_THRESHOLD_DAYS` | `30` | Days to keep files on Desktop. `0` = archive everything. |
| `SKIP_FILES` | _(empty)_ | Comma-separated filenames to never archive |
| `SKIP_EXTENSIONS` | _(empty)_ | Comma-separated extensions to never archive (without dot) |
| `SHOW_IN_MENU_BAR` | `false` | Show Desktop Sweep in the menu bar (app only) |

Example — archive everything except PDFs and a specific file:

```cfg
AGE_THRESHOLD_DAYS=0
SKIP_FILES=notes.txt,todo.md
SKIP_EXTENSIONS=pdf,docx
```

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac (universal binary)
- Xcode Command Line Tools (for building from source)

Tested on macOS 26.2 (Tahoe), Apple Silicon (M1).

## Project Structure

```
├── DesktopSweep/                      # SwiftUI app source
│   ├── DesktopSweepApp.swift
│   ├── Info.plist
│   ├── AppIcon.icns
│   ├── Models/SweepConfig.swift
│   ├── Views/SettingsView.swift
│   ├── Views/SkipListEditor.swift
│   └── Services/
│       ├── ScriptRunner.swift
│       └── LaunchdManager.swift
├── cli/                               # Standalone CLI installer
│   ├── install.sh
│   └── net.axiomfolly.desktop-sweep.plist
├── resources/                         # Shared resources
│   ├── archive-desktop.sh
│   └── config.cfg
├── build.sh
└── README.md
```

---

<p align="center">
  <b>Desktop Sweep</b> — by <a href="https://www.axiomfolly.net">axiomfolly.net</a>
  <br><br>
  <a href="https://ko-fi.com/axiomfolly">
    <img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support on Ko-fi">
  </a>
</p>
