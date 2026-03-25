#!/usr/bin/env bash
# lib/modules/dev/devtools.sh — Developer build artifacts: node_modules, Rust, Python, venv, tox, Gradle, Flutter

devtools::clean() {
  if [[ "$TARGET_DEVTOOLS" != "true" ]]; then
    return 0
  fi

  log::section "Developer Tools"
  local start
  start=$(date +%s)
  local total_size=0
  local found_count=0

  # ── node_modules ─────────────────────────────────────────────────────────
  log::verbose "Scanning for orphaned node_modules..."
  local nm_size=0
  local nm_count=0
  while IFS= read -r -d '' dir; do
    # Skip if a package.json or node_modules is very recent (< 7 days)
    local age_flag
    age_flag=$(find "$dir" -maxdepth 0 -mtime +7 2>/dev/null | wc -l | tr -d ' ')
    if (( age_flag > 0 )); then
      local s
      s=$(utils::get_size_bytes "$dir")
      nm_size=$(( nm_size + s ))
      nm_count=$(( nm_count + 1 ))
      log::verbose "  node_modules: $dir ($(utils::format_bytes "$s"))"
      utils::safe_rm "$dir" "node_modules"
    fi
  done < <(find "$HOME" -type d -name "node_modules" -not -path "*/\.*" \
    -not -path "*/node_modules/*/node_modules" -maxdepth 8 -print0 2>/dev/null)

  if (( nm_count > 0 )); then
    log::verbose "  Found $nm_count node_modules ($(utils::format_bytes "$nm_size"))"
    total_size=$(( total_size + nm_size ))
    found_count=$(( found_count + nm_count ))
  fi

  # ── Rust target/ directories ───────────────────────────────────────────────
  log::verbose "Scanning for Rust target/ directories..."
  while IFS= read -r -d '' dir; do
    local s
    s=$(utils::get_size_bytes "$dir")
    if (( s > 1048576 )); then  # > 1 MB
      log::verbose "  Rust target: $dir ($(utils::format_bytes "$s"))"
      total_size=$(( total_size + s ))
      found_count=$(( found_count + 1 ))
      utils::safe_rm "$dir" "Rust target"
    fi
  done < <(find "$HOME" -type d -name "target" -maxdepth 8 \
    -path "*/src/../target" -print0 2>/dev/null)

  # ── Python __pycache__ ────────────────────────────────────────────────────
  log::verbose "Scanning for Python __pycache__..."
  local py_size=0
  local py_count=0
  while IFS= read -r -d '' dir; do
    local s
    s=$(utils::get_size_bytes "$dir")
    py_size=$(( py_size + s ))
    py_count=$(( py_count + 1 ))
    utils::safe_rm "$dir" "__pycache__"
  done < <(find "$HOME" -type d -name "__pycache__" -maxdepth 10 -print0 2>/dev/null)

  if (( py_count > 0 )); then
    log::verbose "  $py_count __pycache__ dirs ($(utils::format_bytes "$py_size"))"
    total_size=$(( total_size + py_size ))
  fi

  # ── .pyc files ─────────────────────────────────────────────────────────────
  while IFS= read -r -d '' f; do
    local s
    s=$(utils::get_size_bytes "$f")
    total_size=$(( total_size + s ))
    utils::safe_rm "$f" ".pyc file"
  done < <(find "$HOME" -name "*.pyc" -maxdepth 10 -print0 2>/dev/null)

  # ── Python virtual environments (.venv, venv) ─────────────────────────────
  log::verbose "Scanning for Python virtual environments..."
  local venv_size=0
  while IFS= read -r -d '' dir; do
    # Only remove venvs not modified in 30+ days
    local age_flag
    age_flag=$(find "$dir" -maxdepth 0 -mtime +30 2>/dev/null | wc -l | tr -d ' ')
    if (( age_flag > 0 )); then
      local s
      s=$(utils::get_size_bytes "$dir")
      venv_size=$(( venv_size + s ))
      log::verbose "  Stale venv: $dir ($(utils::format_bytes "$s"))"
      utils::safe_rm "$dir" "python venv"
    fi
  done < <(find "$HOME" -maxdepth 8 \( -type d -name ".venv" -o -type d -name "venv" \) -print0 2>/dev/null)
  total_size=$(( total_size + venv_size ))

  # ── .tox directories ──────────────────────────────────────────────────────
  while IFS= read -r -d '' dir; do
    local s
    s=$(utils::get_size_bytes "$dir")
    if (( s > 0 )); then
      log::verbose "  .tox: $dir ($(utils::format_bytes "$s"))"
      total_size=$(( total_size + s ))
      utils::safe_rm "$dir" ".tox"
    fi
  done < <(find "$HOME" -type d -name ".tox" -maxdepth 8 -print0 2>/dev/null)

  # ── Gradle caches ─────────────────────────────────────────────────────────
  local gradle_cache="$HOME/.gradle/caches"
  if [[ -d "$gradle_cache" ]]; then
    local gs
    gs=$(utils::get_size_bytes "$gradle_cache")
    if (( gs > 0 )); then
      log::verbose "  Gradle caches: $(utils::format_bytes "$gs")"
      total_size=$(( total_size + gs ))
      utils::safe_rm "$gradle_cache" "Gradle caches"
    fi
  fi

  # ── Flutter pub cache ─────────────────────────────────────────────────────
  local flutter_cache="$HOME/.pub-cache"
  if [[ -d "$flutter_cache" ]]; then
    local fs
    fs=$(utils::get_size_bytes "$flutter_cache")
    if (( fs > 0 )); then
      local flutter_hosted="$flutter_cache/hosted"
      if [[ -d "$flutter_hosted" ]]; then
        log::verbose "  Flutter pub cache: $(utils::format_bytes "$fs")"
        total_size=$(( total_size + fs ))
        # Only remove the hosted cache, not the whole dir
        utils::safe_rm "$flutter_hosted" "Flutter hosted pub cache"
      fi
    fi
  fi

  local end
  end=$(date +%s)
  local dur=$(( end - start ))
  local status="$([ "$total_size" -gt 0 ] && { [ "$DRY_RUN" == "true" ] && echo "pending" || echo "done"; } || echo "clean")"

  log::module_result "Developer Tools" "$status" "$total_size" "$dur"
  module::register "Developer Tools" "Developer Tools" "$total_size" "$([ "$DRY_RUN" == "false" ] && echo "$total_size" || echo 0)" "$status" "$total_size" "$dur"
}
