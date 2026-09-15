#!/bin/sh

# ============================================================
# INFHUB Homelab — Update Script
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
    printf '\n\033[1;36m[%s] %s\033[0m\n' "$(date '+%H:%M:%S')" "$1"
}

ok() {
    printf '  \033[1;32m[OK]\033[0m %s\n' "$1"
}

warn() {
    printf '  \033[1;33m[WARN]\033[0m %s\n' "$1"
}

err() {
    printf '  \033[1;31m[ERR]\033[0m %s\n' "$1"
}

info() {
    printf '  \033[1;37m[INFO]\033[0m %s\n' "$1"
}

# ------------------------------------------------------------
# Prompt helper
#
# IMPORTANT:
# Prompt goes to stderr because the function's stdout is captured
# by response=$(ask ...). Only Y/N is allowed onto stdout.
# ------------------------------------------------------------

ask() {
    prompt="$1"
    default="${2:-Y}"

    if [ "$default" = "Y" ]; then
        display_default="[Y/n] (default: Y)"
    else
        display_default="[y/N] (default: N)"
    fi

    if [ "$AUTO_YES" = true ]; then
        if [ "$default" = "Y" ]; then
            printf '%s\n' "Y"
        else
            printf '%s\n' "N"
        fi
        return 0
    fi

    while true; do
        printf '%s %s ' "$prompt" "$display_default" >&2

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
                printf '%s\n' "Please answer Y or N." >&2
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

# ------------------------------------------------------------
# Validate Compose
# ------------------------------------------------------------

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

if [ "$response" = "N" ]; then

    info "Skipping database backup"

else

    mkdir -p "$BACKUP_DIR"

    backup_ts="$(date '+%Y-%m-%d_%H%M%S')"
    db_backup="$BACKUP_DIR/database-backup-$backup_ts.sql"

    if [ ! -f "$ENV_FILE" ]; then

        warn ".env not found; cannot determine DB root password."
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

            # Check whether the db service currently has a running
            # container.
            DB_CONTAINER="$(
                docker compose \
                    -f "$COMPOSE_FILE" \
                    ps -q db 2>/dev/null || true
            )"

            if [ -z "$DB_CONTAINER" ]; then

                warn "MariaDB container does not currently exist."
                info "Skipping database backup."

            else

                DB_STATUS="$(
                    docker inspect \
                        --format '{{.State.Status}}' \
                        "$DB_CONTAINER" \
                        2>/dev/null || true
                )"

                if [ "$DB_STATUS" != "running" ]; then

                    warn "MariaDB container is not running."
                    info "Skipping database backup."

                else

                    info "Creating MariaDB backup..."
                    info "Output: $db_backup"

                    if docker compose \
                        -f "$COMPOSE_FILE" \
                        exec -T \
                        -e MYSQL_PWD="$DB_ROOT_PASS" \
                        db \
                        mariadb-dump \
                        -u root \
                        infhub_database \
                        > "$db_backup"; then

                        if [ -s "$db_backup" ]; then
                            ok "Database backup created"
                            echo "    $db_backup"
                        else
                            warn "Backup file is empty."
                            rm -f "$db_backup"
                        fi

                    else

                        warn "Database backup command failed."
                        rm -f "$db_backup"

                    fi
                fi
            fi
        fi
    fi
fi

# ------------------------------------------------------------
# Pull images
# ------------------------------------------------------------

step "Pulling latest Docker images..."

response=$(ask "  Pull latest images (docker compose pull)?" "Y")

if [ "$response" = "N" ]; then

    info "Skipping image pull"

else

    docker compose \
        -f "$COMPOSE_FILE" \
        pull

    ok "Docker images pulled"

fi

# ------------------------------------------------------------
# Rebuild and restart
# ------------------------------------------------------------

step "Rebuilding and restarting the stack..."

response=$(ask \
    "  Rebuild images and restart (docker compose up -d --build)?" \
    "Y"
)

if [ "$response" = "N" ]; then

    response=$(ask \
        "  Restart without rebuilding (docker compose up -d)?" \
        "Y"
    )

    if [ "$response" = "N" ]; then

        info "Skipping restart"

    else

        docker compose \
            -f "$COMPOSE_FILE" \
            up -d

        ok "Stack started"

    fi

else

    docker compose \
        -f "$COMPOSE_FILE" \
        up -d --build

    ok "Stack rebuilt and started"

fi

# ------------------------------------------------------------
# Wait for services
# ------------------------------------------------------------

step "Waiting for services..."

sleep 3

services="web db inspircd lounge"
failed=false

for service in $services; do

    info "Checking $service..."

    healthy=false
    i=1

    while [ "$i" -le 60 ]; do

        container_id="$(
            docker compose \
                -f "$COMPOSE_FILE" \
                ps -q "$service" 2>/dev/null || true
        )"

        if [ -z "$container_id" ]; then
            sleep 2
            i=$((i + 1))
            continue
        fi

        status="$(
            docker inspect \
                --format '{{.State.Status}}' \
                "$container_id" \
                2>/dev/null || true
        )"

        if [ "$status" = "exited" ] || [ "$status" = "dead" ]; then
            warn "$service is not running (status: $status)"
            failed=true
            break
        fi

        if [ "$status" != "running" ]; then
            sleep 2
            i=$((i + 1))
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
                i=$((i + 1))
                ;;

            *)
                sleep 2
                i=$((i + 1))
                ;;
        esac

    done

    if [ "$healthy" != true ] && [ "$failed" != true ]; then
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

if [ "$failed" = true ]; then

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
# Complete
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