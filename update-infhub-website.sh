#!/usr/bin/env bash
# ============================================================
# INFHUB Homelab — Update Script
# ============================================================
# Pulls latest code, rebuilds images, and restarts the stack.
# Use this after git changes or when updating dependencies.
#
# Usage:
#   ./update-infhub-website.sh          # Interactive update
#   ./update-infhub-website.sh --yes    # Non-interactive
#   ./update-infhub-website.sh --help   # Show help
# ============================================================

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# --- Flags ---
AUTO_YES=false

# --- Parse arguments ---
for arg in "$@"; do
    case "$arg" in
        --yes)         AUTO_YES=true ;;
        -h|--help)
            cat <<EOF
Usage: ./update-infhub-website.sh [--yes] [--help]

  Update the INFHUB homelab stack:
  1. Pull latest code from git
  2. Pull latest Docker images
  3. Rebuild and restart containers

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

cd "$SCRIPT_DIR"

# --- Step 1: Git Pull ---
step "Pulling latest code..."
if [[ -d "$SCRIPT_DIR/.git" ]]; then
    response=$(ask "  Run git pull?" "Y")
    if [[ ! "$response" =~ ^[nN] ]]; then
        if git pull; then
            ok "Git pull successful"
        else
            warn "Git pull failed — continuing with existing code"
        fi
    fi
else
    info "Not a git repository — skipping"
fi

# --- Step 2: Pull Docker Images ---
step "Pulling latest Docker images..."
response=$(ask "  Pull latest images (docker compose pull)?" "Y")
if [[ ! "$response" =~ ^[nN] ]]; then
    docker compose pull
    ok "Docker images pulled"
else
    info "Skipping image pull"
fi

# --- Step 3: Backup (optional) ---
step "Checking for backups..."
response=$(ask "  Create a database backup before updating?" "Y")
if [[ ! "$response" =~ ^[nN] ]]; then
    if [[ -f "$ENV_FILE" ]]; then
        # Parse .env for credentials (safer than sourcing)
        DB_ROOT_PASS=$(grep "^DB_ROOT_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2-)
        if [[ -n "$DB_ROOT_PASS" ]]; then
            backup_file="backup_$(date +%F_%H%M).sql"
            echo "  Backing up database to $backup_file..."
            docker compose exec -T db mariadb-dump -u root -p"$DB_ROOT_PASS" infhub_database > "$backup_file" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                ok "Database backed up to $backup_file"
            else
                warn "Database backup failed — check credentials and container status"
            fi
        else
            warn "DB_ROOT_PASSWORD not found in .env — skipping backup"
        fi
    else
        warn ".env not found — cannot back up database"
    fi
else
    info "Skipping backup"
fi

# --- Step 4: Rebuild & Restart ---
step "Rebuilding and restarting the stack..."
response=$(ask "  Rebuild images and restart (docker compose up -d --build)?" "Y")
if [[ ! "$response" =~ ^[nN] ]]; then
    docker compose up -d --build
    ok "Stack rebuilt and restarted"
else
    response=$(ask "  Just restart without rebuild (docker compose up -d)?" "Y")
    if [[ ! "$response" =~ ^[nN] ]]; then
        docker compose up -d
        ok "Stack restarted"
    else
        info "Skipping restart"
    fi
fi

# --- Step 5: Wait for Database Health ---
step "Waiting for database to become healthy..."

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
        echo "  Check logs: docker compose logs db"
        exit 1
    fi
done

echo ""

if [[ "$db_healthy" == true ]]; then
    ok "Database is healthy after $elapsed seconds"
else
    err "Database did not become healthy within 120 seconds"
    echo "  Check logs: docker compose logs db"
    exit 1
fi

# --- Step 6: Verify Services ---
step "Verifying services..."

php_status=$(docker inspect --format='{{.State.Status}}' infhub-website-php-app-1 2>/dev/null || echo "")
if [[ "$php_status" == "running" ]]; then
    ok "php-app (web) is running"
else
    warn "php-app is not running (status: $php_status)"
fi

lounge_status=$(docker inspect --format='{{.State.Status}}' infhub_lounge 2>/dev/null || echo "")
if [[ "$lounge_status" == "running" ]]; then
    ok "lounge (The Lounge IRC) is running"
else
    warn "lounge is not running (status: $lounge_status)"
fi

# --- Step 7: Display Status ---
step "=== Update Complete ==="
echo ""
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker compose ps
echo ""
echo "  Access your services:"
echo "    Web Application    http://localhost:8080"
echo "    The Lounge IRC     http://localhost:9000"
echo "    INFCRAFT page    http://localhost:8080/infcraft"
echo ""
echo "  Happy hacking! 🚀"
