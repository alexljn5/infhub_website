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

npm run dev -- --port "$PORT"