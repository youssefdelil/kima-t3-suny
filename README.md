# 🧹 delileche youcef

> A modular, safe-by-default macOS developer disk-cleanup CLI — enhanced and rebranded.

```
  ██████╗ ███████╗██╗     ██╗██╗     ███████╗ ██████╗██╗  ██╗███████╗
  ██╔══██╗██╔════╝██║     ██║██║     ██╔════╝██╔════╝██║  ██║██╔════╝
  ██║  ██║█████╗  ██║     ██║██║     █████╗  ██║     ███████║█████╗  
  ██║  ██║██╔══╝  ██║     ██║██║     ██╔══╝  ██║     ██╔══██║██╔══╝  
  ██████╔╝███████╗███████╗██║███████╗███████╗╚██████╗██║  ██║███████╗
  ╚═════╝ ╚══════╝╚══════╝╚═╝╚══════╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚══════╝
                                          by youcef — v1.0.0
```

**Built in pure Bash. No dependencies. Safe by default.**

---

## Why delileche?

Developers accumulate gigabytes of forgotten junk: DerivedData, Docker ghosts, orphaned `node_modules`, Python caches, old iOS backups. macOS never cleans these automatically. `delileche` replaces a dozen `rm -rf` commands with a single, safe, auditable CLI.

---

## What it cleans

| Flag | What it removes |
|---|---|
| `--system`       | Crash reports, `.DS_Store`, Trash, Xcode IB Support |
| `--system-deep`  | Rotated logs (`.gz`/`.bz2`/`.old`), old iOS backups, CrashReporter |
| `--xcode`        | DerivedData, old Archives (60d+), old iOS DeviceSupport (2y+), Simulator caches |
| `--docker`       | Stopped containers, dangling images & volumes, build cache |
| `--devtools`     | `node_modules` (7d+), Rust `target/`, `__pycache__`, `.pyc`, `.venv`/`venv` (30d+), `.tox`, Gradle, Flutter pub hosted cache |
| `--snapshots`    | Local Time Machine snapshots |
| `--caches`       | ~/Library/Caches (Spotify, JetBrains, VS Code, npm, pip, yarn, CocoaPods), browser caches (Chrome, Firefox, Safari, **Arc**, Brave, Edge, Opera), Slack/Discord/Zoom/Figma caches |
| `--mail`         | Old Mail attachments (30d+), stale recent-items metadata |
| `--brew`         | `brew cleanup --prune=all`, `brew autoremove` |
| `--optimize`     | DNS flush, LaunchServices rebuild, SQLite vacuum |
| `--all`          | All of the above |

### Orphan Detection (new!)

```bash
delileche --clean-orphans
```

Scans `~/Library/Application Support`, Preferences, Containers, and Caches for data from apps that are **no longer installed**. Each candidate gets a **confidence score (0–100%)** based on:
- **Age** — older entries score higher
- **Size** — larger entries score higher
- **Path pattern** — `.savedState`, Containers, etc.

---

## Supported macOS Versions

- macOS Ventura (13) 
- macOS Sonoma (14) 
- macOS Sequoia (15) 

---

## Installation

### One-line installer
```bash
curl -fsSL https://raw.githubusercontent.com/youcef/delileche-youcef/main/install.sh | bash
```

### Run from source (no install required)
```bash
git clone https://github.com/youcef/delileche-youcef.git
cd delileche-youcef
chmod +x bin/delileche
./bin/delileche          # Runs --all --dry-run by default
```

Optionally symlink to run from anywhere:
```bash
ln -sf "$(pwd)/bin/delileche" /usr/local/bin/delileche
```

---

## Usage

```bash
# Preview all cleanups — safe, no files deleted
delileche

# Preview + verbose (shows every item with size)
delileche --all --dry-run --verbose

# Live cleanup of everything — no prompts
delileche --all --yes

# Clean specific targets
delileche --xcode --docker --yes

# Deep system + dev caches with JSON report
delileche --system-deep --devtools --json

# Interactive orphan removal (with confidence scores)
delileche --clean-orphans

# Show run history
delileche --stats

# Show deletion operation log
delileche --show-log

# Nuclear DevOps reset (destroys all Docker + dev caches)
delileche --devops-reset --yes

# Include ML model caches in DevOps reset
delileche --devops-reset --include-ml-models --yes
```

