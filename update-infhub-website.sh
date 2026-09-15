#!/usr/bin/env bash
# ============================================================
# INFHUB Homelab — Hardened Update Script
# ============================================================
# Safely updates the Docker Compose stack while preventing the
# old PHP container from stealing the Next.js host port.
#
# Usage:
#   bash update-infhub-website.sh              # Interactive update
#   bash update-infhub-website.sh --yes        # Non-interactive update
#   bash update-infhub-website.sh --restart-only --yes
#   bash update-infhub-website.sh --check-only
#   bash update-infhub-website.sh --help
# ============================================================

set -Eeuo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
ENV_FILE="$SCRIPT_DIR/.env"
BACKUP_DIR="$SCRIPT_DIR/backups"
WEB_HOST_PORT="8080"
LEGACY_SERVICE="php-app"
LEGACY_CONTAINER_PREFIX="infhub-website-php-app"
SERVICES=(web db inspircd lounge)

AUTO_YES=false
RESTART_ONLY=false
SKIP_BACKUP=false
CHECK_ONLY=false
SKIP_HEALTHCHECK=false
TIMEOUT_SECONDS=120

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Safely update or restart the INFHUB Docker Compose stack.

Options:
  --yes              Non-interactive mode; accept safe defaults
  --restart-only     Restart existing images without pulling or rebuilding
  --skip-backup      Do not offer a MariaDB backup before updating
  --check-only       Validate Compose and port ownership without changing containers
  --skip-healthcheck Skip service health verification after startup
  --timeout SECONDS  Health-check timeout (default: 120)
  -h, --help         Show this help

Safety guarantees:
  - The active web service is Next.js on host port $WEB_HOST_PORT.
  - Known legacy PHP containers are removed before the new web container starts.
  - An unknown process/container owning port $WEB_HOST_PORT is never removed or replaced.
  - Persistent volumes and data are preserved.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --yes)
            AUTO_YES=true
            ;;
        --restart-only)
            RESTART_ONLY=true
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            ;;
        --check-only)
            CHECK_ONLY=true
            ;;
        --skip-healthcheck)
            SKIP_HEALTHCHECK=true
            ;;
        --timeout)
            shift
            if [[ -z "${1:-}" || ! "$1" =~ ^[0-9]+$ ]]; then
                echo "[ERR] --timeout requires a positive integer" >&2
                exit 1
            fi
            TIMEOUT_SECONDS="$1"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "[ERR] Unknown argument: $arg" >&2
            echo "Run '$0 --help' for usage." >&2
            exit 1
            ;;
    esac
done

# ------------------------------------------------------------
# Output helpers
# ------------------------------------------------------------

step() {
    printf '\n\033[1;31m[%s] %s\033[0m\n' "$(date '+%H:%M:%S')" "$1"
}

ok() {
    printf '  \033[1;31m[OK]\033[0m %s\n' "$1"
}

warn() {
    printf '  \033[1;31m[WARN]\033[0m %s\n' "$1"
}

err() {
    printf '  \033[1;31m[ERR]\033[0m %s\n' "$1"
}

info() {
    printf '  \033[1;31m[INFO]\033[0m %s\n' "$1"
}

ask() {
    local prompt="$1"
    local default="${2:-Y}"
    local response

    if [[ "$AUTO_YES" == true ]]; then
        printf '%s\n' "$default"
        return 0
    fi

    while true; do
        if [[ "$default" == "Y" ]]; then
            printf '%s [Y/n] (default: Y) ' "$prompt" >&2
        else
            printf '%s [y/N] (default: N) ' "$prompt" >&2
        fi

        if ! IFS= read -r response; then
            printf '\n' >&2
            exit 1
        fi

        case "$response" in
            y|Y|yes|YES|Yes)
                printf '%s\n' "Y"
                return 0
                ;;
            n|N|no|NO|No)
                printf '%s\n' "N"
                return 0
                ;;
            "")
                printf '%s\n' "$default"
                return 0
                ;;
            *)
                printf 'Please answer Y or N.\n' >&2
                ;;
        esac
    done
}

# ------------------------------------------------------------
# Compose wrapper and preflight
# ------------------------------------------------------------

compose() {
    docker compose -f "$COMPOSE_FILE" "$@"
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        err "Required command is not available: $1"
        exit 1
    fi
}

step "=== INFHUB Homelab Update ==="
info "Project directory: $SCRIPT_DIR"

require_command docker
require_command grep

if ! docker compose version >/dev/null 2>&1; then
    err "Docker Compose plugin is not available."
    exit 1
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
    err "docker-compose.yml not found: $COMPOSE_FILE"
    exit 1
