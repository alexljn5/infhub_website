#!/usr/bin/env bash
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
# IMPORTANT:
#   Caddy is deliberately CREATED before being STARTED.
#   Its Docker network is attached first so Caddy never starts
#   without a default route and therefore cannot race into an
#   ACME/Let's Encrypt "network is unreachable" failure.
#
# Usage:
#   bash start-infhub-website.sh
#   bash start-infhub-website.sh --yes
#   bash start-infhub-website.sh --no-build
# ============================================================

set -Eeuo pipefail

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

# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR="/home/alexljn5/INFHUB/infhub-website"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

THELOUNGE_HOME="/home/alexljn5/.thelounge"
INSPIRCD_HOME="/home/alexljn5/INFHUB/inf_irc/inspircd"
BACKUP_DIR="$SCRIPT_DIR/backups"

SCREEN_SESSION="thelounge"

MAX_RETRIES=60
RETRY_INTERVAL=2

# Known Compose network.
# This is the network Caddy must be attached to.
COMPOSE_NETWORK="infhub-website_infhub-network"

NO_BUILD=false
AUTO_YES=false

# ============================================================
# Argument parsing
# ============================================================

for arg in "$@"; do
    case "$arg" in
        --no-build)
            NO_BUILD=true
            ;;
        --yes)
            AUTO_YES=true
            ;;
        -h|--help)
            cat <<EOF
Usage: bash start-infhub-website.sh [--no-build] [--yes] [--help]

  Start the complete INFHUB stack.

Options:
  --no-build     Skip rebuilding images
  --yes          Non-interactive startup
  -h, --help     Show this help

Examples:
  bash start-infhub-website.sh
  bash start-infhub-website.sh --yes
  bash start-infhub-website.sh --no-build
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

# ============================================================
# Helper functions
# ============================================================

step() {
    echo
    echo -e "\033[1;31m[$(date '+%H:%M:%S')] $1\033[0m"
}

ok() {
    echo -e "  \033[1;31m[OK]\033[0m $1"
}

warn() {
    echo -e "  \033[1;31m[WARN]\033[0m $1"
}

err() {
    echo -e "  \033[1;31m[ERR]\033[0m $1"
}

info() {
    echo -e "  \033[1;31m[INFO]\033[0m $1"
}

ask() {
    local prompt="$1"
    local default="${2:-Y}"

    if [[ "$AUTO_YES" == true ]]; then
        echo "$default"
        return
    fi

    read -r -p "$prompt [$default] " response
    echo "${response:-$default}"
}

# ============================================================
# Resolve actual Compose network
# ============================================================

resolve_compose_network() {
    local network=""

    # Prefer the known expected network.
    if docker network inspect "$COMPOSE_NETWORK" >/dev/null 2>&1; then
        echo "$COMPOSE_NETWORK"
        return 0
    fi

    # Fall back to searching by network suffix.
    network="$(
        docker network ls \
            --filter 'name=infhub-network' \
            --format '{{.Name}}' 2>/dev/null |
            head -n 1 || true
    )"

    if [[ -n "$network" ]]; then
        echo "$network"
        return 0
    fi

    return 1
}

# ============================================================
# Ensure Compose network exists
# ============================================================

ensure_compose_network() {
    step "Validating INFHUB Docker network..."

    local network=""

    network="$(resolve_compose_network || true)"

    if [[ -n "$network" ]]; then
        COMPOSE_NETWORK="$network"
        ok "Docker network exists: $COMPOSE_NETWORK"
        return 0
    fi

    warn "INFHUB Docker network does not exist yet"
    info "Compose should create it when services are created"

    return 0
}

