#!/usr/bin/env bash
# lib/profile/profile.sh — Cleanup profiles: developer, designer, student

PROFILE_FILE="${PROFILE_FILE:-$HOME/.config/delileche/profile}"

profile::save() {
  local name="$1"
  mkdir -p "$(dirname "$PROFILE_FILE")"
  echo "$name" > "$PROFILE_FILE"
  log::success "Profile saved: $name"
}

profile::load() {
  if [[ -f "$PROFILE_FILE" ]]; then
    local saved
    saved=$(cat "$PROFILE_FILE")
    echo "$saved"
  else
    echo ""
  fi
}

profile::apply() {
  local name="$1"

  case "$name" in
    developer|dev)
      log::info "Profile: Developer — targeting build artifacts and dev caches"
      TARGET_XCODE=true
      TARGET_DOCKER=true
      TARGET_DEVTOOLS=true
      TARGET_BREW=true
      TARGET_SYSTEM=true
      TARGET_CACHES=true
      TARGET_SNAPSHOTS=false
      TARGET_MAIL=false
      TARGET_OPTIMIZE=true
      ;;
    designer)
      log::info "Profile: Designer — targeting app caches, large files, Downloads"
      TARGET_CACHES=true
      TARGET_SYSTEM=true
      TARGET_MAIL=true
      TARGET_BREW=true
      TARGET_XCODE=false
      TARGET_DOCKER=false
      TARGET_DEVTOOLS=false
      TARGET_OPTIMIZE=false
      TARGET_SNAPSHOTS=false
      ;;
    student)
      log::info "Profile: Student — targeting Downloads, system junk, browser caches"
      TARGET_SYSTEM=true
      TARGET_CACHES=true
      TARGET_MAIL=false
      TARGET_BREW=false
      TARGET_XCODE=false
      TARGET_DOCKER=false
      TARGET_DEVTOOLS=false
      TARGET_OPTIMIZE=false
      TARGET_SNAPSHOTS=true
      ;;
    *)
      log::error "Unknown profile: $name. Available: developer, designer, student"
      return 1
      ;;
  esac

  profile::save "$name"
}

profile::show_menu() {
  local bar
  bar=$(printf '─%.0s' $(seq 1 50))
  printf "\n  ${BOLD}${PURPLE}%s${RESET}\n" "$bar"
  printf "  ${BOLD}${MAGENTA}  Choose a cleanup profile${RESET}\n"
  printf "  ${BOLD}${PURPLE}%s${RESET}\n\n" "$bar"
  printf "  ${BOLD}[1]${RESET} ${CYAN}developer${RESET}   — Xcode, Docker, node_modules, brew, build caches\n"
  printf "  ${BOLD}[2]${RESET} ${CYAN}designer${RESET}    — App caches, Mail, brew, system junk\n"
  printf "  ${BOLD}[3]${RESET} ${CYAN}student${RESET}     — System, browser caches, snapshots\n"
  printf "\n  ${DIM}Enter choice [1-3] or press Enter to skip: ${RESET}"

  local choice
  read -r choice
  case "$choice" in
    1) profile::apply "developer" ;;
    2) profile::apply "designer" ;;
    3) profile::apply "student" ;;
    *) log::info "No profile selected." ;;
  esac
}

profile::describe() {
  local saved
  saved=$(profile::load)
  if [[ -n "$saved" ]]; then
    printf "  ${DIM}Active profile:${RESET} ${BOLD}${CYAN}%s${RESET}\n" "$saved"
  fi
}