fi

step "Validating Docker Compose configuration..."
if compose config --quiet; then
    ok "Docker Compose configuration is valid"
else
    err "Docker Compose configuration is invalid."
    exit 1
fi

# ------------------------------------------------------------
# Legacy container cleanup
# ------------------------------------------------------------

container_is_legacy_web() {
    local container_id="$1"
    local service=""
    local name=""
    local image=""

    service="$(docker inspect --format '{{index .Config.Labels "com.docker.compose.service"}}' "$container_id" 2>/dev/null || true)"
    name="$(docker inspect --format '{{.Name}}' "$container_id" 2>/dev/null || true)"
    name="${name#/}"
    image="$(docker inspect --format '{{.Config.Image}}' "$container_id" 2>/dev/null || true)"

    [[ "$service" == "$LEGACY_SERVICE" ]] && return 0
    [[ "$name" == "$LEGACY_CONTAINER_PREFIX"* && "$image" == *php* ]] && return 0
    return 1
}

remove_legacy_web_containers() {
    local container_id=""
    local legacy_name=""
    local removed=0

    while IFS= read -r container_id; do
        [[ -z "$container_id" ]] && continue

        if container_is_legacy_web "$container_id"; then
            legacy_name="$(docker inspect --format '{{.Name}}' "$container_id" 2>/dev/null || true)"
            legacy_name="${legacy_name#/}"
            warn "Removing orphaned legacy web container: $legacy_name"
            docker rm -f "$container_id" >/dev/null
            removed=$((removed + 1))
        fi
    done < <(docker ps -aq 2>/dev/null || true)

    if [[ "$removed" -gt 0 ]]; then
        ok "Removed $removed orphaned legacy web container(s)"
    else
        info "No orphaned legacy web container found"
    fi
}

stop_current_web_container() {
    local web_id=""

    web_id="$(compose ps -q web 2>/dev/null || true)"
    if [[ -n "$web_id" ]]; then
        info "Stopping the current Next.js web container before rebinding port $WEB_HOST_PORT"
        compose stop web >/dev/null 2>&1 || true
    fi
}

assert_port_is_free() {
    local owner=""
    local listener=""

    owner="$(docker ps --format '{{.Names}}|{{.Ports}}' 2>/dev/null | grep -E "(${WEB_HOST_PORT}->|:${WEB_HOST_PORT}/tcp)" || true)"

    if [[ -n "$owner" ]]; then
        err "Host port $WEB_HOST_PORT is still occupied by a Docker container:"
        printf '    %s\n' "$owner"
        err "Refusing to start a replacement container while another owner holds the port."
        exit 1
    fi

    if command -v ss >/dev/null 2>&1; then
        listener="$(ss -ltnp 2>/dev/null | grep -E ":${WEB_HOST_PORT}\\b" || true)"
        if [[ -n "$listener" ]]; then
            err "Host port $WEB_HOST_PORT is still occupied by a host process:"
            printf '    %s\n' "$listener"
            err "Stop the owning process or container before retrying."
            exit 1
        fi
    fi

    ok "Host port $WEB_HOST_PORT is free"
}

if [[ "$CHECK_ONLY" == true ]]; then
    step "Running read-only safety check..."
    assert_port_is_free
    ok "Configuration and port ownership checks passed"
    exit 0
fi

# ------------------------------------------------------------
# Database backup (optional)
# ------------------------------------------------------------

if [[ "$RESTART_ONLY" != true && "$SKIP_BACKUP" != true ]]; then
    step "Database backup"
    response="$(ask "Create a MariaDB backup before updating?" "Y")"

    if [[ "$response" != "N" && -f "$ENV_FILE" ]]; then
        DB_ROOT_PASS="$(grep '^DB_ROOT_PASSWORD=' "$ENV_FILE" | head -n1 | cut -d'=' -f2- || true)"
        DB_CONTAINER="$(compose ps -q db 2>/dev/null || true)"

        if [[ -n "$DB_ROOT_PASS" && -n "$DB_CONTAINER" ]]; then
            DB_STATUS="$(docker inspect --format '{{.State.Status}}' "$DB_CONTAINER" 2>/dev/null || true)"
            if [[ "$DB_STATUS" == "running" ]]; then
                mkdir -p "$BACKUP_DIR"
                backup_ts="$(date '+%Y-%m-%d_%H%M%S')"
                db_backup="$BACKUP_DIR/database-backup-$backup_ts.sql"

                info "Creating MariaDB backup..."
                info "Output: $db_backup"
                if compose exec -T -e MYSQL_PWD="$DB_ROOT_PASS" db mariadb-dump -u root infhub_database > "$db_backup" && [[ -s "$db_backup" ]]; then
                    ok "Database backup created"
                else
                    warn "Database backup failed or was empty."
                    rm -f "$db_backup"
                fi
            else
                warn "MariaDB is not running; skipping backup."
            fi
        else
            warn "MariaDB backup prerequisites are missing; skipping backup."
        fi
    else
        info "Skipping database backup"
    fi
