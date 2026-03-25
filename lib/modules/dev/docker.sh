#!/usr/bin/env bash
# lib/modules/dev/docker.sh — Docker container, image, volume, and build cache cleanup

docker::clean() {
  if [[ "$TARGET_DOCKER" != "true" ]]; then
    return 0
  fi

  log::section "Docker"

  if ! command -v docker >/dev/null 2>&1; then
    log::module_result "Docker" "skipped" "" ""
    module::register "Docker" "Developer Tools" 0 0 "skipped" 0 0
    return 0
  fi

  if ! docker info >/dev/null 2>&1; then
    log::warn "Docker daemon is not running — skipping."
    log::module_result "Docker" "skipped" "" ""
    module::register "Docker" "Developer Tools" 0 0 "skipped" 0 0
    return 0
  fi

  local start
  start=$(date +%s)

  if [[ "$DRY_RUN" == "true" ]]; then
    log::info "[dry-run] Docker prune summary:"
    local containers
    containers=$(docker container ls -aq 2>/dev/null | wc -l | tr -d ' ')
    local images
    images=$(docker image ls -q --filter "dangling=true" 2>/dev/null | wc -l | tr -d ' ')
    local volumes
    volumes=$(docker volume ls -q --filter "dangling=true" 2>/dev/null | wc -l | tr -d ' ')
    log::verbose "  Stopped containers: $containers"
    log::verbose "  Dangling images: $images"
    log::verbose "  Dangling volumes: $volumes"
    log::info "[dry-run] Would run: docker system prune -f --volumes"
  else
    log::verbose "Pruning stopped containers..."
    docker container prune -f >/dev/null 2>&1 || true
    log::verbose "Pruning dangling images..."
    docker image prune -f >/dev/null 2>&1 || true
    log::verbose "Pruning dangling volumes..."
    docker volume prune -f >/dev/null 2>&1 || true
    log::verbose "Pruning build cache..."
    docker builder prune -f >/dev/null 2>&1 || true
    log::success "Docker prune complete"
  fi

  local end
  end=$(date +%s)
  local dur=$(( end - start ))
  local status="$([ "$DRY_RUN" == "true" ] && echo "pending" || echo "done")"

  log::module_result "Docker" "$status" "" "$dur"
  module::register "Docker" "Developer Tools" 0 0 "$status" 0 "$dur"
}
