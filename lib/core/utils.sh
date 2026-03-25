#!/usr/bin/env bash
# lib/core/utils.sh — Shared utilities: colors, logging, sizing, safety, JSON

# Disable colors when stdout is not a TTY (piped or redirected)
if [[ -t 1 ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[1;33m'
  BLUE=$'\033[0;34m'
  CYAN=$'\033[0;36m'
  PURPLE=$'\033[0;35m'
  MAGENTA=$'\033[1;35m'
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  CYAN=''
  PURPLE=''
  MAGENTA=''
  BOLD=''
  DIM=''
  RESET=''
fi

# ── Symbols ───────────────────────────────────────────────────────────────────
CHECK="✔"
CROSS="✘"
ARROW="→"
INFO="ℹ"
WARN="⚠"
TRASH="🗑"
SPARKLE="✨"
DOT="•"

# ── Safety primitives ─────────────────────────────────────────────────────────
WHITELIST_FILE="${WHITELIST_FILE:-$HOME/.config/delileche/whitelist}"
declare -a WHITELIST_PATTERNS=()

# ── Internal log-to-file helper ───────────────────────────────────────────────
_log_to_file() {
  local level="$1"
  local message="$2"
  mkdir -p "$(dirname "$LOG_FILE")"
  printf "[%s] [%-8s] %s\n" \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message" >> "$LOG_FILE"
}

_oplog() {
  local action="$1"
  local path="$2"
  local size="$3"
  mkdir -p "$(dirname "$OPLOG_FILE")"
  printf "[%s] [%s] %s (%s)\n" \
    "$(date '+%Y-%m-%dT%H:%M:%S')" "$action" "$path" "$size" >> "$OPLOG_FILE"
}

# ── Logging functions ──────────────────────────────────────────────────────────
log::info() {
  printf "${CYAN}${INFO} %s${RESET}\n" "$1"
  _log_to_file "INFO" "$1"
}

log::success() {
  printf "${GREEN}${CHECK} %s${RESET}\n" "$1"
  _log_to_file "SUCCESS" "$1"
}

log::warn() {
  printf "${YELLOW}${WARN} %s${RESET}\n" "$1"
  _log_to_file "WARN" "$1"
}

log::error() {
  printf "${RED}${CROSS} %s${RESET}\n" "$1" >&2
  _log_to_file "ERROR" "$1"
}

log::verbose() {
  if [[ "$VERBOSE" == "true" ]]; then
    printf "${DIM}    ${DOT} %s${RESET}\n" "$1"
  fi
  _log_to_file "VERBOSE" "$1"
}

log::section() {
  local title="$1"
  local width=52
  local pad_len=$(( width - ${#title} - 6 ))
  [[ $pad_len -lt 0 ]] && pad_len=0
  local pad
  pad=$(printf '─%.0s' $(seq 1 $pad_len))
  printf "\n${BOLD}${PURPLE}  ┌─── %s %s${RESET}\n" "$title" "$pad"
  _log_to_file "MODULE" "$title"
}

log::category() {
  local title="$1"
  local bar
  bar=$(printf '━%.0s' $(seq 1 60))
  printf "\n${BOLD}${MAGENTA}${bar}${RESET}\n"
  printf "${BOLD}${MAGENTA}  ◆ %s${RESET}\n" "$title"
  printf "${BOLD}${MAGENTA}${bar}${RESET}\n"
}

# ── Get size of a path in bytes ───────────────────────────────────────────────
utils::get_size_bytes() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    echo 0
    return 0
  fi
  local size
  size=$(du -sk "$path" 2>/dev/null | awk '{print $1}')
  echo $(( size * 1024 ))
}

utils::realpath() {
  local path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$path" 2>/dev/null && return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$path" 2>/dev/null && return 0
  fi
  if [[ -e "$path" ]]; then
    local dir base
    dir="$(dirname "$path")"
    base="$(basename "$path")"
    (cd "$dir" 2>/dev/null && printf "%s/%s\n" "$(pwd -P)" "$base") && return 0
  fi
  return 1
}

# Get free disk bytes on /
utils::get_free_bytes() {
  df -k / | awk 'NR==2 {print $4 * 1024}'
}

# ── Format bytes to human-readable (B, KB, MB, GB, TB) ───────────────────────
utils::format_bytes() {
  local bytes="$1"
  if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
    echo "0 B"
    return
  fi
  if (( bytes >= 1099511627776 )); then
    printf "%.2f TB" "$(echo "scale=2; $bytes / 1099511627776" | bc)"
  elif (( bytes >= 1073741824 )); then
    printf "%.2f GB" "$(echo "scale=2; $bytes / 1073741824" | bc)"
  elif (( bytes >= 1048576 )); then
    printf "%.2f MB" "$(echo "scale=2; $bytes / 1048576" | bc)"
  elif (( bytes >= 1024 )); then
    printf "%.2f KB" "$(echo "scale=2; $bytes / 1024" | bc)"
  else
    printf "%d B" "$bytes"
  fi
}

# ── Safety: path validation before any deletion ───────────────────────────────
utils::is_safe_path() {
  local path="$1"
  [[ -z "$path" ]] && return 1

  # Resolve symlinks for comparison
  local real_path
  real_path=$(utils::realpath "$path" 2>/dev/null) || real_path="$path"

  # Guard against root-level or home-level deletion
  local home_real
  home_real=$(utils::realpath "$HOME" 2>/dev/null) || home_real="$HOME"

  # Block exact home dir or root
  if [[ "$real_path" == "/" || "$real_path" == "$home_real" ]]; then
    log::error "Blocked: refusing to delete home or root: $path"
    return 1
  fi

  # Block SIP-protected paths
  for protected in "${SIP_PROTECTED_PATHS[@]}"; do
    local protected_real
    protected_real=$(utils::realpath "$protected" 2>/dev/null) || protected_real="$protected"
    if [[ "$real_path" == "$protected_real"* ]]; then
      log::verbose "Blocked (SIP protected): $path"
      return 1
    fi
  done

  # Block whitelisted paths
  for pattern in "${WHITELIST_PATTERNS[@]}"; do
    if [[ "$path" == $pattern ]]; then
      log::verbose "Skipped (whitelisted): $path"
      return 1
    fi
  done

  return 0
}

# ── Safe removal — all deletes go through this ────────────────────────────────
utils::safe_rm() {
  local path="$1"
  local description="${2:-$path}"

  if ! utils::is_safe_path "$path"; then
    return 1
  fi

  local size
  size=$(utils::get_size_bytes "$path")
  local size_fmt
  size_fmt=$(utils::format_bytes "$size")

  if [[ "$DRY_RUN" == "true" ]]; then
    log::verbose "  [dry-run] Would remove: $description ($size_fmt)"
    TOTAL_DRYRUN_BYTES=$(( TOTAL_DRYRUN_BYTES + size ))
    return 0
  fi

  if rm -rf "$path" 2>/dev/null; then
    log::verbose "  ${TRASH} Removed: $description ($size_fmt)"
    _oplog "DELETE" "$path" "$size_fmt"
    TOTAL_FREED=$(( TOTAL_FREED + size ))
    return 0
  else
    log::warn "  Failed to remove: $description"
    return 1
  fi
}

# ── Confirmation prompt ────────────────────────────────────────────────────────
utils::confirm() {
  local prompt="$1"
  printf "${YELLOW}${WARN}  %s [y/N]: ${RESET}" "$prompt"
  local answer
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

# ── Load whitelist from file ───────────────────────────────────────────────────
utils::load_whitelist() {
  if [[ -f "$WHITELIST_FILE" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" || "$line" == \#* ]] && continue
      WHITELIST_PATTERNS+=("$line")
    done < "$WHITELIST_FILE"
    log::verbose "Loaded ${#WHITELIST_PATTERNS[@]} whitelist entries from $WHITELIST_FILE"
  fi
}

# ── macOS version check ────────────────────────────────────────────────────────
utils::check_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    log::error "delileche only runs on macOS."
    exit 1
  fi
}

# ── Dependency checker ────────────────────────────────────────────────────────
utils::require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log::warn "Required command not found: $cmd — module skipped."
    return 1
  fi
  return 0
}

# ── Spinner for long-running operations ───────────────────────────────────────
utils::spinner() {
  local pid="$1"
  local msg="${2:-Working...}"
  local i=0
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  if [[ ! -t 1 ]]; then
    wait "$pid"
    return $?
  fi
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${PURPLE}%s${RESET} %s" "${frames[$i]}" "$msg"
    i=$(( (i + 1) % ${#frames[@]} ))
    sleep 0.08
  done
  printf "\r  ${GREEN}${CHECK}${RESET} %s\n" "$msg"
  wait "$pid"
}

# ── Top-level grouping: module result line ─────────────────────────────────────
log::module_result() {
  local name="$1"
  local status="$2"
  local size="${3:-}"
  local duration="${4:-}"

  local status_str
  case "$status" in
    clean)    status_str="${GREEN}Clean${RESET}" ;;
    skipped)  status_str="${YELLOW}Skipped${RESET}" ;;
    review)   status_str="${CYAN}Needs review${RESET}" ;;
    done)     status_str="${GREEN}${CHECK} Done${RESET}" ;;
    pending)  status_str="${YELLOW}Pending${RESET}" ;;
    *)        status_str="${DIM}${status}${RESET}" ;;
  esac

  local size_str=""
  if [[ -n "$size" && "$size" != "0" ]]; then
    size_str="  ${DIM}($(utils::format_bytes "$size"))${RESET}"
  fi

  local dur_str=""
  if [[ -n "$duration" ]]; then
    dur_str="  ${DIM}${duration}s${RESET}"
  fi

  printf "  ${BOLD}${PURPLE}└${RESET} %-28s %s%s%s\n" "$name" "$status_str" "$size_str" "$dur_str"
}

# ── Print rich system context header ──────────────────────────────────────────
utils::print_system_context() {
  local os_version
  os_version=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
  local hostname
  hostname=$(scutil --get ComputerName 2>/dev/null || hostname)
  local free_bytes
  free_bytes=$(utils::get_free_bytes)
  local free_fmt
  free_fmt=$(utils::format_bytes "$free_bytes")
  local shell_ver="${BASH_VERSION:-unknown}"
  local user="${USER:-$(whoami)}"

  local bar
  bar=$(printf '━%.0s' $(seq 1 68))

  printf "\n${BOLD}${PURPLE}%s${RESET}\n" "$bar"
  printf "${BOLD}${MAGENTA}  🧹 delileche v%s  ${DIM}by %s${RESET}\n" "$VERSION" "$AUTHOR"
  printf "${BOLD}${PURPLE}%s${RESET}\n" "$bar"
  printf "  ${DIM}Host:${RESET}    %s\n" "$hostname"
  printf "  ${DIM}User:${RESET}    %s\n" "$user"
  printf "  ${DIM}macOS:${RESET}   %s\n" "$os_version"
  printf "  ${DIM}Bash:${RESET}    %s\n" "$shell_ver"
  printf "  ${DIM}Free:${RESET}    %s\n" "$free_fmt"
  printf "  ${DIM}Mode:${RESET}    %s\n" "$([ "$DRY_RUN" == "true" ] && echo "DRY-RUN (preview only)" || echo "${RED}LIVE — files will be deleted${RESET}")"
  printf "${BOLD}${PURPLE}%s${RESET}\n\n" "$bar"
}

# ── Module registration ───────────────────────────────────────────────────────
module::register() {
  local name="$1"
  local category="$2"
  local scanned="${3:-0}"
  local freed="${4:-0}"
  local status="${5:-clean}"
  local projected="${6:-0}"
  local duration="${7:-0}"

  MODULE_NAMES+=("$name")
  MODULE_CATEGORIES+=("$category")
  MODULE_SCANNED+=("$scanned")
  MODULE_FREED+=("$freed")
  MODULE_STATUS+=("$status")
  MODULE_PROJECTED+=("$projected")
  MODULE_DURATIONS+=("$duration")
}

# ── Show operation log ────────────────────────────────────────────────────────
utils::show_operation_log() {
  if [[ ! -f "$OPLOG_FILE" ]]; then
    printf "${YELLOW}${WARN}  No operation log found at %s${RESET}\n" "$OPLOG_FILE"
    return 0
  fi
  printf "\n${BOLD}${PURPLE}  Operation Log — %s${RESET}\n\n" "$OPLOG_FILE"
  cat "$OPLOG_FILE"
}

# ── Show stats (run history) ──────────────────────────────────────────────────
utils::show_stats() {
  if [[ ! -f "$STATS_FILE" ]]; then
    printf "${YELLOW}${WARN}  No stats found yet. Run delileche first.${RESET}\n"
    return 0
  fi
  printf "\n${BOLD}${PURPLE}  Run History — %s${RESET}\n\n" "$STATS_FILE"
  printf "  ${BOLD}%-22s %-12s %-12s %-10s %s${RESET}\n" \
    "Date" "Mode" "Freed" "Duration" "Modules"
  printf "  %s\n" "$(printf '─%.0s' $(seq 1 70))"
  while IFS='|' read -r ts mode freed duration mods; do
    printf "  %-22s %-12s %-12s %-10s %s\n" "$ts" "$mode" "$freed" "${duration}s" "$mods"
  done < "$STATS_FILE"
  printf "\n"
}

# ── Save run stats ────────────────────────────────────────────────────────────
utils::save_stats() {
  local mode="$1"
  local freed_bytes="$2"
  local duration="$3"
  local module_count="$4"
  mkdir -p "$(dirname "$STATS_FILE")"
  local freed_fmt
  freed_fmt=$(utils::format_bytes "$freed_bytes")
  printf "%s|%s|%s|%s|%s\n" \
    "$(date '+%Y-%m-%d %H:%M')" "$mode" "$freed_fmt" "$duration" "${module_count} modules" >> "$STATS_FILE"
}

# ── JSON helpers ──────────────────────────────────────────────────────────────
json::escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  echo "$s"
}

json::kv_str() {
  printf '"%s": "%s"' "$(json::escape "$1")" "$(json::escape "$2")"
}

json::kv_num() {
  printf '"%s": %s' "$(json::escape "$1")" "$2"
}
