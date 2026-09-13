#!/usr/bin/env bash
# ============================================================
# INFHUB Homelab — Start Script
# ============================================================
# Starts the complete INFHUB Docker Compose stack:
#   - php-app: Apache + PHP 8.4 website (port 8080)
#   - db: MariaDB 11 (internal only)
#   - inspircd: InspIRCd 4.x IRC server (ports 6667, 6697)
#   - lounge: The Lounge IRC web client (port 9000)
#
# Usage:
#   bash start-infhub-website.sh          # Interactive startup
#   bash start-infhub-website.sh --yes    # Non-interactive
#   bash start-infhub-website.sh --help   # Show help
#
# Notes:
#   - Stops any existing screen-based TheLounge before starting
#   - Backs up existing InspIRCd and TheLounge configs before starting
#   - Uses absolute paths for cron/non-interactive execution
# ============================================================

set -euo pipefail

# --- Absolute Paths ---
SCRIPT_DIR="/home/alexljn5/INFHUB/infhub-website"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

# Paths for backup and config preservation
THELOUNGE_HOME="/home/alexljn5/.thelounge"
INSPIRCD_HOME="/home/alexljn5/INFHUB/inf_irc/inspircd"
BACKUP_DIR="$SCRIPT_DIR/backups"

# Screen-based TheLounge process check
SCREEN_SESSION="thelounge"

# Health check settings
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
Usage: bash start-infhub-website.sh [--no-build] [--yes] [--help]

  Start the complete INFHUB stack (website, database, InspIRCd, TheLounge).

  Options:
    --no-build     Skip rebuilding images (use existing)
    --yes          Non-interactive: accept all defaults
    -h, --help     Show this help message

  Examples:
    bash start-infhub-website.sh              # Interactive startup
    bash start-infhub-website.sh --yes        # Quick non-interactive startup
    bash start-infhub-website.sh --no-build   # Start without rebuilding
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
echo "Stack directory: $SCRIPT_DIR"

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
    err "docker-compose.yml not found at $COMPOSE_FILE"
    exit 1
fi
ok "docker-compose.yml found"

# --- Step 2: Environment File ---
step "Checking environment configuration..."

if [[ -f "$ENV_FILE" ]]; then
    ok ".env file exists"
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

# --- Step 3: Stop Screen-based TheLounge ---
step "Checking for screen-based TheLounge..."
if screen -list 2>/dev/null | grep -q "$SCREEN_SESSION"; then
    response=$(ask "  Found screen session '$SCREEN_SESSION'. Stop it before starting Docker-managed TheLounge?" "Y")
    if [[ ! "$response" =~ ^[nN] ]]; then
        echo "  Stopping screen session..."
        screen -X -S "$SCREEN_SESSION" quit 2>/dev/null || screen -S "$SCREEN_SESSION" -X quit 2>/dev/null || true
        sleep 2
        if screen -list 2>/dev/null | grep -q "$SCREEN_SESSION"; then
            warn "Screen session still exists — killing process"
            pkill -f "thelounge start" 2>/dev/null || true
            sleep 1
        fi
        ok "Screen-based TheLounge stopped"
    else
        warn "Screen-based TheLounge is still running — port 9000 may conflict"
    fi
else
    info "No screen-based TheLounge found"
fi

# Also check for any running thelounge process
if pgrep -f "thelounge" &>/dev/null; then
    response=$(ask "  Found running TheLounge process. Kill it?" "Y")
    if [[ ! "$response" =~ ^[nN] ]]; then
        echo "  Killing TheLounge processes..."
        pkill -f "thelounge" 2>/dev/null || true
        sleep 2
        ok "TheLounge processes stopped"
    fi
fi

# --- Step 4: Backup Existing Configs ---
step "Backing up existing configurations..."
mkdir -p "$BACKUP_DIR"
backup_ts=$(date +%F_%H%M)

# Backup TheLounge config
if [[ -d "$THELOUNGE_HOME" ]]; then
    thelounge_backup="$BACKUP_DIR/thelounge-backup-$backup_ts"
    echo "  Backing up TheLounge config to $thelounge_backup..."
    cp -a "$THELOUNGE_HOME" "$thelounge_backup" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        ok "TheLounge config backed up"
    else
        warn "TheLounge backup failed"
    fi
else
    info "No existing TheLounge config found at $THELOUNGE_HOME"
fi

