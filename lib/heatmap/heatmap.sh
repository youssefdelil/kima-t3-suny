#!/usr/bin/env bash
# lib/heatmap/heatmap.sh — ASCII disk usage heatmap for key directories

heatmap::run() {
  log::section "Disk Heatmap"

  local bar_width=40
  local total_bytes
  total_bytes=$(utils::get_size_bytes "$HOME")
  (( total_bytes == 0 )) && total_bytes=1

  # Key directories to scan
  local -a dirs=(
    "$HOME/Library/Developer"
    "$HOME/Library/Caches"
    "$HOME/Library/Application Support"
    "$HOME/Library/Containers"
    "$HOME/Downloads"
    "$HOME/Desktop"
    "$HOME/Documents"
    "$HOME/Movies"
    "$HOME/Music"
    "$HOME/.docker"
    "$HOME/.gradle"
    "$HOME/.npm"
    "$HOME/.cache"
    "$HOME/Library/Logs"
    "$HOME/Library/Mail"
    "$HOME/Library/Messages"
  )

  local -a sizes=()
  local -a labels=()
  local max_size=1

  # Gather sizes
  for dir in "${dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      local s
      s=$(utils::get_size_bytes "$dir")
      sizes+=("$s")
      # Shorten label
      local label="${dir/$HOME\//~/}"
      labels+=("$label")
      (( s > max_size )) && max_size=$s
    fi
  done

  # Sort by size descending (bubble sort — small array is fine)
  local n=${#sizes[@]}
  for (( i=0; i<n-1; i++ )); do
    for (( j=0; j<n-i-1; j++ )); do
      if (( sizes[j] < sizes[j+1] )); then
        local tmp_s="${sizes[j]}"
        local tmp_l="${labels[j]}"
        sizes[$j]="${sizes[$j+1]}"
        labels[$j]="${labels[$j+1]}"
        sizes[$((j+1))]="$tmp_s"
        labels[$((j+1))]="$tmp_l"
      fi
    done
  done

  local bar
  bar=$(printf '━%.0s' $(seq 1 68))
  printf "\n  ${BOLD}${PURPLE}%s${RESET}\n" "$bar"
  printf "  ${BOLD}  %-32s %10s   %s${RESET}\n" "Directory" "Size" "Usage"
  printf "  ${PURPLE}%s${RESET}\n" "$bar"

  for (( i=0; i<n && i<14; i++ )); do
    local s="${sizes[$i]}"
    local label="${labels[$i]}"
    local size_fmt
    size_fmt=$(utils::format_bytes "$s")

    # Calculate bar fill
    local fill=$(( s * bar_width / max_size ))
    (( fill < 1 && s > 0 )) && fill=1

    # Color based on size
    local color="${GREEN}"
    (( s > 104857600  )) && color="${YELLOW}"   # > 100 MB
    (( s > 1073741824 )) && color="${RED}"       # > 1 GB
    (( s > 5368709120 )) && color="${BOLD}${RED}" # > 5 GB

    local filled_bar
    filled_bar=$(printf '█%.0s' $(seq 1 $fill) 2>/dev/null || printf '%*s' "$fill" | tr ' ' '█')
    local empty_bar
    local empty_len=$(( bar_width - fill ))
    (( empty_len > 0 )) && empty_bar=$(printf '░%.0s' $(seq 1 $empty_len)) || empty_bar=""

    printf "  %-32s %10s   ${color}%s${RESET}${DIM}%s${RESET}\n" \
      "$label" "$size_fmt" "$filled_bar" "$empty_bar"
  done

  printf "  ${PURPLE}%s${RESET}\n\n" "$bar"

  # Tip: biggest offenders
  if (( n > 0 )); then
    local top_label="${labels[0]}"
    local top_fmt
    top_fmt=$(utils::format_bytes "${sizes[0]}")
    printf "  ${YELLOW}${WARN}${RESET}  Biggest space consumer: ${BOLD}%s${RESET} — ${RED}%s${RESET}\n" "$top_label" "$top_fmt"
    printf "  ${CYAN}${INFO}${RESET}  Run ${BOLD}delileche --scan${RESET} for smart cleanup recommendations.\n\n"
  fi
}
