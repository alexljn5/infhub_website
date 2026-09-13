#!/usr/bin/env bash
# ============================================================
# INFHUB Homelab — Start Script
# ============================================================
# Starts the INFHUB Docker stack: php-app (web), db (MariaDB),
# lounge (The Lounge IRC).
#
# Usage:
#   ./start-infhub-website.sh          # Interactive startup
#   ./start-infhub-website.sh --yes    # Non-interactive
#   ./start-infhub-website.sh --help   # Show help
# ============================================================

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"
ENV_FILE="$SCRIPT_DIR/.env"
MAX_RETRIES=60
RETRY_INTERVAL=2

# --- Flags ---
NO_BUILD=false
AUTO_YES=false

# --- Parse arguments ---
for arg in "$@"; do
    case "$arg" in
        --no-build)    NO_BUILD=true ;;
        --yes)         AUTO_YES=true ;;
        -h|--help)
            cat <<EOF
Usage: ./start-infhub-website.sh [--no-build] [--yes] [--help]

  Start the INFHUB homelab stack (php-app, db, lounge).

  Options:
    --no-build     Skip rebuilding images (use existing)
    --yes          Non-interactive: accept all defaults
    -h, --help     Show this help message

  Examples:
    ./start-infhub-website.sh              # Interactive startup
    ./start-infhub-website.sh --yes        # Quick non-interactive startup
    ./start-infhub-website.sh --no-build   # Start without rebuilding
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

# --- Step 1: Pre-flight Checks ---
step "=== INFHUB Homelab Startup ==="
echo "Working directory: $SCRIPT_DIR"

# Check Docker
step "Checking prerequisites..."
if command -v docker &>/dev/null; then
    ok "Docker found: $(docker --version)"
else
    err "Docker is not installed or not in PATH."
    exit 1
fi

if command -v docker compose &>/dev/null; then
    ok "Docker Compose found: $(docker compose version)"
else
    err "Docker Compose plugin is not available."
    exit 1
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
    err "docker-compose.yml not found in $SCRIPT_DIR"
    exit 1
fi
ok "docker-compose.yml found"

# --- Step 2: Environment File ---
step "Checking environment configuration..."

if [[ -f "$ENV_FILE" ]]; then
    ok ".env file already exists"
    if grep -q "DB_ROOT_PASSWORD=change_me_to_a_strong_password" "$ENV_FILE" 2>/dev/null; then
        warn "DB_ROOT_PASSWORD is still the default — update it!"
    else
        ok "DB_ROOT_PASSWORD is configured"
    fi
    if grep -q "DB_PASSWORD=change_me_to_a_strong_password" "$ENV_FILE" 2>/dev/null; then
        warn "DB_PASSWORD is still the default — update it!"
    else
        ok "DB_PASSWORD is configured"
    fi
else
    warn ".env file not found — creating from template..."
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    echo "  Created .env from .env.example"
    warn "IMPORTANT: Edit .env and set strong passwords!"
    response=$(ask "  Continue anyway and proceed?" "Y")
    if [[ "$response" =~ ^[nN] ]]; then
        echo "  Aborted. Edit .env and run again."
        exit 0
    fi
fi

# --- Step 3: Optional Git Pull ---
step "Checking for updates..."
if [[ -d "$SCRIPT_DIR/.git" ]]; then
    response=$(ask "  Pull latest changes from git?" "Y")
    if [[ ! "$response" =~ ^[nN] ]]; then
        echo "  Running git pull..."
        if git pull; then
            ok "Git pull successful"
        else
            warn "Git pull failed — continuing with existing code"
        fi
    fi
else
    info "Not a git repository — skipping git pull"
fi

# --- Step 4: Stop any running containers ---
step "Checking for existing containers..."
if docker compose ps --format json &>/dev/null && [[ -n "$(docker compose ps --format json 2>/dev/null)" ]]; then
    response=$(ask "  Containers are already running. Stop and restart?" "Y")
    if [[ ! "$response" =~ ^[nN] ]]; then
        echo "  Stopping existing containers..."
        docker compose down 2>&1 || docker compose down --remove-orphans 2>&1
        ok "Existing containers stopped"
    fi