fi

# ------------------------------------------------------------
# Pull images (update mode only)
# ------------------------------------------------------------

if [[ "$RESTART_ONLY" != true ]]; then
    step "Pulling external Docker images..."
    response="$(ask "Pull latest external images?" "Y")"
    if [[ "$response" != "N" ]]; then
        compose pull db lounge >/dev/null || warn "Image pull failed; continuing with locally available images."
        ok "External image pull attempted"
    else
        info "Skipping image pull"
    fi
fi

# ------------------------------------------------------------
# Safe startup
# ------------------------------------------------------------

step "Preparing safe web-service startup..."
remove_legacy_web_containers
stop_current_web_container
assert_port_is_free

if [[ "$RESTART_ONLY" == true ]]; then
    step "Restarting existing stack..."
    compose up -d --remove-orphans >/dev/null 2>&1
    ok "Stack restarted without rebuilding"
else
    step "Building and starting stack..."
    response="$(ask "Rebuild images and restart?" "Y")"
    if [[ "$response" == "N" ]]; then
        compose up -d --remove-orphans >/dev/null 2>&1
        ok "Stack started without rebuilding"
    else
        compose build --no-cache >/dev/null 2>&1 || warn "Image build failed; continuing with existing images."
        compose up -d --remove-orphans >/dev/null 2>&1
        ok "Stack rebuilt and started (no cache)"
    fi
fi

# ------------------------------------------------------------
# Health verification
# ------------------------------------------------------------

wait_for_service() {
    local service="$1"
    local deadline=$((SECONDS + TIMEOUT_SECONDS))
    local container_id=""
    local status=""
    local health=""

    while (( SECONDS < deadline )); do
        container_id="$(compose ps -q "$service" 2>/dev/null || true)"

        if [[ -n "$container_id" ]]; then
            status="$(docker inspect --format '{{.State.Status}}' "$container_id" 2>/dev/null || true)"

            if [[ "$status" == "exited" || "$status" == "dead" ]]; then
                err "$service is not running (status: $status)"
                return 1
            fi

            if [[ "$status" == "running" ]]; then
                health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_id" 2>/dev/null || echo unknown)"

                case "$health" in
                    healthy)
                        ok "$service is healthy"
                        return 0
                        ;;
                    none)
                        ok "$service is running without a healthcheck"
                        return 0
                        ;;
                    unhealthy)
                        err "$service reports unhealthy"
                        return 1
                        ;;
                    *)
                        sleep 2
                        ;;
                esac
            fi
        fi

        sleep 2
    done

    err "$service did not become ready within ${TIMEOUT_SECONDS}s"
    return 1
}

if [[ "$SKIP_HEALTHCHECK" != true ]]; then
    step "Verifying service health..."
    failed=false

    for service in "${SERVICES[@]}"; do
        if ! wait_for_service "$service"; then
            failed=true
        fi
    done

    if [[ "$failed" == true ]]; then
        step "Diagnostics"
        compose ps || true
        echo
        err "One or more services failed health verification."
        echo "Useful commands:"
        echo "  docker compose -f \"$COMPOSE_FILE\" logs --tail=100 web"
        echo "  docker compose -f \"$COMPOSE_FILE\" logs --tail=100 inspircd"
        echo "  docker compose -f \"$COMPOSE_FILE\" logs --tail=100 lounge"
        exit 1
    fi
else
    warn "Skipping service health verification"
fi

# ------------------------------------------------------------
# Complete
# ------------------------------------------------------------

step "Verifying stack..."
compose ps

step "=== Update Complete ==="
echo
echo "  Services:"
echo "    Web Application    http://localhost:$WEB_HOST_PORT"
echo "    The Lounge IRC     http://localhost:9000"
echo "    InspIRCd Plain     irc://localhost:6667"
echo "    InspIRCd TLS       irc://localhost:6697"
echo
echo "  Project:"
echo "    $SCRIPT_DIR"
echo
echo "  Persistent data was not removed."
echo