# Backup InspIRCd config
if [[ -d "$INSPIRCD_HOME" ]]; then
    inspircd_backup="$BACKUP_DIR/inspircd-backup-$backup_ts"
    echo "  Backing up InspIRCd config to $inspircd_backup..."
    cp -a "$INSPIRCD_HOME" "$inspircd_backup" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        ok "InspIRCd config backed up"
    else
        warn "InspIRCd backup failed"
    fi
else
    info "No existing InspIRCd config found at $INSPIRCD_HOME"
fi

# Backup database (optional)
if [[ -f "$ENV_FILE" ]]; then
    DB_ROOT_PASS=$(grep "^DB_ROOT_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2-)
    if [[ -n "$DB_ROOT_PASS" ]]; then
        db_backup="$BACKUP_DIR/database-backup-$backup_ts.sql"
        echo "  Backing up database to $db_backup..."
        docker compose -f "$COMPOSE_FILE" exec -T db mariadb-dump -u root -p"$DB_ROOT_PASS" infhub_database > "$db_backup" 2>/dev/null || true
        if [[ -f "$db_backup" && -s "$db_backup" ]]; then
            ok "Database backed up"
        else
            warn "Database backup failed or empty — continuing"
            rm -f "$db_backup"
        fi
    fi
fi

# --- Step 5: Stop Existing Compose Stack ---
step "Checking for existing Compose stack..."
existing=$(docker compose -f "$COMPOSE_FILE" ps --format json 2>/dev/null || echo "")
if [[ -n "$existing" && "$existing" != "[]" ]]; then
    response=$(ask "  Compose stack is running. Stop and restart?" "Y")
    if [[ ! "$response" =~ ^[nN] ]]; then
        echo "  Stopping existing Compose stack..."
        docker compose -f "$COMPOSE_FILE" down 2>&1 || docker compose -f "$COMPOSE_FILE" down --remove-orphans 2>&1
        ok "Existing Compose stack stopped"
    fi
else
    info "No existing Compose stack found"
fi

# Remove any orphaned containers with old names
for container in infhub_lounge infhub-website-lounge-1; do
    if docker inspect "$container" &>/dev/null 2>&1; then
        response=$(ask "  Removing orphaned container '$container'?" "Y")
        if [[ ! "$response" =~ ^[nN] ]]; then
            echo "  Removing $container..."
            docker rm -f "$container" 2>/dev/null || true
            ok "Removed $container"
        fi
    fi
done

# --- Step 6: Build & Start ---
step "Building and starting the stack..."
echo "  This may take a few minutes on first run (image builds + DB init)..."

if [[ "$NO_BUILD" == true ]]; then
    docker compose -f "$COMPOSE_FILE" up -d
else
    docker compose -f "$COMPOSE_FILE" up -d --build
fi
ok "Stack build and start command issued"

# --- Step 7: Wait for Services Health ---
step "Waiting for services to become healthy..."

# Wait for DB
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
        echo "  Check logs: docker compose -f $COMPOSE_FILE logs db"
        exit 1
    fi
    echo -n "  DB... waiting ($elapsed seconds)..."
done
echo ""
if [[ "$db_healthy" == true ]]; then
    ok "Database healthy after $elapsed seconds"
else
    err "Database did not become healthy within $MAX_RETRIES seconds"
    exit 1
fi

# Wait for InspIRCd
inspircd_healthy=false
elapsed=0
for ((i=0; i<MAX_RETRIES; i++)); do
    sleep "$RETRY_INTERVAL"
    elapsed=$((elapsed + RETRY_INTERVAL))
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
    echo -n "  InspIRCd... waiting ($elapsed seconds)..."
done
echo ""
if [[ "$inspircd_healthy" == true ]]; then
    ok "InspIRCd healthy after $elapsed seconds"
else
    err "InspIRCd did not become healthy within $MAX_RETRIES seconds"
    echo "  Check logs: docker compose -f $COMPOSE_FILE logs inspircd"
    exit 1
fi

# Wait for Lounge
lounge_healthy=false
elapsed=0
for ((i=0; i<MAX_RETRIES; i++)); do
    sleep "$RETRY_INTERVAL"
    elapsed=$((elapsed + RETRY_INTERVAL))
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
    echo -n "  Lounge... waiting ($elapsed seconds)..."
done
echo ""
if [[ "$lounge_healthy" == true ]]; then
    ok "Lounge healthy after $elapsed seconds"
else
    warn "Lounge did not become healthy within $MAX_RETRIES seconds — check logs"
fi

# Wait for PHP app
php_healthy=false
elapsed=0
for ((i=0; i<MAX_RETRIES; i++)); do
    sleep "$RETRY_INTERVAL"
    elapsed=$((elapsed + RETRY_INTERVAL))
    health=$(docker inspect --format='{{.State.Health.Status}}' infhub-website-php-app-1 2>/dev/null || echo "")
    if [[ "$health" == "healthy" ]]; then
        php_healthy=true
        break
    fi
    container_status=$(docker inspect --format='{{.State.Status}}' infhub-website-php-app-1 2>/dev/null || echo "")
    if [[ "$container_status" != "running" ]]; then
        err "PHP app container is not running (status: $container_status)"
        echo "  Check logs: docker compose -f $COMPOSE_FILE logs php-app"
        exit 1
    fi
    echo -n "  PHP app... waiting ($elapsed seconds)..."
done
echo ""
if [[ "$php_healthy" == true ]]; then
    ok "PHP app healthy after $elapsed seconds"
else
    warn "PHP app did not become healthy within $MAX_RETRIES seconds — check logs"
fi

# --- Step 8: Verify TheLounge can reach InspIRCd ---
step "Verifying TheLounge can reach InspIRCd..."
irc_port_check=$(docker exec infhub_lounge nc -z inspircd 6667 2>&1 && echo "ok" || echo "fail")
if [[ "$irc_port_check" == "ok" ]]; then
    ok "TheLounge can reach InspIRCd on port 6667"
else
    warn "TheLounge may not reach InspIRCd yet — TheLounge config may need updating"
    info "Check TheLounge networks.json points to inspircd:6667 (or inspircd:6697 for TLS)"
fi

# --- Step 9: Display Status ---
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
echo "    InspIRCd Plain     irc://localhost:6667"
echo "    InspIRCd TLS       irc://localhost:6697"
echo "    INFCRAFT page    http://localhost:8080/infcraft"
echo ""
echo "  For production (with reverse proxy):"
echo "    Web Application    http://infhub.org"
echo "    The Lounge IRC     http://irc.infhub.org"
echo ""
echo "  Managed services:"
echo "    Website/PHP:       infhub-website-php-app-1"
echo "    Database:          infhub-website-db-1 (internal)"
echo "    InspIRCd:          infhub-website-inspircd-1"
echo "    TheLounge:         infhub_lounge"
echo ""
echo "  Persistent data:"
echo "    Database:          db-data volume"
echo "    InspIRCd data:     inspircd-data volume"
echo "    TheLounge config:  /home/alexljn5/.thelounge"
echo "    InspIRCd config:   /home/alexljn5/INFHUB/inf_irc/inspircd/run"
echo ""
echo "  Container Status:"
docker compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker compose -f "$COMPOSE_FILE" ps
echo ""

# --- Step 10: Post-setup prompts ---
response=$(ask "  Create a The Lounge admin user? (enter username, or n to skip)" "n")
if [[ -n "$response" && "$response" != "n" && "$response" != "N" ]]; then
    echo "  Creating admin user '$response'..."
    if docker compose -f "$COMPOSE_FILE" exec lounge thelounge add "$response" 2>&1; then
        ok "Admin user '$response' created"
    else
        warn "Failed to create admin user — you can try again later"
    fi
fi

response=$(ask "  View container logs? [y/N]" "N")
if [[ "$response" == "y" || "$response" == "Y" ]]; then
    echo "  Starting log tail (Ctrl+C to stop)..."
    docker compose -f "$COMPOSE_FILE" logs -f
fi

echo ""
echo "  Useful commands:"
echo "    docker compose -f $COMPOSE_FILE ps                  — View running containers"
echo "    docker compose -f $COMPOSE_FILE logs -f             — View all logs"
echo "    docker compose -f $COMPOSE_FILE logs -f lounge      — View lounge logs"
echo "    docker compose -f $COMPOSE_FILE logs -f inspircd    — View InspIRCd logs"
echo "    docker compose -f $COMPOSE_FILE restart             — Restart all services"
echo "    bash stop-infhub-website.sh                          — Stop all services"
echo "    bash update-infhub-website.sh                        — Pull updates and rebuild"
echo "    docker compose -f $COMPOSE_FILE exec db mariadb -u root -p\$DB_ROOT_PASSWORD infhub_database"
echo "                                                       — Access database"
echo ""
echo "  Happy hacking! 🚀"
