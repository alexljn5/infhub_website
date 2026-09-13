#!/usr/bin/env bash
# ============================================================
# INFHUB Homelab — Stop Script
# ============================================================
# Stops the complete INFHUB Docker Compose stack:
#   - php-app: Apache + PHP 8.4 website
#   - db: MariaDB 11
#   - inspircd: InspIRCd 4.x IRC server
#   - lounge: The Lounge IRC web client
#
# Data volumes are preserved — databases, IRC configs, and
# TheLounge data survive container recreation.
#
# Usage:
#   bash stop-infhub-website.sh            # Interactive stop
#   bash stop-infhub-website.sh --force    # Stop without confirmation
#   bash stop-infhub-website.sh --help     # Show help
# ============================================================

set -euo pipefail

# --- Absolute Paths ---
SCRIPT_DIR="/home/alexljn5/INFHUB/infhub-website"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
BACKUP_DIR="$SCRIPT_DIR/backups"

# --- Flags ---
FORCE=false

# --- Parse arguments ---
for arg in "$@"; do
    case "$arg" in
        --force)       FORCE=true ;;
        -h|--help)
            cat <<EOF
Usage: bash stop-infhub-website.sh [--force] [--help]

  Stop the complete INFHUB stack (website, database, InspIRCd, TheLounge).
  Data volumes are preserved.

  Options:
    --force        Stop without confirmation prompts
    -h, --help     Show this help message

  Examples:
    bash stop-infhub-website.sh            # Interactive stop
    bash stop-infhub-website.sh --force    # Quick non-interactive stop
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
    if [[ "$FORCE" == true ]]; then
        echo "$default"
    else
        read -rp "$prompt [$default] " response
        echo "${response:-$default}"
    fi
}

# --- Pre-flight ---
step "=== INFHUB Homelab Stop ==="

if ! command -v docker &>/dev/null; then
    err "Docker is not installed or not in PATH."
    exit 1
fi

if ! command -v docker compose &>/dev/null; then
    err "Docker Compose plugin is not available."
    exit 1
fi

# --- Check if anything is running ---
step "Checking running containers..."
running=$(docker compose -f "$COMPOSE_FILE" ps --format json 2>/dev/null || echo "")
if [[ -z "$running" || "$running" == "[]" ]]; then
    info "No INFHUB containers are currently running via Compose."
    # Check for orphaned containers
    for container in infhub_lounge infhub-website-php-app-1 infhub-website-db-1 infhub-website-inspircd-1; do
        if docker inspect "$container" &>/dev/null 2>&1; then
            info "Found orphaned container: $container"
        fi
    done
    exit 0
fi

ok "Found running containers:"
docker compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker compose -f "$COMPOSE_FILE" ps
echo ""

# --- Confirm ---
response=$(ask "  Stop all INFHUB containers? (data volumes preserved)" "Y")
if [[ "$response" =~ ^[nN] ]]; then
    info "Aborted."
    exit 0
fi

# --- Stop ---
step "Stopping containers..."
docker compose -f "$COMPOSE_FILE" down
ok "All INFHUB containers stopped."

echo ""
info "Data volumes are preserved:"
echo "    Database data:     db-data volume"
echo "    InspIRCd data:     inspircd-data volume"
echo "    TheLounge config:  /home/alexljn5/.thelounge"
echo "    InspIRCd config:   /home/alexljn5/INFHUB/inf_irc/inspircd/run"
echo ""
info "Backups are in: $BACKUP_DIR"
echo ""
info "To start again: bash start-infhub-website.sh"
info "To remove all data: docker compose -f $COMPOSE_FILE down -v"
echo ""
ok "Done."