---

## Flag Reference

| Flag | Short | Description |
|---|---|---|
| `--system`         | `-S` | Clean system artifacts |
| `--system-deep`    | `-z` | Deep log and diagnostic cleanup |
| `--xcode`          | `-x` | Xcode DerivedData, Archives, DeviceSupport |
| `--docker`         | `-d` | Docker prune |
| `--devtools`       | `-D` | Developer build artifacts |
| `--snapshots`      | `-s` | Time Machine local snapshots |
| `--caches`         | `-c` | User + browser + app caches |
| `--mail`           | `-m` | Mail attachments and metadata |
| `--brew`           | `-b` | Homebrew cleanup |
| `--optimize`       | `-O` | System optimizations |
| `--all`            | `-a` | All targets |
| `--dry-run`        | `-n` | Preview only (default) |
| `--yes`            | `-y` | Skip confirmation, run live |
| `--json`           |      | **NEW** — Print JSON summary report |
| `--stats`          |      | **NEW** — Show run history |
| `--clean-orphans`  |      | Interactively remove orphaned app data |
| `--devops-reset`   |      | Nuclear developer cleanup |
| `--include-ml-models` |   | Include HuggingFace/Ollama caches |
| `--show-log`       |      | Print operation log |
| `--version`        | `-V` | Print version |
| `--verbose`        | `-v` | Detailed per-item output |
| `--help`           | `-h` | Show help |

---

## Safety

- **Dry-run by default** — running `delileche` with no flags shows a safe preview
- **Interactive mode** — passing targets without `--yes` prompts before any deletion  
- **SIP-protected paths** are permanently blocked (defined in `lib/core/core.sh`)
- **Whitelist** — add paths to `~/.config/delileche/whitelist` to permanently skip them
- **Operation log** — every delete is logged to `~/.delileche/operations.log`

### What it will NEVER touch
- `/System`, `/usr`, `/bin`, `/sbin`, `/etc`
- `$HOME` itself
- Any paths in `SIP_PROTECTED_PATHS` (Safari cache, CloudKit, etc.)
- Any path matching your whitelist

---

## JSON Output

```bash
delileche --all --dry-run --json | python3 -m json.tool
```

Returns a structured JSON object:
```json
{
  "tool": "delileche",
  "version": "1.0.0",
  "author": "youcef",
  "timestamp": "2026-03-25T12:00:00Z",
  "mode": "dry-run",
  "duration_seconds": 4,
  "modules": [...],
  "totals": {
    "scanned_bytes": 2147483648,
    "projected_bytes": 1610612736
  }
}
```

---

## Logs & Stats

| File | Purpose |
|---|---|
| `~/.delileche/cleanup.log` | Full timestamped run log |
| `~/.delileche/operations.log` | Per-file deletion audit trail |
| `~/.delileche/stats.log` | Run history (shown by `--stats`) |

---

## Uninstall

```bash
# If installed via install.sh
rm -rf ~/.delileche
rm /usr/local/bin/delileche    # or ~/.local/bin/delileche
```

---

## Enhancements over mac-cleanup

| Feature | Original | delileche |
|---|---|---|
| Author | PiusSunday | youcef |
| `--json` output | ❌ | ✅ |
| `--stats` run history | ❌ | ✅ |
| Orphan confidence scoring | ❌ | ✅ |
| Arc browser cache | ❌ | ✅ |
| `.venv` / `.tox` cleanup | ❌ | ✅ |
| CocoaPods cache | ❌ | ✅ |
| Per-module timing | ❌ | ✅ |
| Purple accent color & ASCII banner | ❌ | ✅ |
| TB size support | ❌ | ✅ |

---

## License

MIT — see [LICENSE](LICENSE)
