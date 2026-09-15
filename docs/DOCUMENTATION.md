# INFHUB Website Documentation

## Project Overview

INFHUB is a homelab project that provides:
- **Web Application**: Next.js website (host port 8080, container port 3000)
- **Database**: MariaDB 11 (internal only)
- **IRC Server**: InspIRCd 4.x (ports 6667, 6697)
- **Web IRC Client**: The Lounge (port 9000)

## How the Server Works

### Development Mode (Local)

When running `sh start-infhub-dev.sh`, the Next.js development server starts on port 3000.

**Docker Option**: If Docker is installed and the dev image exists, the script automatically starts the dev server and Caddy in Docker containers using `docker-compose-dev.yml`. Caddy runs without SSL in dev mode (`auto_https off`) since domains don't resolve locally.

**Fallback**: If Docker is not available, the script runs Next.js directly on your machine. If Caddy is installed locally, it starts Caddy as a reverse proxy on port 80 proxying to the dev server.

- Next.js uses **Server-Side Rendering (SSR)** by default
- Pages are rendered on the server, then "hydrated" on the client (browser)
- The development server watches for file changes and auto-reloads
- In Docker: file changes are synced via volume mount
- Caddy runs alongside the dev server as a reverse proxy (no SSL in dev)

### Production Mode (Docker)

When running `sh start-infhub-website.sh`, Docker Compose starts all services:

1. **caddy** (Caddy): Reverse proxy with automatic HTTPS (ports 80, 443)
2. **web** (Next.js): Built and served by the production server on port 8080
3. **db** (MariaDB): Database server (internal only, not exposed to host)
4. **inspircd** (InspIRCd): IRC server on ports 6667 and 6697
5. **lounge** (TheLounge): Web IRC client on port 9000

Caddy depends only on the `web` service. InspIRCd and TheLounge have a separate dependency chain (TheLounge depends on InspIRCd).

### Next.js Basics (First Time Users)

Next.js is a React framework. Key concepts:

- **App Router**: Files in `src/app/` define routes (e.g., `src/app/page.tsx` = homepage at `/`)
- **Components**: React components in `src/app/components/`
- **Client Components**: Files with `'use client'` directive run in the browser
- **Server Components**: Default - run on the server for better performance
- **Image Optimization**: Next.js optimizes images automatically (can cause hydration issues with browser extensions)

## Scripts

All scripts are POSIX sh compatible and can be run with `sh`:

- `start-infhub-dev.sh` - Start Next.js dev server locally
- `start-infhub-website.sh` - Start the complete Docker Compose stack
- `stop-infhub-website.sh` - Stop the Docker Compose stack
- `restart-infhub-website.sh` - Safe restart without rebuild
- `update-infhub-website.sh` - Safe update and rebuild

## Running Scripts

```sh
sh start-infhub-dev.sh          # Local development
sh start-infhub-website.sh      # Production startup
sh stop-infhub-website.sh       # Stop services
sh restart-infhub-website.sh    # Restart services
sh update-infhub-website.sh     # Update services
```

## Services

| Service | URL | Port |
|---------|-----|------|
| Web Application | http://localhost:8080 | 8080 |
| Web Application (Caddy - Prod) | http://localhost | 80 |
| Web Application (HTTPS - Prod) | https://infhub.org | 443 |
| Web Application (Caddy - Dev) | http://localhost | 80 |
| The Lounge IRC | http://localhost:9000 | 9000 |
| InspIRCd Plain | irc://localhost:6667 | 6667 |
| InspIRCd TLS | irc://localhost:6697 | 6697 |
| INFCRAFT | http://localhost:8080/infcraft | 8080 |
| INFCRAFT (subdomain) | https://infcraft.infhub.org | 443 |
| Caddy (Prod) | http://localhost / https://infhub.org | 80, 443 |

## DNS & Redirection

For DNS subdomains (e.g., infcraft.infhub.org):
- DNS A record must point to your server IP
- Caddy handles subdomain routing and automatic HTTPS
- Caddy depends only on the `web` service (not on InspIRCd or TheLounge)
- If DNS subdomain doesn't route, check:
  1. DNS A record points to server IP
  2. Caddy container is running (`docker compose ps caddy`)
  3. Ports 80 and 443 are open on the server
  4. Caddy automatically obtains SSL certificates from Let's Encrypt

