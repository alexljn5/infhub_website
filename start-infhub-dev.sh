#!/usr/bin/env bash
# ============================================================
# INFHUB — Local Development Script
# ============================================================
# Runs the Next.js dev server locally so you can iterate
# without pulling from the production server.
#
# Usage:
#   bash dev.sh            # Start the dev server
#   bash dev.sh --port 3000
#   bash dev.sh --help
# ============================================================

set -euo pipefail

PORT=3000

for arg in "$@"; do
    case "$arg" in
        --port)    PORT="$2"; shift 2 ;;
        -h|--help)
            cat <<EOF
Usage: bash dev.sh [--port PORT]

  Start the Next.js dev server for local development.

  Options:
    --port PORT    Port to listen on (default: 3000)
    -h, --help     Show this help message

  Examples:
    bash dev.sh
    bash dev.sh --port 3001
EOF
            exit 0
            ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

echo "============================================"
echo "  INFHUB Local Dev Server"
echo "============================================"
echo "  Port:    $PORT"
echo "  URL:     http://localhost:$PORT"
echo "  Ctrl+C to stop"
echo "============================================"
echo ""

npm run dev -- --port "$PORT"