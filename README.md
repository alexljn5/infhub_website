# infhub-website

Official website for the INFHUB project, now serving as the central management
point for the complete INFHUB web + database + IRC stack.

## Managed Services

This Docker Compose stack manages four services:

| Service     | Description                          | Port (host) | Internal Port |
|-------------|--------------------------------------|-------------|---------------|
| `php-app`   | Apache + PHP 8.4 web application     | 8080        | 80            |
| `db`        | MariaDB 11 (database)                | — (internal)| 3306          |
| `inspircd`  | InspIRCd 4.x IRC server              | 6667, 6697  | 6667, 6697    |
| `lounge`    | The Lounge IRC web client            | 9000        | 9000          |

All services run on a shared `infhub-network` (bridge). TheLounge connects to
InspIRCd via the Compose service name `inspircd` (e.g., `inspircd:6667` for
plaintext or `inspircd:6697` for TLS).

## Persistent Data

| Data                  | Location                                              | Type         |
|-----------------------|-------------------------------------------------------|--------------|
| MariaDB data           | `db-data` Docker volume                               | Named volume |
| InspIRCd data          | `inspircd-data` Docker volume                         | Named volume |
| InspIRCd config        | `/home/alexljn5/INFHUB/inf_irc/inspircd/run`          | Bind mount   |
| TheLounge config       | `/home/alexljn5/.thelounge`                           | Bind mount   |
| IRC TLS certificate    | `/etc/ssl/certs/irc.crt`                              | Bind mount   |

MariaDB is **not** exposed to the host — it is accessible only from other
containers on the `infhub-network`.

## Quick Start

```bash
cd ~/INFHUB/infhub-website
./start-infhub-website.sh
```

This will:
1. Check prerequisites (Docker, Docker Compose)
2. Ensure `.env` exists (creates from `.env.example` if needed)
3. Stop any existing screen-based TheLounge
4. Back up existing configs to `backups/`
5. Build and start all four services
6. Wait for health checks to pass
7. Verify TheLounge can reach InspIRCd

## Management Scripts

| Script                       | Description                                      |
|------------------------------|--------------------------------------------------|
| `start-infhub-website.sh`    | Start the full stack (website, db, IRC, lounge)  |
| `stop-infhub-website.sh`     | Stop the full stack (data preserved)             |
| `update-infhub-website.sh`   | Pull images, rebuild, restart (data preserved)   |

### Script Options

```bash
./start-infhub-website.sh --yes        # Non-interactive (cron-friendly)
./start-infhub-website.sh --no-build   # Skip image rebuild
./start-infhub-website.sh --help       # Show help

./stop-infhub-website.sh --force       # Stop without confirmation

./update-infhub-website.sh --yes       # Non-interactive update
```

All scripts use absolute paths and work from cron/non-interactive shells.

## How TheLounge Connects to InspIRCd

TheLounge is configured to connect to InspIRCd via the Docker Compose network.
The TheLounge `networks.json` config should reference the InspIRCd service:

```json
{
  "name": "INFHUB",
  "servers": [
    {
      "host": "inspircd",
      "port": "6667",
      "tls": false
    }
  ]
}
```

For TLS (port 6697), set `"tls": true` and ensure the IRC certificate is
mounted at `/etc/ssl/certs/irc.crt` inside the TheLounge container.

## InspIRCd Configuration

InspIRCd config is bind-mounted from the host at:
`/home/alexljn5/INFHUB/inf_irc/inspircd/run`

The InspIRCd binary is built into the Docker image from `inspircd/Dockerfile`.
To rebuild the image after updating the binary:

```bash
cp /home/alexljn5/INFHUB/inf_irc/inspircd/inspircd inspircd/
cp -r /home/alexljn5/INFHUB/inf_irc/inspircd/modules/*.so inspircd/modules/
docker compose build inspircd
```

## Migration from Screen-based TheLounge

The old screen-based TheLounge launcher is no longer needed. The
`start-infhub-website.sh` script will:
1. Detect and stop any running `screen` session named `thelounge`
2. Kill any lingering `thelounge` processes
3. Back up the existing `/home/alexljn5/.thelounge` config
4. Start TheLounge as a Docker container

## Backups

The start and update scripts automatically create backups in `backups/`:
- TheLounge config backup
- InspIRCd config backup
- MariaDB database dump

## Production Deployment

For production, place the stack behind a reverse proxy (Nginx, Caddy, or
Traefik) with HTTPS. See `DEPLOY.md` for detailed instructions.

## Prerequisites

- Docker Engine 24.0+
- Docker Compose v2.20+ (plugin)
- Git (for cloning the repository)

```bash
docker --version
docker compose version
```
