#!/usr/bin/env bash
# ============================================================
# INFHUB Homelab — Update Script
# ============================================================
# Updates the complete INFHUB Docker Compose stack:
#   - Pulls latest Docker images
#   - Rebuilds and restarts containers
#   - Preserves all persistent data and configurations
#
# Usage:
#   ./update-infhub-website.sh          # Interactive update
#   ./update-infhub-website.sh --yes    # Non-interactive
#   ./update-infhub-website.sh --help   # Show help
#
# Notes:
#   - Never uses destructive volume removal
#   - Never deletes existing IRC configuration/data
#   - Creates database backup before updating
# ============================================================

set -euo pipefail

# --- Absolute Paths ---
SCRIPT_DIR="/home/alexljn5/INFHUB/infhub-website"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
ENV_FILE="$SCRIPT_DIR/.env"
BACKUP_DIR="$SCRIPT_DIR/backups"

# --- Flags ---
AUTO_YES=false

# --- Parse arguments ---
for arg in "$@"; do
    case "$arg" in
        --yes)         AUTO_YES=true ;;
        -h|--help)
            cat <<EOF
Usage: ./update-infhub-website.sh [--yes] [--help]

  Update the complete INFHUB stack:
  1. Pull latest Docker images
  2. Rebuild and restart containers
  3. Preserve all persistent data

  Options:
    --yes      Non-interactive: accept all defaults
    -h, --help Show this help message

  Examples:
    ./update-infhub-website.sh              # Interactive update
    ./update-infhub-website.sh --yes        # Quick non-interactive update
EOF
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Run with --help for usage."
            exit 1
            ;;
    esac
done

# --- Helper Functions ---
step()  { echo -e "\n\033[1;36m[$(date '+%H:%M:%S')] $1\033[0m"; }
ok()    { echo -e "  \033[1;32m[OK]\033[0m $1"; }
warn()  { echo -e "  \033[1;33m[WARN]\033[0m $1"; }
err()   { echo -e "  \033[1;31m[ERR]\033[0m $1"; }
info()  { echo -e "  \033[1;37m[INFO]\033[0m $1"; }

ask() {
    local prompt="$1"
    local default="${2:-Y}"
    if [[ "$AUTO_YES" == true ]]; then
        echo "$default"
    else
        read -rp "$prompt [$default] " response
        echo "${response:-$default}"
    fi
}

# --- Pre-flight ---
step "=== INFHUB Homelab Update ==="

if ! command -v docker &>/dev/null; then
    err "Docker is not installed or not in PATH."
    exit 1
fi

if ! command -v docker compose &>/dev/null; then
    err "Docker Compose plugin is not available."
    exit 1
fi

# --- Step 1: Pull Docker Images ---
step "Pulling latest Docker images..."
response=$(ask "  Pull latest images (docker compose pull)?" "Y")
if [[ ! "$response" =~ ^[nN] ]]; then
    docker compose -f "$COMPOSE_FILE" pull
    ok "Docker images pulled"
else
    info "Skipping image pull"
fi

