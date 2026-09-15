# infhub-website

Official website for the INFHUB project, now serving as the central management
point for the complete INFHUB web + database + IRC stack.

## Architecture

This project is built with **Next.js** (App Router) and follows a modular,
feature-based organisation. See [`docs/STANDARDISATION.md`](docs/STANDARDISATION.md)
for full architectural conventions and coding standards.

### Key Principles

- **Pages as modules**: Each page is a self-contained module with its own
  components, styles, and logic grouped together.
- **Server Components by default**: Pages and components that don't need
  interactivity are Server Components for optimal performance.
- **Scoped styles**: CSS is scoped per module/component via CSS Modules or
  co-located stylesheets. No global scope pollution.
- **TypeScript**: All new code is written in TypeScript with strict mode enabled.
- **API routes are authenticated and rate-limited**: All API endpoints enforce
  authentication and rate limiting per the STANDARDISATION document.

## Managed Services

This Docker Compose stack manages four services:

| Service     | Description                          | Port (host) | Internal Port |
|-------------|--------------------------------------|-------------|---------------|
| `web`       | Next.js 15 web application           | 8080        | 3000          |
| `db`        | MariaDB 11 (database)                | — (internal)| 3306          |
| `inspircd`  | InspIRCd 4.x IRC server              | 6667, 6697  | 6667, 6697    |
| `lounge`    | The Lounge IRC web client            | 9000        | 9000          |

All services run on a shared `infhub-network` (bridge). TheLounge connects to
InspIRCd via the Compose service name `inspircd` (e.g., `inspircd:6667` for
plaintext or `inspircd:6697` for TLS).

## Project Structure

```
project-root/
├── docs/
│   └── STANDARDISATION.md          # Architecture & coding standards
├── src/
│   ├── app/                        # Next.js App Router root
│   │   ├── layout.tsx              # Root layout
│   │   ├── page.tsx                # Home page (/)
│   │   ├── globals.css             # Global styles & design tokens
│   │   ├── api/                    # API route handlers
│   │   │   ├── auth/
│   │   │   │   ├── irc-auth/route.ts
│   │   │   │   └── lounge-auth/route.ts
│   │   │   └── health/route.ts
│   │   ├── infcraft/               # Infcraft feature module
│   │   │   ├── layout.tsx
│   │   │   ├── page.tsx
│   │   │   ├── irc/page.tsx
│   │   │   ├── components/
│   │   │   │   ├── InfcraftHeader.tsx
│   │   │   │   └── AuthControls.tsx
│   │   │   ├── styles/
│   │   │   │   ├── infcraft.module.css
│   │   │   │   ├── header.module.css
│   │   │   │   └── auth.module.css
│   │   ├── components/             # Shared components
│   │   │   ├── Header.tsx
│   │   │   ├── Footer.tsx
│   │   │   └── ServerBox.tsx
│   │   ├── hooks/                  # Shared hooks
│   │   │   └── useClickableBoxes.ts
│   ├── lib/                        # Shared server utilities
│   │   ├── auth.ts
│   │   ├── db.ts
│   │   └── rateLimit.ts
│   ├── types/                      # Shared TypeScript types
│   │   └── index.ts
│   ├── database/
│   │   └── schema.sql
│   ├── img/                        # All active static assets
│   └── legacy/                     # Preserved legacy implementation
│       ├── php/
│       ├── css/
│       └── js/
├── next.config.js
├── tsconfig.json
├── docker-compose.yml
└── .env.example
```

## Quick Start

```bash
cd ~/INFHUB/infhub-website
bash start-infhub-website.sh
```

This will:
1. Check prerequisites (Docker, Docker Compose)
2. Ensure `.env` exists (creates from `.env.example` if needed)
3. Build and start all services
4. Wait for health checks to pass

## Development

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build

# Start production server
npm start
```

## Management Scripts

| Script                       | Description                                      |
|------------------------------|--------------------------------------------------|
| `start-infhub-website.sh`    | Start the full stack (website, db, IRC, lounge)  |
| `stop-infhub-website.sh`     | Stop the full stack (data preserved)             |
| `update-infhub-website.sh`   | Safe update with orphan cleanup and port checks  |
| `restart-infhub-website.sh`  | Safe restart without pulling or rebuilding       |

For routine recovery, use:

```bash
bash restart-infhub-website.sh
```

The restart flow stops the current Next.js container, removes only verified
legacy `php-app` containers, refuses to overwrite an unknown owner of port
`8080`, and then starts the Compose services with health verification. For an
update, use `bash update-infhub-website.sh --yes`.

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

## Production Deployment

For production, place the stack behind a reverse proxy (Nginx, Caddy, or
Traefik) with HTTPS. See `DEPLOY.md` for detailed instructions.

## Prerequisites

- Docker Engine 24.0+
- Docker Compose v2.20+ (plugin)
- Node.js 20+ (for local development)
- Git (for cloning the repository)

```bash
docker --version
docker compose version
node --version
```