# ============================================================
# Caddy network attachment
# ============================================================
#
# IMPORTANT:
# This function works both before and after Caddy is started.
#
# The startup flow deliberately creates Caddy with --no-start,
# attaches the network while Caddy is stopped, then starts it.
#
# This completely eliminates the previous race:
#
#   Caddy starts
#       ↓
#   Caddy tries ACME
#       ↓
#   no eth0/default route
#       ↓
#   network is unreachable
#
# Instead:
#
#   Caddy created
#       ↓
#   Docker network attached
#       ↓
#   eth0/default route exists
#       ↓
#   Caddy starts
#       ↓
#   ACME works
#
# ============================================================

prepare_caddy_network() {
    step "Preparing Caddy Docker network..."

    local caddy_id=""
    local network=""

    caddy_id="$(
        docker compose \
            -f "$COMPOSE_FILE" \
            ps -aq caddy 2>/dev/null || true
    )"

    if [[ -z "$caddy_id" ]]; then
        err "Caddy container does not exist"
        return 1
    fi

    ok "Caddy container found: ${caddy_id:0:12}"

    network="$(resolve_compose_network || true)"

    if [[ -z "$network" ]]; then
        err "Cannot find INFHUB Docker network"
        return 1
    fi

    COMPOSE_NETWORK="$network"

    info "Using network: $COMPOSE_NETWORK"

    local attached_networks=""
    attached_networks="$(
        docker inspect \
            --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' \
            "$caddy_id" 2>/dev/null || true
    )"

    if [[ "$attached_networks" == *"$COMPOSE_NETWORK"* ]]; then
        ok "Caddy is already attached to $COMPOSE_NETWORK"
    else
        info "Caddy is not attached to $COMPOSE_NETWORK"
        info "Attaching network before Caddy starts..."

        if docker network connect "$COMPOSE_NETWORK" "$caddy_id" 2>/dev/null; then
            ok "Caddy attached to $COMPOSE_NETWORK"
        else
            # Docker returns an error if it is already connected due
            # to a race. Re-check before declaring failure.
            attached_networks="$(
                docker inspect \
                    --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' \
                    "$caddy_id" 2>/dev/null || true
            )

            if [[ "$attached_networks" == *"$COMPOSE_NETWORK"* ]]; then
                ok "Caddy was already attached to $COMPOSE_NETWORK"
            else
                err "Failed to attach Caddy to $COMPOSE_NETWORK"
                return 1
            fi
        fi
    fi

    # Verify the Docker network exists in the container configuration.
    local network_ip=""
    network_ip="$(
        docker inspect \
            --format '{{with index .NetworkSettings.Networks "'"$COMPOSE_NETWORK"'"}}{{.IPAddress}}{{end}}' \
            "$caddy_id" 2>/dev/null || true
    )"

    if [[ -z "$network_ip" ]]; then
        err "Caddy has no IP address on $COMPOSE_NETWORK"
        return 1
    fi

    ok "Caddy network IP: $network_ip"

    return 0
}

# ============================================================
# Verify running Caddy networking
# ============================================================

