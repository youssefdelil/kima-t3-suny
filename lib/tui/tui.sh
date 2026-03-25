#!/usr/bin/env bash
# lib/tui/tui.sh — Interactive arrow-key module selector TUI

# ── TUI state ──────────────────────────────────────────────────────────────────
declare -a TUI_LABELS=(
  "System              (.DS_Store, Trash, crash reports)"
  "System Deep         (rotated logs, old iOS backups)"
  "Xcode               (DerivedData, Archives, DeviceSupport)"
  "Docker              (containers, images, volumes)"
  "Developer Tools     (node_modules, Rust, Python, .venv)"
  "Snapshots           (Time Machine local snapshots)"
  "Caches              (Library, browsers, apps)"
  "Mail                (old attachments, metadata)"
  "Homebrew            (brew cleanup + autoremove)"
  "Optimize            (DNS flush, SQL vacuum, LS rebuild)"
)

declare -a TUI_FLAGS=(
  TARGET_SYSTEM
  TARGET_SYSTEM_DEEP
  TARGET_XCODE
  TARGET_DOCKER
  TARGET_DEVTOOLS
  TARGET_SNAPSHOTS
  TARGET_CACHES
  TARGET_MAIL
  TARGET_BREW
  TARGET_OPTIMIZE
)

declare -a TUI_SELECTED=()

tui::init_selected() {
  for i in "${!TUI_FLAGS[@]}"; do
    TUI_SELECTED[$i]=0
  done
}

tui::toggle() {
  local i="$1"
  if (( TUI_SELECTED[i] == 1 )); then
    TUI_SELECTED[$i]=0
  else
    TUI_SELECTED[$i]=1
  fi
}

tui::select_all() {
  for i in "${!TUI_FLAGS[@]}"; do
    TUI_SELECTED[$i]=1
  done
}

