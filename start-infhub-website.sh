#!/usr/bin/env sh
# ============================================================
# INFHUB Homelab — Start Script
# ============================================================
# Starts the complete INFHUB Docker Compose stack:
#   - caddy: Reverse proxy with automatic HTTPS (ports 80, 443)
#   - web: Next.js website (host port 8080, container port 3000)
#   - db: MariaDB 11 (internal only)
#   - inspircd: InspIRCd 4.x IRC server (ports 6667, 6697)
#   - lounge: The Lounge IRC web client (port 9000)
#
# Usage:
#   sh start-infhub-website.sh          # Interactive startup
#   sh start-infhub-website.sh --yes    # Non-interactive
#   sh start-infhub-website.sh --help   # Show help
#
# Notes:
#   - Stops any existing screen-based TheLounge before starting
#   - Backs up existing InspIRCd and TheLounge configs before starting
#   - Uses absolute paths for cron/non-interactive execution
#   - Caddy provides automatic HTTPS for subdomains (infhub.org, infcraft.infhub.org)
# ============================================================

printf '\033[1;31m'
cat <<'ASCII'
  _     <-. (`-')_            (`-').->           <-.(`-')
 (_)       \( OO) )  <-.      (OO )__      .->    __( OO)
 ,-(`-'),--./ ,--/(`-')-----.,--. ,'-',--.(,--.  '-'---.\
 | ( OO)|   \ |  |(OO|(_\---'|  | |  ||  | |(`-')| .-. (/
 |  |  )|  . '|  |)/ |  '--. |  `-'  ||  | |(OO )| '-' `.)
(|  |_/ |  |\    | \_)  .--' |  .-.  ||  | | |  \| /`'.  |
 |  |'->|  | \   |  `|  |_)  |  | |  |\  '-'(_ .'| '--'  /
 `--'   `--'  `--'   `--'    `--' `--' `-----'   `------'
ASCII
printf '\033[0m\n'

set -eu

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
step()  { echo -e "\n\033[1;31m[$(date '+%H:%M:%S')] $1\033[0m"; }
ok()    { echo -e "  \033[1;31m[OK]\033[0m $1"; }
warn()  { echo -e "  \033[1;31m[WARN]\033[0m $1"; }
err()   { echo -e "  \033[1;31m[ERR]\033[0m $1"; }
info()  { echo -e "  \033[1;31m[INFO]\033[0m $1"; }

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

wait_for_service() {
    local service="$1"
    local label="$2"
    local container_id=""
    local status=""
    local health=""
    local elapsed=0
    local last_progress=0

    for ((i=0; i<MAX_RETRIES; i++)); do
        sleep "$RETRY_INTERVAL"
        elapsed=$((elapsed + RETRY_INTERVAL))
        container_id="$(docker compose -f "$COMPOSE_FILE" ps -q "$service" 2>/dev/null || true)"

        if [[ -z "$container_id" ]]; then
            continue
        fi

        status="$(docker inspect --format '{{.State.Status}}' "$container_id" 2>/dev/null || true)"
        if [[ "$status" != "running" ]]; then
            err "$label container is not running (status: ${status:-unknown})"
            echo "  Check logs: docker compose -f $COMPOSE_FILE logs $service"
            return 1
        fi

        health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_id" 2>/dev/null || true)"
        if [[ "$health" == "healthy" || "$health" == "none" ]]; then
            ok "$label healthy after $elapsed seconds"
            return 0
        fi

        if [[ "$health" == "unhealthy" ]]; then
            err "$label container reports unhealthy"
            echo "  Check logs: docker compose -f $COMPOSE_FILE logs $service"
            return 1
        fi

        # Progress indicator — print a dot every 10 seconds so it doesn't look like a hang
        if [[ $((elapsed % 10)) -eq 0 && $elapsed -ne $last_progress ]]; then
            last_progress=$elapsed
            printf "  \033[1;31m[wait]\033[0m %s still starting... (%ds)\n" "$label" "$elapsed"
        fi
    done

    err "$label did not become healthy within $((MAX_RETRIES * RETRY_INTERVAL)) seconds"
    echo "  Check logs: docker compose -f $COMPOSE_FILE logs $service"
    return 1
}

# ------------------------------------------------------------
# Caddy Network Recovery
# ------------------------------------------------------------
# Detects and repairs the failure mode where Docker Compose
# creates the Caddy container without attaching it to any
# network (Status=running, Networks={}). This causes DNS,
# upstream connectivity, and ACME/Let's Encrypt validation to
# fail silently because the health check only probes localhost.
# ------------------------------------------------------------

recover_caddy_network() {
    step "Validating Caddy Docker network attachment..."

    local caddy_id=""
    caddy_id="$(docker compose -f "$COMPOSE_FILE" ps -q caddy 2>/dev/null || true)"

    if [[ -z "$caddy_id" ]]; then
        err "Caddy container not found — cannot validate network"
        return 1
    fi
    ok "Caddy container found: ${caddy_id:0:12}"

    local caddy_status=""
    caddy_status="$(docker inspect --format '{{.State.Status}}' "$caddy_id" 2>/dev/null || true)"
    if [[ "$caddy_status" != "running" ]]; then
        err "Caddy is not running (status: ${caddy_status:-unknown})"
        return 1
    fi
    ok "Caddy is running"

    # Check whether Caddy is attached to any Docker network
    local attached_networks=""
    attached_networks="$(docker inspect --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$caddy_id" 2>/dev/null || true)"

    if [[ -n "$attached_networks" ]]; then
        ok "Caddy is already attached to network(s): $attached_networks"
    else
        warn "Caddy has NO network attachment (Networks={}) — attempting recovery"

        # Determine the Docker network name dynamically
        local compose_network=""

        # Method 1: Search docker networks by name (most reliable —
        # returns the actual Docker network name, e.g. infhub-website_infhub-network)
        compose_network="$(docker network ls --filter 'name=infhub-network' --format '{{.Name}}' 2>/dev/null | head -1 || true)"

        # Method 2: Construct from project name + network name
        if [[ -z "$compose_network" ]]; then
            local project_name=""
            project_name="$(basename "$SCRIPT_DIR")"
            compose_network="${project_name}_infhub-network"
        fi

        if [[ -z "$compose_network" ]]; then
            err "Cannot determine the Compose network name"
            return 1
        fi

        info "Using network: $compose_network"

        docker network connect "$compose_network" "$caddy_id" || {
            err "Failed to attach Caddy to network: $compose_network"
            return 1
        }
        ok "Attached Caddy to network: $compose_network"

        # Wait for network configuration to propagate
        sleep 3
    fi

    # Verify network connectivity
    info "Verifying Caddy network connectivity..."

    # Check interface
    local addr=""
    addr="$(docker exec "$caddy_id" ip addr show eth0 2>/dev/null | grep 'inet ' | awk '{print $2}' || true)"
    if [[ -z "$addr" ]]; then
        err "Caddy has no IP address on eth0 — network attachment may not be fully configured"
        return 1
    fi
    ok "Caddy IP address: $addr"

    # Check default route
    local route=""
    route="$(docker exec "$caddy_id" ip route 2>/dev/null | grep default || true)"
    if [[ -z "$route" ]]; then
        err "Caddy has no default route — ip route output is empty"
        return 1
    fi
    ok "Default route: $route"

    # Determine gateway
    local gateway=""
    gateway="$(docker exec "$caddy_id" ip route 2>/dev/null | grep default | awk '{print $3}' || true)"
    if [[ -z "$gateway" ]]; then
        gateway="$(docker inspect --format '{{range $k, $v := .NetworkSettings.Networks}}{{$v.IPAMConfig.Gateway}}{{end}}' "$caddy_id" 2>/dev/null || true)"
    fi

    if [[ -z "$gateway" ]]; then
        err "Cannot determine Docker gateway address"
        return 1
    fi
    ok "Docker gateway: $gateway"

    # Check gateway connectivity
    local ping_result=""
    ping_result="$(docker exec "$caddy_id" ping -c 1 "$gateway" 2>&1 || true)"
    if [[ "$ping_result" == *"$gateway"* ]] || [[ "$ping_result" == *"1 packet transmitted"* ]]; then
        ok "Gateway ping successful"
    elif ! docker exec "$caddy_id" which ping >/dev/null 2>&1; then
        # ping not available — verify via DNS resolution instead
        warn "ping not available in container — verifying gateway via DNS"
        local dns_gw=""
        dns_gw="$(docker exec "$caddy_id" getent hosts "$gateway" 2>&1 || true)"
        if [[ -z "$dns_gw" ]]; then
            err "Cannot verify gateway connectivity (ping unavailable, DNS also fails)"
            return 1
        fi
        ok "Gateway reachable (verified via DNS resolution)"
    else
        err "Cannot ping Docker gateway $gateway"
        echo "  Output: $ping_result"
        return 1
    fi

    # Check external DNS resolution
    local dns_result=""
    dns_result="$(docker exec "$caddy_id" getent hosts acme-v02.api.letsencrypt.org 2>&1 || true)"
    if [[ -z "$dns_result" ]]; then
        err "External DNS resolution failed — Caddy cannot reach Let's Encrypt"
        return 1
    fi
    ok "External DNS working: $(echo "$dns_result" | awk '{print $1}')"

    ok "Caddy network validation and recovery complete"
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
        docker compose -f "$COMPOSE_FILE" down --remove-orphans 2>&1
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
    docker compose -f "$COMPOSE_FILE" up -d --remove-orphans >/dev/null 2>&1
else
    docker compose -f "$COMPOSE_FILE" up -d --build --remove-orphans >/dev/null 2>&1
fi
ok "Stack build and start command issued"

# ------------------------------------------------------------
# Step 7: Recover Caddy network immediately
# ------------------------------------------------------------
# Caddy must have a working Docker network before we wait for
# health checks or ACME certificate provisioning. Without this,
# Caddy can start successfully but cannot reach DNS/Let's Encrypt.
# ------------------------------------------------------------

step "Recovering Caddy network..."

recover_caddy_network || {
    err "Caddy network recovery failed"
    err "Manual emergency recovery:"
    err "docker network connect infhub-website_infhub-network infhub-caddy"
    exit 1
}

# --- Step 8: Wait for Services Health ---
step "Waiting for services to become healthy..."

wait_for_service "caddy" "Caddy (HTTPS)" || warn "Caddy health check failed; check its logs"
wait_for_service "db" "Database" || exit 1
wait_for_service "inspircd" "InspIRCd" || warn "InspIRCd health check failed; check its logs"
wait_for_service "lounge" "Lounge" || warn "Lounge health check failed; check its logs"
wait_for_service "web" "Web app" || warn "Web health check failed; check its logs"

# --- Step 9: Verify Caddy is running ---
step "Verifying Caddy is running..."
caddy_running=$(docker compose -f "$COMPOSE_FILE" ps -q caddy 2>/dev/null || true)
if [[ -n "$caddy_running" ]]; then
    ok "Caddy container is running"
    caddy_health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$caddy_running" 2>/dev/null || true)"
    if [[ "$caddy_health" == "healthy" ]]; then
        ok "Caddy is healthy"
    elif [[ "$caddy_health" == "starting" ]]; then
        warn "Caddy is still starting — give it a moment"
    else
        warn "Caddy health check reports: ${caddy_health:-unknown}"
    fi
else
    warn "Caddy container not found — Caddy may have failed to start"
    info "Check: docker compose -f $COMPOSE_FILE logs caddy"
fi

# Note: InspIRCd and TheLounge have a dependency chain.
# If InspIRCd is crashing, TheLounge will be unhealthy.
# Caddy only depends on web, so it starts independently.

# --- Step 10: Verify TheLounge can reach InspIRCd ---
step "Verifying TheLounge can reach InspIRCd..."
irc_port_check=$(docker compose -f "$COMPOSE_FILE" exec -T lounge nc -z inspircd 6667 2>&1 && echo "ok" || echo "fail")
if [[ "$irc_port_check" == "ok" ]]; then
    ok "TheLounge can reach InspIRCd on port 6667"
else
    warn "TheLounge may not reach InspIRCd yet — TheLounge config may need updating"
    info "Check TheLounge networks.json points to inspircd:6667 (or inspircd:6697 for TLS)"
fi

# --- Step 11: Display Status ---
step "=== Startup Complete ==="
echo ""
echo "  +---------------------------------------------------+"
echo "  |            INFHUB Stack is Running!               |"
echo "  +---------------------------------------------------+"
echo ""
echo -e "  \033[1;31m[Jim]\033[0m Jim vomits fire in your face."
echo -e "  \033[1;31m[Jim]\033[0m The flames taste like cinnamon. You're welcome."
echo ""
echo "  Access your services:"
echo ""
echo "    Web Application    http://localhost:8080"
echo "    Web (Caddy HTTP)   http://localhost"
echo "    Web (Caddy HTTPS)  https://infhub.org"
echo "    The Lounge IRC     http://localhost:9000"
echo "    InspIRCd Plain     irc://localhost:6667"
echo "    InspIRCd TLS       irc://localhost:6697"
echo "    INFCRAFT page    http://localhost:8080/infcraft"
echo "    INFCRAFT (HTTPS)   https://infcraft.infhub.org"
echo ""
echo "  For production (with Caddy reverse proxy):"
echo "    Web Application    https://infhub.org"
echo "    INFCRAFT           https://infcraft.infhub.org"
echo "    The Lounge IRC     http://irc.infhub.org"
echo ""
echo "  Caddy automatically obtains SSL certificates via Let's Encrypt"
echo ""
web_name="$(docker compose -f "$COMPOSE_FILE" ps --format '{{.Name}}' web 2>/dev/null || true)"
db_name="$(docker compose -f "$COMPOSE_FILE" ps --format '{{.Name}}' db 2>/dev/null || true)"
inspircd_name="$(docker compose -f "$COMPOSE_FILE" ps --format '{{.Name}}' inspircd 2>/dev/null || true)"
lounge_name="$(docker compose -f "$COMPOSE_FILE" ps --format '{{.Name}}' lounge 2>/dev/null || true)"
caddy_name="$(docker compose -f "$COMPOSE_FILE" ps --format '{{.Name}}' caddy 2>/dev/null || true)"

echo "  Managed services:"
echo "    Website/Next.js:   ${web_name:-web}"
echo "    Database:          ${db_name:-db} (internal)"
echo "    InspIRCd:          ${inspircd_name:-inspircd}"
echo "    TheLounge:         ${lounge_name:-lounge}"
echo "    Caddy (proxy):     ${caddy_name:-caddy}"
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

# --- Step 12: Post-setup prompts ---
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
echo "    docker compose -f $COMPOSE_FILE logs -f caddy        — View Caddy logs"
echo "    docker compose -f $COMPOSE_FILE exec caddy caddy validate — Validate Caddy config"
echo "    bash start-infhub-website.sh — Restart stack with Caddy network recovery"
echo "    docker network connect infhub-website_infhub-network infhub-caddy — Emergency: manually attach Caddy network"
echo "    docker compose -f $COMPOSE_FILE restart caddy        — Restart Caddy only"
echo "    docker compose -f $COMPOSE_FILE logs -f lounge      — View lounge logs"
echo "    docker compose -f $COMPOSE_FILE logs -f inspircd    — View InspIRCd logs"
echo "    docker compose -f $COMPOSE_FILE restart             — Restart all services"
echo "    bash stop-infhub-website.sh                          — Stop all services"
echo "    bash update-infhub-website.sh                        — Safe update and rebuild"
echo "    bash restart-infhub-website.sh                       — Safe restart without rebuild"
echo "    docker compose -f $COMPOSE_FILE exec db mariadb -u root -p\$DB_ROOT_PASSWORD infhub_database"
echo "                                                       — Access database"
echo ""
echo "  Happy hacking!"
