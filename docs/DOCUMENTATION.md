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
- Check TheLounge config: ensure `networks.json` points to `inspircd:6667`
- The startup script will warn (not exit) on InspIRCd/Lounge failures so you can still access the web app and Caddy

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
