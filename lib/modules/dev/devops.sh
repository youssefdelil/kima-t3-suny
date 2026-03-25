#!/usr/bin/env bash
# lib/modules/dev/devops.sh — DevOps nuclear reset: Docker, dev ecosystem deep clean

devops_reset::run() {
  if [[ "$DEVOPS_RESET_MODE" != "true" ]]; then
    return 0
  fi

  log::section "DevOps Reset"
  log::warn "Nuclear DevOps reset mode — this will remove ALL Docker assets and dev caches"

  local start
  start=$(date +%s)

  if [[ "$DRY_RUN" == "true" ]]; then
    log::info "[dry-run] DevOps reset would:"
    log::info "  • docker system prune --all --volumes -f"
    log::info "  • Remove all npm global cache"
    log::info "  • Remove pip cache"
    log::info "  • Remove all Gradle caches"
    if [[ "$INCLUDE_ML_MODELS" == "true" ]]; then
      log::info "  • Remove HuggingFace model cache (~/.cache/huggingface)"
      log::info "  • Remove Ollama models (~/.ollama/models)"
    fi
  else
    # Docker full purge
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
      log::info "Purging all Docker assets..."
      docker system prune --all --volumes -f >/dev/null 2>&1 || true
    fi

    # npm global cache
    if command -v npm >/dev/null 2>&1; then
      log::info "Clearing npm global cache..."
      npm cache clean --force >/dev/null 2>&1 || true
    fi

    # pip cache
    if command -v pip3 >/dev/null 2>&1; then
      log::info "Clearing pip cache..."
      pip3 cache purge >/dev/null 2>&1 || true
    fi

    # Gradle
    if [[ -d "$HOME/.gradle" ]]; then
      log::info "Removing Gradle caches..."
      utils::safe_rm "$HOME/.gradle/caches" "Gradle caches"
      utils::safe_rm "$HOME/.gradle/wrapper" "Gradle wrapper"
    fi

    # ML models
    if [[ "$INCLUDE_ML_MODELS" == "true" ]]; then
      log::info "Removing ML model caches..."
      utils::safe_rm "$HOME/.cache/huggingface" "HuggingFace models"
      utils::safe_rm "$HOME/.ollama/models" "Ollama models"
    fi

    log::success "DevOps reset complete"
  fi

  local end
  end=$(date +%s)
  local dur=$(( end - start ))
  local status="$([ "$DRY_RUN" == "true" ] && echo "pending" || echo "done")"

  log::module_result "DevOps Reset" "$status" "" "$dur"
  module::register "DevOps Reset" "Developer Tools" 0 0 "$status" 0 "$dur"
}