# --- Step 2: Backup Database ---
step "Backing up database..."
response=$(ask "  Create a database backup before updating?" "Y")
if [[ ! "$response" =~ ^[nN] ]]; then
    mkdir -p "$BACKUP_DIR"
    backup_ts=$(date +%F_%H%M)
    db_backup="$BACKUP_DIR/database-backup-$backup_ts.sql"

    if [[ -f "$ENV_FILE" ]]; then
        DB_ROOT_PASS=$(grep "^DB_ROOT_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2-)
        if [[ -n "$DB_ROOT_PASS" ]]; then
            echo "  Backing up database to $db_backup..."
            docker compose -f "$COMPOSE_FILE" exec -T db mariadb-dump -u root -p"$DB_ROOT_PASS" infhub_database > "$db_backup" 2>/dev/null
            if [[ $? -eq 0 && -s "$db_backup" ]]; then
                ok "Database backed up to $db_backup"
            else
                warn "Database backup failed — check credentials and container status"
                rm -f "$db_backup"
            fi
        else
            warn "DB_ROOT_PASSWORD not found in .env — skipping backup"
        fi
    else
        warn ".env not found — cannot back up database"
    fi
else
    info "Skipping database backup"
fi

# --- Step 3: Rebuild & Restart ---
step "Rebuilding and restarting the stack..."
response=$(ask "  Rebuild images and restart (docker compose up -d --build)?" "Y")
if [[ ! "$response" =~ ^[nN] ]]; then
    docker compose -f "$COMPOSE_FILE" up -d --build
    ok "Stack rebuilt and restarted"
else
    response=$(ask "  Just restart without rebuild (docker compose up -d)?" "Y")
    if [[ ! "$response" =~ ^[nN] ]]; then
        docker compose -f "$COMPOSE_FILE" up -d
        ok "Stack restarted"
    else
        info "Skipping restart"
    fi
fi

# --- Step 4: Wait for Services Health ---
step "Waiting for services to become healthy..."

# Wait for DB
db_healthy=false
elapsed=0
for ((i=0; i<60; i++)); do
    sleep 2
    elapsed=$((elapsed + 2))
    health=$(docker inspect --format='{{.State.Health.Status}}' infhub-website-db-1 2>/dev/null || echo "")
    if [[ "$health" == "healthy" ]]; then
        db_healthy=true
        break
    fi
    container_status=$(docker inspect --format='{{.State.Status}}' infhub-website-db-1 2>/dev/null || echo "")
    if [[ "$container_status" != "running" ]]; then
        err "Database container is not running (status: $container_status)"
        echo "  Check logs: docker compose -f $COMPOSE_FILE logs db"
        exit 1
    fi
done
echo ""
if [[ "$db_healthy" == true ]]; then
    ok "Database healthy after $elapsed seconds"
else
    err "Database did not become healthy within 120 seconds"
    exit 1
fi

# Wait for InspIRCd
inspircd_healthy=false
elapsed=0
for ((i=0; i<60; i++)); do
    sleep 2
    elapsed=$((elapsed + 2))
    health=$(docker inspect --format='{{.State.Health.Status}}' infhub-website-inspircd-1 2>/dev/null || echo "")
    if [[ "$health" == "healthy" ]]; then
        inspircd_healthy=true
        break
    fi
    container_status=$(docker inspect --format='{{.State.Status}}' infhub-website-inspircd-1 2>/dev/null || echo "")
    if [[ "$container_status" != "running" ]]; then
        err "InspIRCd container is not running (status: $container_status)"
        echo "  Check logs: docker compose -f $COMPOSE_FILE logs inspircd"
        exit 1
    fi
done
echo ""
if [[ "$inspircd_healthy" == true ]]; then
    ok "InspIRCd healthy after $elapsed seconds"
else
    warn "InspIRCd did not become healthy within 120 seconds — check logs"
fi

# Wait for Lounge
lounge_healthy=false
elapsed=0
for ((i=0; i<60; i++)); do
    sleep 2
    elapsed=$((elapsed + 2))
    health=$(docker inspect --format='{{.State.Health.Status}}' infhub_lounge 2>/dev/null || echo "")
    if [[ "$health" == "healthy" ]]; then
        lounge_healthy=true
        break
    fi
    container_status=$(docker inspect --format='{{.State.Status}}' infhub_lounge 2>/dev/null || echo "")
    if [[ "$container_status" != "running" ]]; then
        err "Lounge container is not running (status: $container_status)"
        echo "  Check logs: docker compose -f $COMPOSE_FILE logs lounge"
        exit 1
    fi
done
echo ""
if [[ "$lounge_healthy" == true ]]; then
    ok "Lounge healthy after $elapsed seconds"
else
    warn "Lounge did not become healthy within 120 seconds — check logs"
fi

# --- Step 5: Verify Services ---
step "Verifying services..."

php_status=$(docker inspect --format='{{.State.Status}}' infhub-website-php-app-1 2>/dev/null || echo "")
if [[ "$php_status" == "running" ]]; then
    ok "php-app (web) is running"
else
    warn "php-app is not running (status: $php_status)"
fi

# --- Step 6: Display Status ---
step "=== Update Complete ==="
echo ""
docker compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker compose -f "$COMPOSE_FILE" ps
echo ""
echo "  Access your services:"
echo "    Web Application    http://localhost:8080"
echo "    The Lounge IRC     http://localhost:9000"
echo "    InspIRCd Plain     irc://localhost:6667"
echo "    InspIRCd TLS       irc://localhost:6697"
echo ""
echo "  Backups are in: $BACKUP_DIR"
echo ""
echo "  Happy hacking! 🚀"