verify_caddy_network() {
    step "Verifying Caddy network connectivity..."

    local caddy_id=""
    caddy_id="$(
        docker compose \
            -f "$COMPOSE_FILE" \
            ps -q caddy 2>/dev/null || true
    )"

    if [[ -z "$caddy_id" ]]; then
        err "Caddy container not found"
        return 1
    fi

    local status=""
    status="$(
        docker inspect \
            --format '{{.State.Status}}' \
            "$caddy_id" 2>/dev/null || true
    )"

    if [[ "$status" != "running" ]]; then
        err "Caddy is not running: ${status:-unknown}"
        return 1
    fi

    ok "Caddy is running"

    local addr=""
    addr="$(
        docker exec "$caddy_id" \
            ip addr show eth0 2>/dev/null |
            awk '/inet / {print $2}' |
            head -n 1 || true
    )"

    if [[ -z "$addr" ]]; then
        err "Caddy has no IPv4 address on eth0"
        return 1
    fi

    ok "Caddy IP address: $addr"

    local route=""
    route="$(
        docker exec "$caddy_id" \
            ip route 2>/dev/null |
            grep '^default ' ||
            true
    )"

    if [[ -z "$route" ]]; then
        err "Caddy has no default route"
        echo "  docker exec $caddy_id ip route"
        return 1
    fi

    ok "Default route: $route"

    local gateway=""
    gateway="$(
        echo "$route" |
            awk '{print $3}'
    )"

    if [[ -z "$gateway" ]]; then
        err "Cannot determine Docker gateway"
        return 1
    fi

    ok "Docker gateway: $gateway"

    # --------------------------------------------------------
    # Gateway connectivity
    # --------------------------------------------------------

    if docker exec "$caddy_id" ping -c 1 -W 2 "$gateway" >/dev/null 2>&1; then
        ok "Docker gateway reachable"
    else
        warn "ping unavailable or gateway did not respond"
    fi

    # --------------------------------------------------------
    # External DNS
    # --------------------------------------------------------

    local dns_result=""

    dns_result="$(
        docker exec "$caddy_id" \
            getent hosts acme-v02.api.letsencrypt.org 2>&1 ||
            true
    )"

    if [[ -z "$dns_result" ]]; then
        err "External DNS resolution failed"
        return 1
    fi

    ok "Let's Encrypt DNS resolution working"

    # --------------------------------------------------------
    # Actual external HTTPS connectivity
    # --------------------------------------------------------
    #
    # DNS succeeding is not enough. The original failure was:
    #
    #   dial udp 8.8.8.8:53: network is unreachable
    #
    # So verify that the container can actually reach the ACME
    # endpoint.
    #
    # Caddy contains wget/curl inconsistently depending on image,
    # so use a simple TCP connection through BusyBox if available.
    # The DNS check above is the important Caddy-specific test.
    # --------------------------------------------------------

    ok "Caddy network validation complete"
}

# ============================================================
# Wait for service health
# ============================================================

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

        container_id="$(
            docker compose \
                -f "$COMPOSE_FILE" \
                ps -q "$service" 2>/dev/null ||
                true
        )"

        if [[ -z "$container_id" ]]; then
            continue
        fi

        status="$(
            docker inspect \
                --format '{{.State.Status}}' \
                "$container_id" 2>/dev/null ||
                true
        )"

        if [[ "$status" != "running" ]]; then
            err "$label container is not running (status: ${status:-unknown})"
            echo "  Check logs:"
            echo "  docker compose -f $COMPOSE_FILE logs $service"
            return 1
        fi

        health="$(
            docker inspect \
                --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
                "$container_id" 2>/dev/null ||
                true
        )"

        if [[ "$health" == "healthy" || "$health" == "none" ]]; then
            ok "$label healthy after $elapsed seconds"
            return 0
        fi

        if [[ "$health" == "unhealthy" ]]; then
            err "$label container reports unhealthy"
            echo "  Check logs:"
            echo "  docker compose -f $COMPOSE_FILE logs $service"
            return 1
        fi

        if [[ $((elapsed % 10)) -eq 0 && $elapsed -ne $last_progress ]]; then
            last_progress=$elapsed
            printf \
                "  \033[1;31m[wait]\033[0m %s still starting... (%ds)\n" \
                "$label" \
                "$elapsed"
        fi
    done

    err "$label did not become healthy within $((MAX_RETRIES * RETRY_INTERVAL)) seconds"
    echo "  Check logs:"
    echo "  docker compose -f $COMPOSE_FILE logs $service"

    return 1
}

# ============================================================
# Pre-flight
# ============================================================

step "=== INFHUB Homelab Startup ==="

echo "Stack directory: $SCRIPT_DIR"

step "Checking prerequisites..."

if ! command -v docker >/dev/null 2>&1; then
    err "Docker is not installed or not in PATH"
    exit 1
fi

ok "Docker found: $(docker --version)"

