#!/usr/bin/env bash
# lib/modules/system/orphans.sh — Orphaned app data detection with confidence scoring

orphans::clean() {
  if [[ "$CLEAN_ORPHANS" != "true" ]]; then
    # Still scan and report, but don't delete unless --clean-orphans is passed
    orphans::_scan "report"
    return 0
  fi

  orphans::_scan "clean"
}

# Compute a confidence score (0-100) for how likely a path is a true orphan
orphans::_score() {
  local path="$1"
  local score=0

  # ── Age factor: older = more likely orphan ────────────────────────────────
  local days_old
  days_old=$(find "$path" -maxdepth 0 -mtime +365 2>/dev/null | wc -l | tr -d ' ')
  (( days_old > 0 )) && score=$(( score + 40 ))

  local days_medium
  days_medium=$(find "$path" -maxdepth 0 -mtime +180 2>/dev/null | wc -l | tr -d ' ')
  (( days_medium > 0 && days_old == 0 )) && score=$(( score + 20 ))

  # ── Size factor: large = more likely worth flagging ────────────────────────
  local size
  size=$(utils::get_size_bytes "$path")
  (( size > 1073741824 )) && score=$(( score + 25 )) # > 1 GB
  (( size > 104857600 && size <= 1073741824 )) && score=$(( score + 15 )) # 100 MB–1 GB

  # ── Path pattern heuristics ────────────────────────────────────────────────
  local base
  base=$(basename "$path")
  [[ "$path" == *"Saved Application State"* ]] && score=$(( score + 10 ))
  [[ "$base" == *.savedState ]] && score=$(( score + 10 ))
  [[ "$path" == *"Application Support"* ]] && score=$(( score + 5 ))

  # Cap at 100
  (( score > 100 )) && score=100
  echo "$score"
}

orphans::_scan() {
  local mode="$1"  # "report" or "clean"

  log::section "Orphans"
  local start
  start=$(date +%s)
  local candidate_count=0
  local total_size=0

  # Common orphan locations
  local scan_dirs=(
    "$HOME/Library/Application Support"
    "$HOME/Library/Preferences"
    "$HOME/Library/Saved Application State"
    "$HOME/Library/Containers"
    "$HOME/Library/Caches"
  )

  # Apps currently installed (bundle IDs)
  local installed_apps_raw
  installed_apps_raw=$(find /Applications /Applications/Utilities "$HOME/Applications" \
    -maxdepth 2 -name "*.app" -exec defaults read {}/Contents/Info.plist CFBundleIdentifier \; 2>/dev/null | sort -u)

  log::verbose "Scanning for orphaned app data..."

  while IFS= read -r -d '' entry; do
    local base
    base=$(basename "$entry")
    # Skip obviously active/system dirs
    [[ "$base" == "com.apple."* ]] && continue
    [[ "$base" == "Apple"* ]] && continue

    # Check if the bundle ID is still installed
    local is_installed=false
    while IFS= read -r installed_id; do
      if [[ "$base" == "$installed_id"* || "$installed_id" == "$base"* ]]; then
        is_installed=true
        break
      fi
    done <<< "$installed_apps_raw"

    if [[ "$is_installed" == "false" ]]; then
      local score
      score=$(orphans::_score "$entry")
      local size
      size=$(utils::get_size_bytes "$entry")
      local size_fmt
      size_fmt=$(utils::format_bytes "$size")

      if (( score >= 30 )); then
        candidate_count=$(( candidate_count + 1 ))
        total_size=$(( total_size + size ))
        log::verbose "  ${YELLOW}[${score}%]${RESET} ${DIM}$entry${RESET} ($size_fmt)"

        if [[ "$mode" == "clean" && "$CLEAN_ORPHANS" == "true" ]]; then
          if [[ "$SKIP_CONFIRM" == "true" ]]; then
            utils::safe_rm "$entry" "orphan: $base"
          else
            printf "  ${YELLOW}${WARN}${RESET}  Remove orphan [%d%% confidence] %s (%s)? [y/N]: " "$score" "$base" "$size_fmt"
            local answer
            read -r answer
            if [[ "$answer" =~ ^[Yy]$ ]]; then
              utils::safe_rm "$entry" "orphan: $base"
            fi
          fi
        fi
      fi
    fi
  done < <(find "${scan_dirs[@]}" -maxdepth 1 -mindepth 1 \( -type d -o -type f -name "*.plist" \) -print0 2>/dev/null)

  local end
  end=$(date +%s)
  local dur=$(( end - start ))

  local status="review"
  if (( candidate_count == 0 )); then
    status="clean"
  elif [[ "$mode" == "clean" ]]; then
    status="$([ "$DRY_RUN" == "true" ] && echo "pending" || echo "done")"
  fi

  if (( candidate_count > 0 )); then
    log::info "Found $candidate_count orphan candidate(s) — $(utils::format_bytes "$total_size") reclaimable"
    if [[ "$CLEAN_ORPHANS" != "true" ]]; then
      log::info "Re-run with --clean-orphans to interactively remove them"
    fi
  fi

  log::module_result "Orphans" "$status" "$total_size" "$dur"
  module::register "Orphans" "System" "$total_size" 0 "$status" "$([ "$CLEAN_ORPHANS" == "true" ] && echo "$total_size" || echo 0)" "$dur"
}
