#!/usr/bin/env sh
# ============================================================
# INFHUB — Local Development Script
# ============================================================
# Runs the Next.js dev server locally so you can iterate
# without pulling from the production server.
#
# Usage:
#   ./start-infhub-dev.sh            # Start the dev server
#   ./start-infhub-dev.sh --port 3000
#   ./start-infhub-dev.sh --help
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

PORT=3000

for arg in "$@"; do
    case "$arg" in
        --port)    PORT="$2"; shift 2 ;;
        -h|--help)
            cat <<EOF
Usage: ./start-infhub-dev.sh [--port PORT]

  Start the Next.js dev server for local development.

  Options:
    --port PORT    Port to listen on (default: 3000)
    -h, --help     Show this help message

  Examples:
    ./start-infhub-dev.sh
    ./start-infhub-dev.sh --port 3001
EOF
            exit 0
            ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

echo -e "\n\033[1;31m============================================\033[0m"
echo -e "  \033[1;31m  INFHUB Local Dev Server\033[0m"
echo -e "\033[1;31m============================================\033[0m"
echo -e "  \033[1;31m  Port:\033[0m    $PORT"
echo -e "  \033[1;31m  URL:\033[0m     http://localhost:$PORT"
echo -e "  \033[1;31m  Ctrl+C to stop\033[0m"
echo -e "\033[1;31m============================================\033[0m"
echo ""

# Check if Docker is available and dev image exists
if command -v docker >/dev/null 2>&1 && command -v docker compose >/dev/null 2>&1; then
    if docker compose -f docker-compose-dev.yml images 2>/dev/null | grep -q "infhub-dev-web"; then
        echo "  Starting dev server in Docker container..."
        echo "  Starting Caddy (reverse proxy)..."
        docker compose -f docker-compose-dev.yml up
        exit 0
    else
        echo "  Docker available but dev image not found. Building..."
        echo "  Starting Caddy (reverse proxy)..."
        docker compose -f docker-compose-dev.yml up --build
        exit 0
    fi
fi

# Fallback: run directly with npm
if command -v caddy >/dev/null 2>&1; then
    echo "  Starting Caddy (reverse proxy)..."
    cat <<CADDYFILE | caddy run --environ &
{
    admin off
    auto_https off
}

localhost {
    reverse_proxy localhost:$PORT
}
CADDYFILE
    sleep 2
    echo "  Caddy running at http://localhost"
fi

npm run dev -- --port "$PORT"