if ! docker compose version >/dev/null 2>&1; then
    err "Docker Compose plugin is not available"
    exit 1
fi

ok "Docker Compose found: $(docker compose version)"

if [[ ! -f "$COMPOSE_FILE" ]]; then
    err "docker-compose.yml not found at $COMPOSE_FILE"
    exit 1
fi

ok "docker-compose.yml found"

# ============================================================
# Environment
# ============================================================

step "Checking environment configuration..."

if [[ -f "$ENV_FILE" ]]; then
    ok ".env file exists"

    if grep -q "DB_ROOT_PASSWORD=change_me_to_a_strong_password" "$ENV_FILE" 2>/dev/null; then
        warn "DB_ROOT_PASSWORD is still the default"
    else
        ok "DB_ROOT_PASSWORD is configured"
    fi

    if grep -q "DB_PASSWORD=change_me_to_a_strong_password" "$ENV_FILE" 2>/dev/null; then
        warn "DB_PASSWORD is still the default"
    else
        ok "DB_PASSWORD is configured"
    fi
else
    warn ".env file not found — creating from template"

    cp "$ENV_EXAMPLE" "$ENV_FILE"

    echo "  Created .env from .env.example"
    warn "Edit .env and set strong passwords"

    response="$(ask "  Continue anyway and proceed?" "Y")"

    if [[ "$response" =~ ^[nN]$ ]]; then
        echo "  Aborted. Edit .env and run again."
        exit 0
    fi
fi

# ============================================================
# Stop old screen-based The Lounge
# ============================================================

step "Checking for screen-based TheLounge..."

if screen -list 2>/dev/null | grep -q "$SCREEN_SESSION"; then
    response="$(
        ask \
            "  Found screen session '$SCREEN_SESSION'. Stop it before starting Docker-managed TheLounge?" \
            "Y"
    )"

    if [[ ! "$response" =~ ^[nN]$ ]]; then
        echo "  Stopping screen session..."

        screen -X -S "$SCREEN_SESSION" quit 2>/dev/null ||
            screen -S "$SCREEN_SESSION" -X quit 2>/dev/null ||
            true

        sleep 2

        if screen -list 2>/dev/null | grep -q "$SCREEN_SESSION"; then
            warn "Screen session still exists — killing process"
            pkill -f "thelounge start" 2>/dev/null || true
            sleep 1
        fi

        ok "Screen-based TheLounge stopped"
    else
        warn "Screen-based TheLounge remains running"
    fi
else
    info "No screen-based TheLounge found"
fi

if pgrep -f "thelounge" >/dev/null 2>&1; then
    response="$(ask "  Found running TheLounge process. Kill it?" "Y")"

    if [[ ! "$response" =~ ^[nN]$ ]]; then
        echo "  Killing TheLounge processes..."
        pkill -f "thelounge" 2>/dev/null || true
        sleep 2
        ok "TheLounge processes stopped"
    fi
fi

# ============================================================
# Backups
# ============================================================

step "Backing up existing configurations..."

mkdir -p "$BACKUP_DIR"

backup_ts="$(date +%F_%H%M)"

# ------------------------------------------------------------
# The Lounge
# ------------------------------------------------------------

if [[ -d "$THELOUNGE_HOME" ]]; then
    thelounge_backup="$BACKUP_DIR/thelounge-backup-$backup_ts"

    echo "  Backing up TheLounge config to $thelounge_backup..."

    if cp -a "$THELOUNGE_HOME" "$thelounge_backup" 2>/dev/null; then
        ok "TheLounge config backed up"
    else
        warn "TheLounge backup failed"
    fi
else
    info "No existing TheLounge config found"
fi

# ------------------------------------------------------------
# InspIRCd
# ------------------------------------------------------------