### How Caddy Works

Caddy is a modern web server that provides:
- **Automatic HTTPS**: Automatically obtains and renews SSL certificates via Let's Encrypt
- **Subdomain routing**: Routes traffic based on the Host header (e.g., `infcraft.infhub.org` → web service)
- **Reverse proxy**: Forwards requests to the Next.js application on port 3000

Caddy is part of the production Docker Compose stack and depends only on the `web` service being healthy. It starts independently of InspIRCd and TheLounge, so even if IRC services are down, Caddy will still serve the web application.

### Caddyfile Configuration

The `Caddyfile` defines routing rules:
```
infhub.org {
    reverse_proxy web:3000
}
infcraft.infhub.org {
    reverse_proxy web:3000
}
```

Each domain directive routes traffic to the Next.js web service running on port 3000 inside the Docker network.

> **Note**: `www.infhub.org` and `www.infcraft.infhub.org` were removed from the Caddyfile because they produce NXDOMAIN (no DNS records exist). See the Docker Network Failure section for details.

## Docker Network Failure — Caddy Missing Network Attachment

### Incident Summary

On one or more occasions, the `infhub-caddy` container was running and reported healthy, but Docker had created it with **no network endpoints**:

```text
docker inspect infhub-caddy
# Status=running Networks={}
```

Inside the container, there was no network configuration at all:

```text
docker exec infhub-caddy ip route
# (empty — no routes)
```

Connectivity to the Docker gateway failed:

```text
docker exec infhub-caddy ping -c 3 172.21.0.1
# ping: sendto: Network unreachable
```

DNS resolution also failed. As a result, Caddy could not reach Let's Encrypt for ACME HTTP-01 validation, and external traffic received Cloudflare 525 (Origin Error).

### Root Cause

Docker Compose declared the correct network attachment in `docker-compose.yml`:

```yaml
caddy:
    networks:
      - infhub-network
```

However, during container recreation, Docker sometimes created the Caddy container **without actually attaching it to the declared network**. The Compose configuration was correct — the failure occurred at the Docker daemon level during container creation/recreation. This is a known Docker Compose race condition.

The existing health check (`curl -f http://localhost:80`) only probed the container's localhost loopback, so it **passed even when Caddy had no network interface**. This masked the failure completely.

### Actual Compose Network

| Property | Value |
|----------|-------|
| Compose network name | `infhub-network` |
| Docker network name | `infhub-website_infhub-network` |
| Subnet | `172.21.0.0/16` |
| Gateway | `172.21.0.1` |

### Symptoms of the Failure

- `docker inspect infhub-caddy` shows `Networks={}`
- `docker exec infhub-caddy ip route` returns nothing (empty)
- `docker exec infhub-caddy ping -c 3 172.21.0.1` returns `Network unreachable`
- `docker exec infhub-caddy getent hosts acme-v02.api.letsencrypt.org` fails (DNS broken)
- Caddy health check reports `healthy` (because it only checks localhost)
- External access produces Cloudflare 525
- Let's Encrypt ACME HTTP-01 validation fails

### Why `Networks={}` and Empty `ip route` Are Significant

- **`Networks={}`**: Docker created the container with zero network interfaces. The container is isolated from all Docker networks, including the one declared in Compose. No inter-container communication, no external DNS, no gateway access.
- **Empty `ip route`**: The container has no routing table entries at all — not even a default route or link-local route. This means no packets can leave the container. This is distinct from a container that has an IP but no default route.

### Manual Emergency Recovery

If you discover Caddy has no network attachment:

```bash
docker network connect infhub-website_infhub-network infhub-caddy
```

After this command, Caddy receives:

```text
eth0: 172.21.0.2/16
default via 172.21.0.1 dev eth0
172.21.0.0/16 dev eth0 scope link src 172.21.0.2
```

Then verify:

```bash
docker exec infhub-caddy ping -c 3 172.21.0.1
docker exec infhub-caddy getent hosts acme-v02.api.letsencrypt.org
```

### Permanent Automated Recovery