else
    info "No existing containers found"
fi

# --- Step 5: Build & Start ---
step "Building and starting the stack..."
echo "  This may take a few minutes on first run (image builds + DB init)..."

if [[ "$NO_BUILD" == true ]]; then
    docker compose up -d
else
    docker compose up -d --build
fi
ok "Stack build and start command issued"

# --- Step 6: Wait for Database Health ---
step "Waiting for database to become healthy..."

db_healthy=false
elapsed=0

for ((i=0; i<MAX_RETRIES; i++)); do
    sleep "$RETRY_INTERVAL"
    elapsed=$((elapsed + RETRY_INTERVAL))

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

    echo -n "  ...waiting ($elapsed seconds elapsed)..."
done

echo ""  # newline after waiting

if [[ "$db_healthy" == true ]]; then
    ok "Database is healthy after $elapsed seconds"
else
    err "Database did not become healthy within $MAX_RETRIES seconds"
    echo "  Check logs: docker compose logs db"
    echo "  Check status: docker compose ps"
    exit 1
fi

# --- Step 7: Verify All Services ---
step "Verifying all services..."

php_status=$(docker inspect --format='{{.State.Status}}' infhub-website-php-app-1 2>/dev/null || echo "")
if [[ "$php_status" == "running" ]]; then
    ok "php-app (web) is running"
else
    warn "php-app is not running (status: $php_status) — check logs"
fi

lounge_status=$(docker inspect --format='{{.State.Status}}' infhub_lounge 2>/dev/null || echo "")
if [[ "$lounge_status" == "running" ]]; then
    ok "lounge (The Lounge IRC) is running"
else
    warn "lounge is not running (status: $lounge_status) — check logs"
fi

# --- Step 8: Display Status ---
step "=== Startup Complete ==="
echo ""
echo "  +---------------------------------------------------+"
echo "  |            INFHUB Stack is Running!               |"
echo "  +---------------------------------------------------+"
echo ""
echo "  Access your services:"
echo ""
echo "    Web Application    http://localhost:8080"
echo "    The Lounge IRC     http://localhost:9000"
echo "    INFCRAFT page    http://localhost:8080/infcraft"
echo ""
echo "  For production (with reverse proxy):"
echo "    Web Application    http://infhub.org"
echo "    The Lounge IRC     http://irc.infhub.org"
echo ""
echo "  Database (internal): infhub-website-db-1"
echo "  Network:           infhub-network"
echo ""
echo "  Container Status:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker compose ps
echo ""

# --- Step 9: Post-setup prompts ---
response=$(ask "  Create a The Lounge admin user? (enter username, or n to skip)" "n")
if [[ -n "$response" && "$response" != "n" && "$response" != "N" ]]; then
    echo "  Creating admin user '$response'..."
    if docker compose exec lounge thelounge add "$response" 2>&1; then
        ok "Admin user '$response' created"
    else
        warn "Failed to create admin user — you can try again later"
    fi
fi

response=$(ask "  View container logs? [y/N]" "N")
if [[ "$response" == "y" || "$response" == "Y" ]]; then
    echo "  Starting log tail (Ctrl+C to stop)..."
    docker compose logs -f
fi

echo ""
echo "  Useful commands:"
echo "    docker compose ps                  — View running containers"
echo "    docker compose logs -f             — View all logs"
echo "    docker compose logs -f lounge      — View lounge logs"
echo "    docker compose restart             — Restart all services"
echo "    ./stop-infhub-website.sh           — Stop all services"
echo "    ./update-infhub-website.sh         — Pull updates and rebuild"
echo "    docker compose exec db mariadb -u root -p\$DB_ROOT_PASSWORD infhub_database"
echo "                                       — Access database"
echo ""
echo "  Happy hacking! 🚀"
