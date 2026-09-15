#!/usr/bin/env sh
# ============================================================
# INFHUB Homelab — Safe Restart Wrapper
# ============================================================
# Restarts the current Compose stack without pulling or rebuilding
# images. Legacy PHP containers are removed safely and port 8080 is
# checked before the Next.js container starts.
#
# Usage:
#   sh restart-infhub-website.sh
#   sh restart-infhub-website.sh --yes
#   sh restart-infhub-website.sh --skip-healthcheck
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

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

exec bash "$SCRIPT_DIR/update-infhub-website.sh" --restart-only --yes "$@"