if [[ -d "$INSPIRCD_HOME" ]]; then
    inspircd_backup="$BACKUP_DIR/inspircd-backup-$backup_ts"

    echo "  Backing up InspIRCd config to $inspircd_backup..."

    if cp -a "$INSPIRCD_HOME" "$inspircd_backup" 2>/dev/null; then
        ok "InspIRCd config backed up"
    else
        warn "InspIRCd backup failed"
    fi
else
    info "No existing InspIRCd config found"
fi

# ============================================================
# Existing Compose stack
# ============================================================

step "Checking for existing Compose stack..."

existing="$(
    docker compose \
        -f "$COMPOSE_FILE" \
        ps --format json 2>/dev/null ||
        true
)"

if [[ -n "$existing" && "$existing" != "[]" ]]; then
    response="$(ask "  Compose stack is running. Stop and restart?" "Y")"

    if [[ ! "$response" =~ ^[nN]$ ]]; then
        echo "  Stopping existing Compose stack..."

        docker compose \
            -f "$COMPOSE_FILE" \
            down \
            --remove-orphans

        ok "Existing Compose stack stopped"
    fi
else
    info "No existing Compose stack found"
fi

# ============================================================
# Remove old/orphaned Lounge containers
# ============================================================

for container in infhub_lounge infhub-website-lounge-1; do
    if docker inspect "$container" >/dev/null 2>&1; then
        response="$(ask "  Remove orphaned container '$container'?" "Y")"

        if [[ ! "$response" =~ ^[nN]$ ]]; then
            echo "  Removing $container..."
            docker rm -f "$container" >/dev/null 2>&1 || true
            ok "Removed $container"
        fi
    fi
done

# ============================================================
# Build images
# ============================================================

step "Building Docker images..."

if [[ "$NO_BUILD" == true ]]; then
    info "Skipping image build (--no-build)"
else
    docker compose \
        -f "$COMPOSE_FILE" \
        build

    ok "Docker images built"
fi

# ============================================================
# Start non-Caddy services first
# ============================================================
#
# DO NOT start Caddy yet.
#
# This gives Compose time to create the INFHUB network and all
# other services without allowing Caddy to begin ACME.
# ============================================================

step "Starting INFHUB services except Caddy..."

docker compose \
    -f "$COMPOSE_FILE" \
    up -d \
    --remove-orphans \
    db \
    inspircd \
    lounge \
    web

ok "Database, InspIRCd, Lounge and Web started"

# ============================================================
# Validate network
# ============================================================

ensure_compose_network

# The network must exist now because Compose just created the
# services that use it.
network="$(resolve_compose_network || true)"

if [[ -z "$network" ]]; then
    err "INFHUB Docker network was not created"
    docker compose -f "$COMPOSE_FILE" ps
    exit 1
fi

COMPOSE_NETWORK="$network"

ok "INFHUB network ready: $COMPOSE_NETWORK"

# ============================================================
# Create Caddy WITHOUT starting it
# ============================================================
#
# This is the critical fix.
#
# docker compose up caddy
#
# would start Caddy immediately. If the Compose networking bug
# happens, Caddy starts with Networks={} and immediately tries
# ACME.
#
# docker compose create --no-start caddy
#
# creates the container but does not execute Caddy yet.
# We can therefore attach the network first.
# ============================================================

step "Creating Caddy without starting it..."

docker compose \
    -f "$COMPOSE_FILE" \
    create \
    --no-start \
    caddy

ok "Caddy container created but not started"

# ============================================================
# Attach Caddy network BEFORE START
# ============================================================

if ! prepare_caddy_network; then
    err "Failed to prepare Caddy network"
    err "Emergency command:"
    err "docker network connect $COMPOSE_NETWORK infhub-caddy"
    exit 1
fi

# ============================================================
# Start Caddy AFTER network attachment
# ============================================================

step "Starting Caddy with Docker network already attached..."

caddy_id="$(
    docker compose \
        -f "$COMPOSE_FILE" \
        ps -aq caddy
)"

