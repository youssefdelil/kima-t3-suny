#!/usr/bin/env bash
# lib/core/core.sh — Global state, version, and constants
# Sourced first by bin/delileche; never modified after initial parse.

export DRY_RUN=${DRY_RUN:-true}
export VERBOSE=${VERBOSE:-false}
export SKIP_CONFIRM=${SKIP_CONFIRM:-false}

# ── Global Constants ───────────────────────────────────────────────────────────
TOOL_NAME="delileche"
AUTHOR="youcef"
VERSION="1.0.0"
LOG_DIR="$HOME/.delileche"
LOG_FILE="$LOG_DIR/cleanup.log"
OPLOG_FILE="$LOG_DIR/operations.log"
STATS_FILE="$LOG_DIR/stats.log"

# Enforce standard C locale for correct numerical operations on all machines
export LC_NUMERIC=C

export LOG_FILE="${LOG_FILE}"
export OPLOG_FILE="${OPLOG_FILE}"
export STATS_FILE="${STATS_FILE}"
export VERSION="$VERSION"
export TOOL_NAME="$TOOL_NAME"
export AUTHOR="$AUTHOR"

# Cleanup targets (default: all false, set by CLI flags)
export TARGET_SYSTEM=false
export TARGET_XCODE=false
export TARGET_DOCKER=false
export TARGET_DEVTOOLS=false
export TARGET_SNAPSHOTS=false
export TARGET_CACHES=false
export TARGET_BREW=false
export TARGET_MAIL=false
export TARGET_SYSTEM_DEEP=false

# Tracking — accumulate bytes freed across modules
export TOTAL_FREED=0
export TOTAL_DRYRUN_BYTES=0

# Feature flags
export CLEAN_ORPHANS=${CLEAN_ORPHANS:-false}
export INCLUDE_ML_MODELS=${INCLUDE_ML_MODELS:-false}
export DEVOPS_RESET_MODE=${DEVOPS_RESET_MODE:-false}
export SHOW_OPERATION_LOG=${SHOW_OPERATION_LOG:-false}
export SHOW_VERSION=${SHOW_VERSION:-false}
export TARGET_OPTIMIZE=${TARGET_OPTIMIZE:-false}
export JSON_OUTPUT=${JSON_OUTPUT:-false}
export SHOW_STATS=${SHOW_STATS:-false}

# Per-module reporting arrays
# Each module registers: name, category, scanned bytes, freed bytes, status,
# and projected reclaimable bytes for the summary report.
declare -a MODULE_NAMES=()
declare -a MODULE_CATEGORIES=()
declare -a MODULE_SCANNED=()
declare -a MODULE_FREED=()
declare -a MODULE_STATUS=()
declare -a MODULE_PROJECTED=()
declare -a MODULE_DURATIONS=()

# Paths that macOS SIP or system ownership protects — never attempt deletion
readonly SIP_PROTECTED_PATHS=(
  "$HOME/Library/Caches/com.apple.HomeKit"
  "$HOME/Library/Caches/CloudKit"
  "$HOME/Library/Caches/com.apple.Safari"
  "$HOME/Library/Caches/com.apple.spotlight"
  "$HOME/Library/Caches/com.apple.Spotlight"
  "$HOME/Library/Caches/com.apple.FontRegistry"
  "$HOME/Library/Caches/com.apple.finder"
  "$HOME/Library/Caches/com.apple.homed"
  "$HOME/Library/Caches/com.apple.bird"
  "$HOME/Library/Caches/com.apple.nsurlsessiond"
  "$HOME/Library/Caches/com.apple.WebKit.Networking"
  "$HOME/Library/Caches/com.apple.ap.adprivacyd"
  "$HOME/Library/Logs"
  "/Library/Logs"
)
