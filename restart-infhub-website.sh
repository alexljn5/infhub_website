#!/usr/bin/env bash
# ============================================================
# INFHUB Homelab — Safe Restart Wrapper
# ============================================================
# Restarts the current Compose stack without pulling or rebuilding
# images. Legacy PHP containers are removed safely and port 8080 is
# checked before the Next.js container starts.
#
# Usage:
#   bash restart-infhub-website.sh
#   bash restart-infhub-website.sh --yes
#   bash restart-infhub-website.sh --skip-healthcheck
# ============================================================

set -Eeuo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

exec bash "$SCRIPT_DIR/update-infhub-website.sh" --restart-only --yes "$@"
