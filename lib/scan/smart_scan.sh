#!/usr/bin/env bash
# lib/scan/smart_scan.sh — Smart space scanner with prioritized recommendations

smart_scan::run() {
  log::section "Smart Scan"

  local bar
  bar=$(printf '━%.0s' $(seq 1 68))
  printf "\n  ${BOLD}${PURPLE}%s${RESET}\n" "$bar"
  printf "  ${BOLD}${MAGENTA}  Smart Scan — Finding your biggest wins${RESET}\n"
  printf "  ${BOLD}${PURPLE}%s${RESET}\n\n" "$bar"

  local -a rec_labels=()
  local -a rec_sizes=()
  local -a rec_flags=()
  local -a rec_tips=()

  _check_dir() {
    local path="$1"
    local label="$2"
    local flag="$3"
    local tip="$4"

    if [[ -d "$path" ]]; then
      local s
      s=$(utils::get_size_bytes "$path")
      if (( s > 10485760 )); then  # > 10 MB
        rec_labels+=("$label")
        rec_sizes+=("$s")
        rec_flags+=("$flag")
        rec_tips+=("$tip")
      fi
    fi
  }

  printf "  ${DIM}Scanning your Mac...${RESET}\n\n"

  # Xcode
  _check_dir "$HOME/Library/Developer/Xcode/DerivedData" \
    "Xcode DerivedData" "--xcode" "Safe to delete — rebuilt automatically on next build"
  _check_dir "$HOME/Library/Developer/Xcode/Archives" \
    "Xcode Archives" "--xcode" "Old app archives — delete if no longer needed for distribution"
  _check_dir "$HOME/Library/Developer/Xcode/iOS DeviceSupport" \
    "iOS DeviceSupport" "--xcode" "Device symbol caches — can be very large, safe to remove"
  _check_dir "$HOME/Library/Developer/CoreSimulator/Caches" \
    "Simulator Caches" "--xcode" "Simulator cache — rebuilt on demand"

  # Docker
  _check_dir "$HOME/Library/Containers/com.docker.docker" \
    "Docker Data" "--docker" "Run 'docker system prune' to reclaim space"

  # Developer caches
  _check_dir "$HOME/.gradle/caches" \
    "Gradle Caches" "--devtools" "Build caches — safe to remove"
  _check_dir "$HOME/.npm" \
    "npm Cache" "--devtools" "Node package cache — rebuilt on demand"
  _check_dir "$HOME/.cache/pip" \
    "pip Cache" "--devtools" "Python package cache — rebuilt on demand"
  _check_dir "$HOME/.pub-cache/hosted" \
    "Flutter pub Cache" "--devtools" "Flutter hosted pub packages"

  # User caches
  _check_dir "$HOME/Library/Caches" \
    "System/App Caches" "--caches" "Browser and application caches"
  _check_dir "$HOME/Library/Caches/com.spotify.client" \
    "Spotify Cache" "--caches" "Streamed content cache — rebuilt on playback"
  _check_dir "$HOME/Library/Caches/JetBrains" \
    "JetBrains Cache" "--caches" "IDE caches — rebuilt automatically"

  # Mail
  local mail_total=0
  for v in V10 V9 V8; do
    local d="$HOME/Library/Mail/$v/MailData/Attachments"
    if [[ -d "$d" ]]; then
      local s
      s=$(utils::get_size_bytes "$d")
      mail_total=$(( mail_total + s ))
    fi
  done
  if (( mail_total > 10485760 )); then
    rec_labels+=("Mail Attachments")
    rec_sizes+=("$mail_total")
    rec_flags+=("--mail")
    rec_tips+=("Old email attachments cached locally")
  fi

  # Snapshots
  if command -v tmutil >/dev/null 2>&1; then
    local snap_count
    snap_count=$(tmutil listlocalsnapshots / 2>/dev/null | wc -l | tr -d ' ')
    if (( snap_count > 0 )); then
      rec_labels+=("Time Machine Snapshots")
      rec_sizes+=("$(( snap_count * 524288000 ))")  # ~500MB estimate each
      rec_flags+=("--snapshots")
      rec_tips+=("$snap_count local snapshot(s) — can be large on small SSDs")
    fi
  fi

  # Sort by size descending
  local n=${#rec_labels[@]}
  for (( i=0; i<n-1; i++ )); do
    for (( j=0; j<n-i-1; j++ )); do
      if (( rec_sizes[j] < rec_sizes[j+1] )); then
        local tmp_s="${rec_sizes[j]}"
        local tmp_l="${rec_labels[j]}"
        local tmp_f="${rec_flags[j]}"
        local tmp_t="${rec_tips[j]}"
        rec_sizes[$j]="${rec_sizes[$j+1]}"
        rec_labels[$j]="${rec_labels[$j+1]}"
        rec_flags[$j]="${rec_flags[$j+1]}"
        rec_tips[$j]="${rec_tips[$j+1]}"
        rec_sizes[$((j+1))]="$tmp_s"
        rec_labels[$((j+1))]="$tmp_l"
        rec_flags[$((j+1))]="$tmp_f"
        rec_tips[$((j+1))]="$tmp_t"
      fi
    done
  done

  if (( n == 0 )); then
    printf "  ${GREEN}${CHECK}${RESET}  Your Mac looks clean! Nothing significant found.\n\n"
    return 0
  fi

  # Build recommended command
  local total_win=0
  local best_flags=""
  local rank=1

  for (( i=0; i<n && i<8; i++ )); do
    local sz="${rec_sizes[$i]}"
    local label="${rec_labels[$i]}"
    local flag="${rec_flags[$i]}"
    local tip="${rec_tips[$i]}"
    local fmt
    fmt=$(utils::format_bytes "$sz")
    total_win=$(( total_win + sz ))

    local color="${GREEN}"
    (( sz > 104857600  )) && color="${YELLOW}"
    (( sz > 1073741824 )) && color="${RED}"

    printf "  ${BOLD}%d.${RESET} %-28s ${color}${BOLD}%s${RESET}\n" "$rank" "$label" "$fmt"
    printf "     ${DIM}%s${RESET}  →  ${CYAN}delileche %s --dry-run${RESET}\n\n" "$tip" "$flag"

    # Deduplicate flags
    if [[ "$best_flags" != *"$flag"* ]]; then
      best_flags="$best_flags $flag"
    fi
    (( rank++ ))
  done

  local total_fmt
  total_fmt=$(utils::format_bytes "$total_win")
  local sep
  sep=$(printf '─%.0s' $(seq 1 68))

  printf "  ${PURPLE}%s${RESET}\n" "$sep"
  printf "  ${BOLD}  Potential savings: ${GREEN}%s${RESET}\n\n" "$total_fmt"
  printf "  ${BOLD}  Recommended command:${RESET}\n"
  printf "  ${BOLD}${CYAN}  delileche%s --dry-run${RESET}\n\n" "$best_flags"
}