The startup script `start-infhub-website.sh` now includes a `recover_caddy_network` function that runs automatically after the stack starts. It:

1. Confirms the Caddy container exists and is running
2. Checks whether Caddy is attached to any Docker network
3. If not attached, dynamically determines the Compose network name and attaches it
4. Verifies the container has an IP address on eth0
5. Verifies a default route exists
6. Verifies connectivity to the Docker gateway
7. Verifies external DNS resolution works
8. Fails loudly if recovery did not work

The function is idempotent — running it repeatedly produces no errors if Caddy is already attached.

To run it manually:

```bash
# The function runs automatically on startup
# To run just the recovery:
docker network connect infhub-website_infhub-network infhub-caddy
```

### Docker DNS Configuration

The host Docker daemon is configured with:

```json
{
  "dns": ["1.1.1.1", "8.8.8.8"]
}
```

Validated with:

```bash
sudo dockerd --validate --config-file=/etc/docker/daemon.json
```

**Important distinction**: DNS configuration alone was **not** the original problem. Caddy had no network interface or default route. Once attached to the Docker network, DNS worked correctly because the daemon-level DNS configuration was already correct.

### Caddy Health Check Improvement

The original health check:

```yaml
test: ["CMD", "curl", "-f", "http://localhost:80"]
```

This checks only the container's localhost loopback. It **passes even when Caddy has no Docker network endpoint**, making it useless for detecting this class of failure.

The improved health check:

```yaml
test: ["CMD", "sh", "-c", "curl -sf http://web:3000/api/health"]
```

This verifies that Caddy can reach the upstream `web` service on port 3000, which **requires a working Docker network connection**. If Caddy has no network, this health check fails.

### Caddy Configuration and ACME

The `Caddyfile` currently serves:

- `infhub.org` — primary site (Let's Encrypt validated successfully)
- `infcraft.infhub.org` — INFCRAFT subdomain (requires DNS A record)

The following hostnames were **removed** from the Caddyfile because they produce NXDOMAIN:

- `www.infhub.org` — no DNS A/AAAA/CNAME record exists
- `www.infcraft.infhub.org` — no DNS A/AAAA/CNAME record exists

Requesting Let's Encrypt certificates for nonexistent domains causes unnecessary ACME failures (NXDOMAIN looking up A/AAAA). If these subdomains are needed, add the DNS records first, then re-enable the corresponding blocks in the Caddyfile.

### Incident Timeline

| Time | Event |
|------|-------|
| T+0 | Caddy container running, reported healthy |
| T+0 | `docker inspect` reveals `Networks={}` |
| T+1 | `ip route` inside container returns empty |
| T+2 | Ping to gateway fails: Network unreachable |
| T+3 | DNS resolution fails inside container |
| T+4 | Let's Encrypt ACME validation fails |
| T+5 | Cloudflare returns 525 (Origin Error) |
| T+6 | **Recovery**: `docker network connect infhub-website_infhub-network infhub-caddy` |
| T+7 | Caddy receives eth0 172.21.0.2/16, default route via 172.21.0.1 |
| T+8 | Ping to gateway succeeds |
| T+9 | DNS resolution works |
| T+10 | Let's Encrypt ACME HTTP-01 validation succeeds for infhub.org |
| T+11 | Cloudflare 525 resolved |

### Verification Commands

After startup or recovery, verify the stack:

```bash
docker compose config
docker compose ps
docker inspect infhub-caddy --format 'Status={{.State.Status}} Networks={{json .NetworkSettings.Networks}}'
docker exec infhub-caddy ip addr
docker exec infhub-caddy ip route
docker exec infhub-caddy ping -c 3 172.21.0.1
docker exec infhub-caddy getent hosts acme-v02.api.letsencrypt.org
docker exec infhub-caddy caddy validate --config /etc/caddy/Caddyfile
curl -vk --resolve infhub.org:443:127.0.0.1 https://infhub.org/
```

## Known Issues & Fixes

### Hydration Error with Dark Reader

If you see hydration errors when using the Dark Reader browser extension:
- The extension modifies CSS variables on the client side, causing server/client mismatch
- Fixed by adding `unoptimized` prop to Image components in `ServerBox.tsx`

### Redirection Issues

If DNS subdomains don't route correctly:
- Check DNS A record is properly configured
- Ensure reverse proxy forwards to the correct port (8080 for web)
- For local development, use `localhost` or `127.0.0.1` instead of domain names

### InspIRCd Crash Loop / TheLounge Unhealthy

If InspIRCd is restarting and TheLounge is unhealthy:
- InspIRCd and TheLounge have a dependency chain: TheLounge depends on InspIRCd
- If InspIRCd crashes, TheLounge will be unhealthy (can't connect to IRC)
- Caddy only depends on the web service, so it starts independently
- Check InspIRCd logs: `docker compose logs inspircd`
- If InspIRCd shows "Invalid command or none given", the Dockerfile CMD needs the `start` argument — ensure `CMD ["/home/inspircd/inspircd/inspircd", "start"]` in `Dockerfile`
- Check TheLounge config: ensure `networks.json` points to `inspircd:6667`
- The startup script will warn (not exit) on InspIRCd/Lounge failures so you can still access the web app and Caddy
- After fixing InspIRCd, rebuild with `docker compose build inspircd`

## Development Docker Setup

For local development in a Docker container:

```sh
sh start-infhub-dev.sh    # Auto-detects Docker, starts dev + Caddy container if available
```

Files for Docker development:
- `docker-compose-dev.yml` - Development Docker Compose configuration (web + caddy)
- `Caddyfile.dev` - Dev Caddy config (no SSL, localhost only)
- `Dockerfile.dev` - Development Docker image (Node 20 Alpine)

The dev script checks if Docker is available and if the dev image exists. If both conditions are met, it starts the dev server and Caddy in containers. Otherwise, it falls back to running Next.js directly (with Caddy if installed locally).

### Dev Caddy

In Docker mode, Caddy runs as a separate container (`infhub-dev-caddy`) using `Caddyfile.dev`, which proxies `localhost` to the dev web container on port 3000. Auto-HTTPS is disabled (`auto_https off`) since dev domains don't resolve locally.

In non-Docker mode, if the `caddy` binary is available, it starts with inline config proxying `localhost` to the Next.js dev server port, also with `auto_https off`.

> **Note**: For domain-based access (e.g., `infhub.dev`), add entries to your `/etc/hosts` file pointing to `127.0.0.1`. Caddy will proxy without SSL in dev mode.

## Project Structure

```
infhub_website/
├── docker-compose.yml      # Production Docker Compose (web, db, inspircd, lounge, caddy)
├── docker-compose-dev.yml  # Development Docker Compose (web + caddy)
├── Dockerfile              # Production Docker image
├── Dockerfile.dev          # Development Docker image
├── Caddyfile               # Production Caddy config (HTTPS, subdomains)
├── Caddyfile.dev           # Dev Caddy config (no SSL, localhost)
├── .env                    # Environment variables
├── docs/                   # Documentation
│   └── DOCUMENTATION.md    # This file
├── src/                    # Source code
│   ├── app/               # Next.js application (App Router)
│   │   ├── page.tsx       # Homepage
│   │   ├── components/    # React components
│   │   └── ...
│   ├── legacy/            # Legacy PHP code
│   └── lib/               # Library files
└── scripts/                # Shell scripts
```

## Notes

- All shell scripts use `#!/usr/bin/env sh` for POSIX compatibility
- ASCII art is displayed in blood red color on script startup
- Data volumes are preserved across restarts
- For local development, use `sh start-infhub-dev.sh` (auto-detects Docker)
- Docker dev container uses `docker-compose-dev.yml` and `Dockerfile.dev`
- The dev script automatically builds the Docker image if it doesn't exist
- Caddy provides automatic HTTPS for subdomains (infhub.org, infcraft.infhub.org) in production
- Caddy runs in dev mode without SSL (auto_https off) since domains don't resolve locally
- Caddy automatically obtains and renews SSL certificates via Let's Encrypt
- The web service still exposes port 8080 for direct access (development/debugging)
- Caddy routes port 80/443 traffic to the web service on port 3000
- Caddy depends only on the `web` service; InspIRCd and TheLounge have a separate dependency chain
- The startup script warns (not exits) on InspIRCd/Lounge failures so the web app and Caddy remain accessible
