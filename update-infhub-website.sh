#!/bin/sh

# ============================================================
# INFHUB Homelab — Update Script
# ============================================================
# Updates the complete INFHUB Docker Compose stack.
#
# Managed services:
#   - php-app
#   - db
#   - inspircd
#   - lounge
#
# Usage:
#   sh update-infhub-website.sh
#   sh update-infhub-website.sh --yes
#   sh update-infhub-website.sh --help
#
# Safety:
#   - Never removes Docker volumes
#   - Never runs "docker compose down -v"
#   - Never deletes IRC configuration
#   - Never deletes The Lounge data
#   - Database backup is optional
# ============================================================

set -eu

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
ENV_FILE="$SCRIPT_DIR/.env"
BACKUP_DIR="$SCRIPT_DIR/backups"

cd "$SCRIPT_DIR"

# ------------------------------------------------------------
# Flags
# ------------------------------------------------------------

AUTO_YES=false

for arg in "$@"; do
    case "$arg" in
        --yes)
            AUTO_YES=true
            ;;

        -h|--help)
            cat <<EOF
Usage: $0 [OPTIONS]

Update the complete INFHUB Docker Compose stack.

Prompts accept Y/yes or N/no. Press Enter to use the displayed default.

Options:
  --yes       Non-interactive mode
  -h, --help  Show this help

The update performs:
  1. Docker/Compose preflight checks
  2. Optional MariaDB backup
  3. Docker image pull
  4. Docker Compose rebuild
  5. Container restart
  6. Service health verification

Persistent Docker volumes and IRC/The Lounge configuration
are never deliberately removed by this script.
EOF
            exit 0
            ;;

        *)
            echo "[ERR] Unknown argument: $arg"
            echo "Run '$0 --help' for usage."
            exit 1
            ;;
    esac
done

# ------------------------------------------------------------
# Output helpers
# ------------------------------------------------------------

step() {
    echo
    echo -e "\033[1;36m[$(date '+%H:%M:%S')] $1\033[0m"
}

ok() {
    echo -e "  \033[1;32m[OK]\033[0m $1"
}

warn() {
    echo -e "  \033[1;33m[WARN]\033[0m $1"
}

err() {
    echo -e "  \033[1;31m[ERR]\033[0m $1"
}

info() {
    echo -e "  \033[1;37m[INFO]\033[0m $1"
}

ask() {
    prompt="$1"
    default="${2:-Y}"
    display_default="[Y/N] (default: $default)"

    if [ "$AUTO_YES" = true ]; then
        case "$default" in
            [Yy]*) echo "Y" ;;
            *) echo "N" ;;
        esac
        return
    fi

    while true; do
        printf "%s %s " "$prompt" "$display_default"
        IFS= read -r response || exit 1

        case "$response" in
            [yY]|[yY][eE][sS])
                echo "Y"
                return
                ;;
            [nN]|[nN][oO])
                echo "N"
                return
                ;;
            "")
                case "$default" in
                    [Yy]*) echo "Y" ;;
                    *) echo "N" ;;
                esac
                return
                ;;
            *)
                echo "Please answer Y or N." >&2
                ;;
        esac
    done
}

# ------------------------------------------------------------
# Preflight
# ------------------------------------------------------------

step "=== INFHUB Homelab Update ==="

if ! command -v docker >/dev/null 2>&1; then
    err "Docker is not installed or not available in PATH."
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    err "Docker Compose plugin is not available."
    exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    err "docker-compose.yml not found:"
    echo "  $COMPOSE_FILE"
    exit 1
fi

ok "Docker available"
ok "Docker Compose available"
ok "Compose file found"

# Validate Compose before doing anything destructive-ish.

step "Validating Docker Compose configuration..."

if docker compose -f "$COMPOSE_FILE" config --quiet; then
    ok "Docker Compose configuration is valid"
else
    err "Docker Compose configuration is invalid."
    exit 1
fi

# ------------------------------------------------------------
# Database backup
# ------------------------------------------------------------

step "Database backup"

response=$(ask "  Create a database backup before updating?" "Y")