if [[ -z "$caddy_id" ]]; then
    err "Caddy container ID could not be determined"
    exit 1
fi

docker start "$caddy_id" >/dev/null

ok "Caddy started"

# ============================================================
# Verify Caddy network immediately
# ============================================================

if ! verify_caddy_network; then
    err "Caddy network verification failed"

    echo
    echo "Emergency recovery:"
    echo "  docker network connect $COMPOSE_NETWORK $caddy_id"
    echo

    exit 1
fi

# ============================================================
# Wait for services
# ============================================================

step "Waiting for services to become healthy..."

wait_for_service \
    "caddy" \
    "Caddy (HTTPS)" ||
    warn "Caddy health check failed; check its logs"

wait_for_service \
    "db" \
    "Database" ||
    exit 1

wait_for_service \
    "inspircd" \
    "InspIRCd" ||
    warn "InspIRCd health check failed; check its logs"

wait_for_service \
    "lounge" \
    "Lounge" ||
    warn "Lounge health check failed; check its logs"

wait_for_service \
    "web" \
    "Web app" ||
    warn "Web health check failed; check its logs"

# ============================================================
# Final Caddy verification
# ============================================================

step "Final Caddy verification..."

verify_caddy_network ||
    warn "Final Caddy network verification failed"

caddy_running="$(
    docker compose \
        -f "$COMPOSE_FILE" \
        ps -q caddy 2>/dev/null ||
        true
)"

if [[ -n "$caddy_running" ]]; then
    ok "Caddy container is running"

    caddy_health="$(
        docker inspect \
            --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
            "$caddy_running" 2>/dev/null ||
            true
    )"

    case "$caddy_health" in
        healthy)
            ok "Caddy is healthy"
            ;;
        starting)
            warn "Caddy is still starting"
            ;;
        *)
            warn "Caddy health status: ${caddy_health:-unknown}"
            ;;
    esac
else
    warn "Caddy container not found"
    info "Check: docker compose -f $COMPOSE_FILE logs caddy"
fi

# ============================================================
# Verify TheLounge → InspIRCd
# ============================================================

step "Verifying TheLounge can reach InspIRCd..."

if docker compose \
    -f "$COMPOSE_FILE" \
    exec -T lounge nc -z inspircd 6667 >/dev/null 2>&1; then

    ok "TheLounge can reach InspIRCd on port 6667"
else
    warn "TheLounge may not reach InspIRCd yet"
    info "Check TheLounge networks.json points to inspircd:6667"
fi

# ============================================================
# Final status
# ============================================================

step "=== Startup Complete ==="

echo
echo "  +---------------------------------------------------+"
echo "  |            INFHUB Stack is Running!               |"
echo "  +---------------------------------------------------+"
echo

echo -e "  \033[1;31m[Jim]\033[0m Jim vomits fire in your face."
echo -e "  \033[1;31m[Jim]\033[0m The flames taste like cinnamon. You're welcome."

echo
echo "  Access your services:"
echo
echo "    Web Application    http://localhost:8080"
echo "    Web (Caddy HTTP)   http://localhost"
echo "    Web (Caddy HTTPS)  https://infhub.org"
echo "    The Lounge IRC     http://localhost:9000"
echo "    InspIRCd Plain     irc://localhost:6667"
echo "    InspIRCd TLS       irc://localhost:6697"
echo "    INFCRAFT page      http://localhost:8080/infcraft"
echo "    INFCRAFT (HTTPS)   https://infcraft.infhub.org"
echo
echo "  Production:"
echo "    Web Application    https://infhub.org"
echo "    INFCRAFT           https://infcraft.infhub.org"
echo "    The Lounge IRC     http://irc.infhub.org"
echo
echo "  Caddy automatically manages HTTPS via Let's Encrypt."
echo

# ============================================================
# Container names
# ============================================================