tui::draw() {
  local cursor="$1"
  local count=${#TUI_LABELS[@]}

  # Move cursor to top of menu area
  tput cup 6 0

  printf "${BOLD}${PURPLE}  ┌─────────────────────────────────────────────────────────┐${RESET}\n"
  printf "${BOLD}${PURPLE}  │${RESET}  ${BOLD}Select cleanup targets  ${DIM}[↑↓ move · space toggle · a=all · enter run]${RESET}${BOLD}${PURPLE}  │${RESET}\n"
  printf "${BOLD}${PURPLE}  ├─────────────────────────────────────────────────────────┤${RESET}\n"

  for (( i=0; i<count; i++ )); do
    local label="${TUI_LABELS[$i]}"
    local checked=" "
    local row_color="${RESET}"
    local check_color="${DIM}"

    if (( TUI_SELECTED[i] == 1 )); then
      checked="✔"
      check_color="${GREEN}"
    fi

    if (( i == cursor )); then
      row_color="${BOLD}${CYAN}"
      printf "${BOLD}${PURPLE}  │${RESET}  ${BOLD}${CYAN}▶${RESET} [${check_color}%s${RESET}] ${row_color}%-52s${RESET}${BOLD}${PURPLE}│${RESET}\n" \
        "$checked" "$label"
    else
      printf "${BOLD}${PURPLE}  │${RESET}    [${check_color}%s${RESET}] %-52s${BOLD}${PURPLE}│${RESET}\n" \
        "$checked" "$label"
    fi
  done

  printf "${BOLD}${PURPLE}  ├─────────────────────────────────────────────────────────┤${RESET}\n"

  local sel_count=0
  for v in "${TUI_SELECTED[@]}"; do (( sel_count += v )); done

  local mode_str="  ${DIM}Mode: DRY-RUN  (--yes to run live)${RESET}"
  [[ "$SKIP_CONFIRM" == "true" ]] && mode_str="  ${RED}Mode: LIVE — files will be deleted${RESET}"
  printf "${BOLD}${PURPLE}  │${RESET}%s\n" "$mode_str"
  printf "${BOLD}${PURPLE}  │${RESET}  ${DIM}%d module(s) selected${RESET}\n" "$sel_count"
  printf "${BOLD}${PURPLE}  │${RESET}  ${DIM}q = quit · d = dry-run toggle · s = smart scan first${RESET}\n"
  printf "${BOLD}${PURPLE}  └─────────────────────────────────────────────────────────┘${RESET}\n"
}

tui::run() {
  # Only works in a real TTY
  if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
    log::warn "TUI requires an interactive terminal. Use flags instead."
    return 1
  fi

  tui::init_selected
  tui::select_all  # default: all selected

  local cursor=0
  local count=${#TUI_LABELS[@]}

  # Save terminal state
  tput smcup 2>/dev/null
  tput civis 2>/dev/null
  clear

  # Print banner at top
  printf "\n${BOLD}${PURPLE}"
  printf '  ██████╗ ███████╗██╗     ██╗██╗     ███████╗ ██████╗██╗  ██╗███████╗\n'
  printf '  ██╔══██╗██╔════╝██║     ██║██║     ██╔════╝██╔════╝██║  ██║██╔════╝\n'
  printf '  ██║  ██║█████╗  ██║     ██║██║     █████╗  ██║     ███████║█████╗  \n'
  printf '  ██║  ██║██╔══╝  ██║     ██║██║     ██╔══╝  ██║     ██╔══██║██╔══╝  \n'
  printf '  ██████╔╝███████╗███████╗██║███████╗███████╗╚██████╗██║  ██║███████╗\n'
  printf '  ╚═════╝ ╚══════╝╚══════╝╚═╝╚══════╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚══════╝\n'
  printf "${RESET}${DIM}                                    by youcef — v%s${RESET}\n" "$VERSION"

  tui::draw "$cursor"

  local quit=false
  local confirmed=false

  while [[ "$quit" == "false" && "$confirmed" == "false" ]]; do
    # Read a single key (including escape sequences)
    local key
    IFS= read -r -s -n1 key
    if [[ "$key" == $'\x1b' ]]; then
      IFS= read -r -s -n2 -t 0.1 key2
      key+="$key2"
    fi

    case "$key" in
      $'\x1b[A'|k)  # Up arrow / k
        (( cursor > 0 )) && cursor=$(( cursor - 1 ))
        ;;
      $'\x1b[B'|j)  # Down arrow / j
        (( cursor < count - 1 )) && cursor=$(( cursor + 1 ))
        ;;
      ' ')  # Space — toggle
        tui::toggle "$cursor"
        ;;
      a|A)  # Select all
        tui::select_all
        ;;
      d|D)  # Toggle dry-run
        if [[ "$DRY_RUN" == "true" ]]; then
          DRY_RUN=false
          SKIP_CONFIRM=true
        else
          DRY_RUN=true
          SKIP_CONFIRM=false
        fi
        ;;
      s|S)  # Smart scan
        tput rmcup 2>/dev/null
        tput cnorm 2>/dev/null
        smart_scan::run
        printf "\n  ${DIM}Press any key to return to menu...${RESET}"
        read -r -s -n1
        tput smcup 2>/dev/null
        tput civis 2>/dev/null
        clear
        printf "\n" # redraw banner area
        tui::draw "$cursor"
        continue
        ;;
      ''|$'\n')  # Enter — confirm
        local any=false
        for v in "${TUI_SELECTED[@]}"; do (( v == 1 )) && any=true && break; done
        if [[ "$any" == "true" ]]; then
          confirmed=true
        fi
        ;;
      q|Q)  # Quit
        quit=true
        ;;
    esac

    [[ "$confirmed" == "false" && "$quit" == "false" ]] && tui::draw "$cursor"
  done

  # Restore terminal
  tput rmcup 2>/dev/null
  tput cnorm 2>/dev/null

  if [[ "$quit" == "true" ]]; then
    log::info "Cancelled."
    exit 0
  fi

  # Apply selected flags
  for (( i=0; i<count; i++ )); do
    if (( TUI_SELECTED[i] == 1 )); then
      eval "export ${TUI_FLAGS[$i]}=true"
    fi
  done

  return 0
}
