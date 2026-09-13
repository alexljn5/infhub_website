#!/usr/bin/env bash
# ============================================================
# INFHUB Homelab — Stop Script
# ============================================================
# Stops the INFHUB Docker stack gracefully.
# Data volumes are preserved — databases and lounge config survive.
#
# Usage:
#   ./stop-infhub-website.sh            # Interactive stop
#   ./stop-infhub-website.sh --force   # Stop without confirmation
#   ./stop-infhub-website.sh --help    # Show help
# ============================================================

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Flags ---
FORCE=false

# --- Parse arguments ---
for arg in "$@"; do
    case "$arg" in
        --force)       FORCE=true ;;
        -h|--help)
            cat <<EOF
Usage: ./stop-infhub-website.sh [--force] [--help]

  Stop the INFHUB homelab stack (php-app, db, lounge).
  Data volumes are preserved.

  Options:
    --force        Stop without confirmation prompts
    -h, --help     Show this help message

  Examples:
    ./stop-infhub-website.sh            # Interactive stop
    ./stop-infhub-website.sh --force    # Quick non-interactive stop
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

cd "$SCRIPT_DIR"

# --- Check if anything is running ---
step "Checking running containers..."
running=$(docker compose ps --format json 2>/dev/null || echo "")
if [[ -z "$running" || "$running" == "[]" ]]; then
    info "No INFHUB containers are currently running."
    exit 0
fi

ok "Found running containers:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker compose ps
echo ""

# --- Confirm ---
response=$(ask "  Stop all INFHUB containers? (data volumes preserved)" "Y")
if [[ "$response" =~ ^[nN] ]]; then
    info "Aborted."
    exit 0
fi

# --- Stop ---
step "Stopping containers..."
docker compose down
ok "All INFHUB containers stopped."

echo ""
info "Data volumes are preserved:"
echo "    Database data:     infhub-website-db-data"
echo "    Lounge data:       infhub-website-lounge-data"
echo ""
info "To start again: ./start-infhub-website.sh"
info "To remove all data: docker compose down -v"
echo ""
ok "Done."