case "$response" in
    [nN]*)

    mkdir -p "$BACKUP_DIR"

    backup_ts="$(date '+%Y-%m-%d_%H%M%S')"
    db_backup="$BACKUP_DIR/database-backup-$backup_ts.sql"

    if [ ! -f "$ENV_FILE" ]; then
        warn ".env not found; cannot automatically determine DB root password."
        info "Skipping database backup."
    else
        DB_ROOT_PASS="$(
            grep '^DB_ROOT_PASSWORD=' "$ENV_FILE" \
                | head -n1 \
                | cut -d'=' -f2-
        )"

        if [ -z "$DB_ROOT_PASS" ]; then
            warn "DB_ROOT_PASSWORD is not defined in .env."
            info "Skipping database backup."
        else

            # Make sure the DB service exists/runs.
            if docker compose -f "$COMPOSE_FILE" ps --status running db \
                --format '{{.Name}}' | grep -q .; then

                info "Creating MariaDB backup..."

                if docker compose -f "$COMPOSE_FILE" exec -T \
                    -e MYSQL_PWD="$DB_ROOT_PASS" \
                    db \
                    mariadb-dump \
                    -u root \
                    infhub_database \
                    > "$db_backup"; then

                    if [ -s "$db_backup" ]; then
                        ok "Database backed up:"
                        echo "    $db_backup"
                    else
                        warn "Backup file is empty."
                        rm -f "$db_backup"
                    fi

                else
                    warn "Database backup failed."
                    rm -f "$db_backup"
                fi

            else
                warn "MariaDB container is not currently running."
                info "Skipping database backup."
            fi
        fi
    fi
else
    info "Skipping database backup"
fi

# ------------------------------------------------------------
# Pull images
# ------------------------------------------------------------

step "Pulling latest Docker images..."

response=$(ask "  Pull latest images (docker compose pull)?" "Y")

case "$response" in
    [nN]*)

    docker compose \
        -f "$COMPOSE_FILE" \
        pull

    ok "Docker images pulled"

else
    info "Skipping image pull"
fi

# ------------------------------------------------------------
# Rebuild and restart
# ------------------------------------------------------------

step "Rebuilding and restarting the stack..."

response=$(ask \
    "  Rebuild images and restart (docker compose up -d --build)?" \
    "Y"
)

case "$response" in
    [nN]*)

    docker compose \
        -f "$COMPOSE_FILE" \
        up -d --build

    ok "Stack rebuilt and started"

else

    response=$(ask \
        "  Restart without rebuilding (docker compose up -d)?" \
        "Y"
    )

    case "$response" in
        [nN]*)

        docker compose \
            -f "$COMPOSE_FILE" \
            up -d

        ok "Stack started"

    else
        info "Skipping restart"
    fi
fi

# ------------------------------------------------------------
# Wait for services
# ------------------------------------------------------------

step "Waiting for services..."

# Give Compose a moment to create/start containers.

sleep 3

services=(
    "db"
    "inspircd"
    "lounge"
    "php-app"
)

failed=false

for service in "${services[@]}"; do

    info "Checking $service..."

    healthy=false

    for ((i=1; i<=60; i++)); do

        container_id="$(
            docker compose \
                -f "$COMPOSE_FILE" \
                ps -q "$service" 2>/dev/null || true
        )"

        if [[ -z "$container_id" ]]; then
            sleep 2
            continue
        fi

        status="$(
            docker inspect \
                --format '{{.State.Status}}' \
                "$container_id" \
                2>/dev/null || true
        )"

        if [[ "$status" != "running" ]]; then
            if [[ "$status" == "exited" || "$status" == "dead" ]]; then
                warn "$service is not running (status: $status)"
                failed=true
                break
            fi

            sleep 2
            continue
        fi

        health="$(
            docker inspect \
                --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
                "$container_id" \
                2>/dev/null || echo "unknown"
        )"

        case "$health" in
            healthy)
                ok "$service healthy"
                healthy=true
                break
                ;;

            none)
                ok "$service running (no healthcheck)"
                healthy=true
                break
                ;;

            unhealthy)
                warn "$service reports unhealthy"
                failed=true
                break
                ;;

            starting|unknown)
                sleep 2
                ;;
        esac
    done

    if [[ "$healthy" != true && "$failed" != true ]]; then
        warn "$service did not become ready within 120 seconds"
        failed=true
    fi
done

# ------------------------------------------------------------
# Final verification
# ------------------------------------------------------------

step "Verifying stack..."

docker compose \
    -f "$COMPOSE_FILE" \
    ps

echo

if [[ "$failed" == true ]]; then

    warn "One or more services failed health verification."
    echo
    echo "Useful diagnostics:"
    echo "  docker compose -f \"$COMPOSE_FILE\" ps"
    echo "  docker compose -f \"$COMPOSE_FILE\" logs --tail=100"
    echo "  docker compose -f \"$COMPOSE_FILE\" logs inspircd"
    echo "  docker compose -f \"$COMPOSE_FILE\" logs lounge"

    exit 1
fi

ok "All services passed verification"

# ------------------------------------------------------------
# Service information
# ------------------------------------------------------------

step "=== Update Complete ==="

echo
echo "  Services:"
echo "    Web Application    http://localhost:8080"
echo "    The Lounge IRC     http://localhost:9000"
echo "    InspIRCd Plain     irc://localhost:6667"
echo "    InspIRCd TLS       irc://localhost:6697"
echo
echo "  Project:"
echo "    $SCRIPT_DIR"
echo
echo "  Backups:"
echo "    $BACKUP_DIR"
echo
echo "  Persistent data was not removed."
echo