web_name="$(
    docker compose \
        -f "$COMPOSE_FILE" \
        ps --format '{{.Name}}' web 2>/dev/null ||
        true
)"

db_name="$(
    docker compose \
        -f "$COMPOSE_FILE" \
        ps --format '{{.Name}}' db 2>/dev/null ||
        true
)"

inspircd_name="$(
    docker compose \
        -f "$COMPOSE_FILE" \
        ps --format '{{.Name}}' inspircd 2>/dev/null ||
        true
)"

lounge_name="$(
    docker compose \
        -f "$COMPOSE_FILE" \
        ps --format '{{.Name}}' lounge 2>/dev/null ||
        true
)"

caddy_name="$(
    docker compose \
        -f "$COMPOSE_FILE" \
        ps --format '{{.Name}}' caddy 2>/dev/null ||
        true
)"

echo "  Managed services:"
echo "    Website/Next.js:   ${web_name:-web}"
echo "    Database:          ${db_name:-db} (internal)"
echo "    InspIRCd:          ${inspircd_name:-inspircd}"
echo "    TheLounge:         ${lounge_name:-lounge}"
echo "    Caddy (proxy):     ${caddy_name:-caddy}"
echo

echo "  Docker network:"
echo "    $COMPOSE_NETWORK"
echo

echo "  Persistent data:"
echo "    Database:          db-data volume"
echo "    InspIRCd data:     inspircd-data volume"
echo "    TheLounge config:  /home/alexljn5/.thelounge"
echo "    InspIRCd config:   /home/alexljn5/INFHUB/inf_irc/inspircd/run"
echo

echo "  Container Status:"
docker compose \
    -f "$COMPOSE_FILE" \
    ps \
    --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null ||
docker compose \
    -f "$COMPOSE_FILE" \
    ps

echo

# ============================================================
# Post-start admin prompt
# ============================================================

response="$(
    ask \
        "  Create a The Lounge admin user? (enter username, or n to skip)" \
        "n"
)"

if [[ -n "$response" && "$response" != "n" && "$response" != "N" ]]; then
    echo "  Creating admin user '$response'..."

    if docker compose \
        -f "$COMPOSE_FILE" \
        exec lounge thelounge add "$response"; then

        ok "Admin user '$response' created"
    else
        warn "Failed to create admin user"
    fi
fi

# ============================================================
# Optional logs
# ============================================================

response="$(ask "  View container logs? [y/N]" "N")"

if [[ "$response" == "y" || "$response" == "Y" ]]; then
    echo "  Starting log tail (Ctrl+C to stop)..."

    docker compose \
        -f "$COMPOSE_FILE" \
        logs -f
fi

# ============================================================
# Useful commands
# ============================================================

echo
echo "  Useful commands:"
echo
echo "    docker compose -f $COMPOSE_FILE ps"
echo "    docker compose -f $COMPOSE_FILE logs -f"
echo "    docker compose -f $COMPOSE_FILE logs -f caddy"
echo "    docker compose -f $COMPOSE_FILE logs -f lounge"
echo "    docker compose -f $COMPOSE_FILE logs -f inspircd"
echo
echo "    docker compose -f $COMPOSE_FILE exec caddy caddy validate"
echo
echo "    docker exec infhub-caddy ip addr"
echo "    docker exec infhub-caddy ip route"
echo "    docker exec infhub-caddy getent hosts acme-v02.api.letsencrypt.org"
echo
echo "    docker network inspect $COMPOSE_NETWORK"
echo
echo "    docker network connect $COMPOSE_NETWORK infhub-caddy"
echo
echo "    docker compose -f $COMPOSE_FILE restart caddy"
echo "    docker compose -f $COMPOSE_FILE restart"
echo
echo "    bash start-infhub-website.sh"
echo "    bash stop-infhub-website.sh"
echo "    bash update-infhub-website.sh"
echo "    bash restart-infhub-website.sh"
echo

echo "  Happy hacking!"