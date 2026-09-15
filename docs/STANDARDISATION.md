# INFHUB Standardisation

This document defines the architecture, organisation, and coding conventions for the INFHUB website. The active application is a **Next.js App Router** application. Legacy PHP, CSS, and JavaScript are retained for reference under `src/legacy/` and must not be served as the active application.

The guiding idea is simple: **a page is a module, and a module owns its markup, styles, behaviour, data access, and tests where applicable.**

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Next.js Conventions](#nextjs-conventions)
3. [Page-as-Module Pattern](#page-as-module-pattern)
4. [Components](#components)
5. [HTML and JSX](#html-and-jsx)
6. [CSS Organisation](#css-organisation)
7. [JavaScript and TypeScript](#javascript-and-typescript)
8. [API Routes](#api-routes)
9. [Assets](#assets)
10. [Naming Conventions](#naming-conventions)
11. [Environment Variables](#environment-variables)
12. [Docker and Permissions](#docker-and-permissions)
13. [Legacy Migration](#legacy-migration)
14. [Review Checklist](#review-checklist)

---

## Project Structure

The repository is organised around `src/`. There is **no root `public/` directory** and no active PHP entry point at `src/index.php`.

```text
project-root/
├── docs/
│   └── STANDARDISATION.md
├── src/
│   ├── app/                         # Next.js App Router and page modules
│   │   ├── layout.tsx               # Root layout
│   │   ├── page.tsx                 # Home page
│   │   ├── page.module.css          # Home page styles
│   │   ├── globals.css              # Global reset and design tokens
│   │   ├── api/                     # Route handlers
│   │   │   ├── auth/
│   │   │   │   ├── irc-auth/route.ts
│   │   │   │   └── lounge-auth/route.ts
│   │   │   └── health/route.ts
│   │   ├── components/              # Shared application components
│   │   │   ├── Header.tsx
│   │   │   ├── Header.module.css
│   │   │   ├── Footer.tsx
│   │   │   ├── Footer.module.css
│   │   │   ├── ServerBox.tsx
│   │   │   └── ServerBox.module.css
│   │   ├── hooks/                   # Shared client hooks
│   │   │   └── useClickableBoxes.ts
│   │   └── infcraft/                # INFCRAFT feature module
│   │       ├── layout.tsx
│   │       ├── page.tsx
│   │       ├── irc/page.tsx
│   │       ├── components/
│   │       │   ├── AuthControls.tsx
│   │       │   └── InfcraftHeader.tsx
│   │       └── styles/
│   │           ├── auth.module.css
│   │           ├── header.module.css
│   │           └── infcraft.module.css
│   ├── lib/                         # Shared server-side utilities
│   │   ├── auth.ts
│   │   ├── db.ts
│   │   └── rateLimit.ts
│   ├── types/                       # Shared TypeScript types
│   │   └── index.ts
│   ├── database/
│   │   └── schema.sql
│   ├── img/                         # All static assets
│   │   ├── logo/
│   │   │   ├── favicon.ico
│   │   │   ├── infcraft/infcraft_logo.png
│   │   │   └── infhub/infhub_ascii.txt
│   │   └── misc/
│   │       ├── bnuuyascii.txt
│   │       └── pixel_art_burger.png
│   └── legacy/                      # Preserved legacy implementation
│       ├── index.php
│       ├── css/
│       ├── js/
│       └── php/
├── Dockerfile
├── docker-compose.yml
├── next.config.js
├── package.json
├── tsconfig.json
└── .env.example
```

### Structure rules

- `src/app/` contains routes, layouts, pages, and page-owned components.
- `src/lib/` contains shared server-side utilities such as database, authentication, and rate-limiting code.
- `src/types/` contains shared TypeScript interfaces and response types.
- `src/img/` is the only asset directory used by the active application.
- `src/legacy/` is archival code. It is not imported by new code and is not an application entry point.
- Shared components that are used by more than one feature live in `src/app/components/`.
- Feature-specific components, hooks, styles, and data access live beside the feature page.

---

## Next.js Conventions

### App Router

This project uses the Next.js App Router with `src/app/` as its root. Routing is file-based:

| Route | File |
|---|---|
| `/` | `src/app/page.tsx` |
| `/infcraft` | `src/app/infcraft/page.tsx` |
| `/infcraft/irc` | `src/app/infcraft/irc/page.tsx` |
| `/api/health` | `src/app/api/health/route.ts` |
| `/api/auth/irc-auth` | `src/app/api/auth/irc-auth/route.ts` |
| `/api/auth/lounge-auth` | `src/app/api/auth/lounge-auth/route.ts` |

### Server Components by default

Pages and components are Server Components unless they need browser-only behaviour. Do not add `'use client'` unless the file uses one or more of:

- React state or effects
- Event handlers
- Browser APIs such as `window`, `document`, or `localStorage`
- A browser-dependent third-party library

Client boundaries should be as small as possible. Keep data fetching, database access, and authentication checks in Server Components or route handlers.

### Layouts and metadata

- `src/app/layout.tsx` owns the document shell, global styles, header, and footer.
- Feature layouts own feature-specific navigation or chrome.
- Metadata and robots policy belong in the relevant layout or page.
- API routes must never opt into search indexing.

### TypeScript

- New application code is TypeScript.
- `tsconfig.json` uses strict type checking.
- Use explicit prop, request, response, and data types.
- Do not use `any` in new code. Use a narrow interface, a discriminated union, or a typed database result.
- Prefer named exports for components, hooks, utilities, and route handlers.

---

## Page-as-Module Pattern

A page is a self-contained feature module. Its route file should remain focused on composition, while related concerns live beside it.

```text
src/app/infcraft/
├── page.tsx                 # Route composition
├── layout.tsx               # Feature shell
├── irc/page.tsx             # Child route
├── components/              # Components used only by this feature
│   ├── AuthControls.tsx
│   └── InfcraftHeader.tsx
├── styles/                  # Feature-scoped CSS Modules
│   ├── auth.module.css
│   ├── header.module.css
│   └── infcraft.module.css
├── hooks/                   # Feature-specific client hooks
└── lib/                     # Feature-specific server utilities
```

The home page follows the same pattern with `page.tsx` and `page.module.css` co-located.

### Module rules

1. Keep page composition in the page file.
2. Keep feature-specific components in that feature's `components/` directory.
3. Keep feature-specific CSS in that feature's `styles/` directory or beside the component as a CSS Module.
4. Keep feature-specific hooks in `hooks/`.
5. Keep feature-specific server utilities in `lib/`.
6. Import shared utilities from `src/lib/` and shared types from `src/types/`.
7. Do not reach into another feature's internal files. Use a shared component or a small public API instead.
8. Do not place unrelated global classes or scripts in a page module.

---

## Components

### Component file shape

```tsx
// src/app/components/ServerBox.tsx
'use client';

import Image, { type StaticImageData } from 'next/image';
import Link from 'next/link';
import styles from './ServerBox.module.css';

interface ServerBoxProps {
    id: string;
    name: string;
    imageSrc: StaticImageData;
    imageAlt: string;
    href: string;
}

export function ServerBox({ id, name, imageSrc, imageAlt, href }: ServerBoxProps) {
    return (
        <Link href={href} className={`${styles.serverBox} ${styles[id] || ''}`} data-server={id}>
            <Image src={imageSrc} alt={imageAlt} className={styles.serverImage} />
            <p>{name}</p>
        </Link>
    );
}
```

### Component rules

- Use PascalCase filenames and named exports.
- Put the component and its CSS Module next to each other when the component is shared.
- Put feature-only components inside the feature's `components/` directory.
- Type every prop.
- Use semantic HTML (`header`, `nav`, `main`, `section`, `article`, `button`, and so on).
- Give interactive controls accessible names and keyboard behaviour.
- Do not use a `<div>` when a semantic element communicates the purpose better.
- Do not put business logic inside a presentational component. Pass data in or call a typed utility.
- Do not use client components for static content.

---

## HTML and JSX

The active application uses JSX/TSX rather than standalone HTML files.

### JSX rules

- Keep markup close to the component that owns it.
- Use self-closing tags for void elements.
- Use `className`, `htmlFor`, and `aria-*` attributes.
- Do not use inline styles for fixed layout or presentation. Use CSS Modules.
- Inline styles are allowed only for values that are genuinely dynamic and cannot be represented by a class or CSS custom property.
- Escape or safely render user-provided content. React escapes normal string children by default.
- Do not use raw `dangerouslySetInnerHTML` unless the source is trusted and the reason is documented.
- Keep comments focused on non-obvious intent, not a restatement of the markup.

### Page example

```tsx
export default async function HomePage() {
    const bunnyAscii = await readAssetText('misc/bnuuyascii.txt');

    return (
        <main>
            <pre>{bunnyAscii}</pre>
        </main>
    );
}
```

---

## CSS Organisation

### Layers

| Layer | Location | Responsibility |
|---|---|---|
| Global | `src/app/globals.css` | Reset, design tokens, typography, body-level layout |
| Feature | `src/app/[feature]/styles/` | Feature and page composition styles |
| Component | `Component.module.css` | Styles owned by one component |

### Design tokens

Define reusable values in `globals.css`:

```css
:root {
    --color-bg-primary: #000000;
    --color-bg-secondary: #1a1a1a;
    --color-text-primary: #ffffff;
    --color-accent-green: #00ff00;
    --space-sm: 8px;
    --space-md: 16px;
    --space-lg: 24px;
    --radius-md: 8px;
    --font-family-mono: monospace;
}
```

### CSS rules

- Prefer CSS Modules for component and feature styles.
- Use lowercase module filenames when they live in a feature `styles/` directory.
- Use descriptive class names that reflect purpose, not visual implementation.
- Use custom properties for themeable values.
- Keep responsive rules in the relevant module.
- Do not add vendor prefixes manually; let the Next.js CSS pipeline handle them.
- Do not use global selectors from a module to style unrelated pages.
- Do not keep active CSS under `src/legacy/css/`.

---

## JavaScript and TypeScript

### Language

- TypeScript is the default for all new code.
- Existing JavaScript is retained only under `src/legacy/js/`.
- When legacy behaviour is needed, migrate it to a typed React component or hook.
- Do not load legacy JavaScript with a `<script>` tag from the active application.

### Locations

| Concern | Location | Example |
|---|---|---|
| Page composition | Feature directory | `src/app/infcraft/page.tsx` |
| Shared client hook | `src/app/hooks/` | `useClickableBoxes.ts` |
| Feature client hook | Feature `hooks/` | `src/app/infcraft/hooks/useAuth.ts` |
| Shared server utility | `src/lib/` | `rateLimit.ts` |
| Feature server utility | Feature `lib/` | `src/app/infcraft/lib/fetchServer.ts` |
| Shared types | `src/types/` | `ApiResponse.ts` or `index.ts` |

### TypeScript rules

- Enable strict mode in `tsconfig.json`.
- Use `unknown` before narrowing when a value comes from an external boundary.
- Validate external input with Zod or an equivalent schema.
- Type database rows and API responses instead of casting to `any`.
- Keep hooks in `.ts` files and components in `.tsx` files.
- Use `use client` only at the top of a client module.
- Avoid side effects during module initialisation.
- Use typed event handlers, for example `React.MouseEvent<HTMLButtonElement>`.
- Keep browser APIs inside client components or client hooks.

---

## API Routes

### Security baseline

API routes must be:

- Authenticated
- Rate-limited
- Protected against unvalidated input
- Excluded from search indexing
- Consistent in their JSON error shape

The health endpoint is the explicit public exception because it is used by Docker health checks.

### Route handler shape

```ts
import { NextRequest, NextResponse } from 'next/server';
import { getRatelimit } from '@/lib/rateLimit';
import { verifySession } from '@/lib/auth';
import { z } from 'zod';

const loginSchema = z.object({
    username: z.string().min(1),
    password: z.string().min(1),
});

export async function POST(request: NextRequest) {
    const { success } = await getRatelimit().limit('login');
    if (!success) {
        return NextResponse.json({ error: 'Too many requests' }, { status: 429 });
    }

    const session = await verifySession();
    if (!session) {
        return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const parsed = loginSchema.safeParse(await request.json());
    if (!parsed.success) {
        return NextResponse.json({ error: 'Invalid request' }, { status: 400 });
    }

    return NextResponse.json({ valid: true });
}
```

### API rules

1. Use `route.ts` for App Router handlers.
2. Use the correct HTTP method; never use `GET` for mutations.
3. Return JSON from API routes.
4. Use `{ "error": "message" }` for errors and a consistent success shape.
5. Validate all request bodies, query strings, and path parameters.
6. Catch expected failures and return an appropriate status code.
7. Never return passwords, session tokens, database credentials, or unnecessary PII.
8. Do not use `any` for database rows or request data.
9. Do not add metadata that enables indexing for API routes.
10. Keep authentication and rate-limiting in shared utilities instead of duplicating logic.

---

## Assets

### No `public/` directory

The active application has **no root `public/` directory**. Do not create one and do not reference assets with root URLs such as `/img/logo.png`.

All assets live under `src/img/`:

```text
src/img/
├── logo/
│   ├── favicon.ico
│   ├── infcraft/infcraft_logo.png
│   └── infhub/infhub_ascii.txt
└── misc/
    ├── bnuuyascii.txt
    └── pixel_art_burger.png
```

### Images

Import images from `src/img/` and pass the imported value to `next/image`:

```tsx
import infcraftLogo from '@/img/logo/infcraft/infcraft_logo.png';
import Image from 'next/image';

export function Logo() {
    return <Image src={infcraftLogo} alt="INFCRAFT" />;
}
```

This lets Next.js hash, optimise, and bundle the asset. It also keeps the asset inside the source tree.

### Text and other source assets

For text files that are read by a Server Component, read them from `src/img/` using a typed server-side helper:

```ts
import { readFile } from 'node:fs/promises';
import path from 'node:path';

export async function readAssetText(relativePath: string): Promise<string> {
    return readFile(path.join(process.cwd(), 'src', 'img', relativePath), 'utf8');
}
```

Do not expose raw text files through a manually configured public URL.

### Asset rules

- Keep all active assets under `src/img/`.
- Use descriptive filenames and group by purpose.
- Prefer WebP or AVIF for photographic images where browser support allows it.
- Use SVG for icons when practical.
- Do not duplicate an asset in both `src/img/` and `src/legacy/`.
- Legacy assets remain under `src/legacy/` only as historical references.
- Ensure `Dockerfile` copies `src/img/` into the Next.js build stage.
- Do not mount a host source directory over the production image in a way that changes file ownership or bypasses the built asset pipeline.

---

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Page | `page.tsx` in the route directory | `src/app/infcraft/page.tsx` |
| Route handler | `route.ts` | `src/app/api/health/route.ts` |
| Component | PascalCase `.tsx` | `InfcraftHeader.tsx` |
| CSS Module | PascalCase beside component, or lowercase in feature `styles/` | `ServerBox.module.css`, `auth.module.css` |
| Hook | camelCase, `use*` | `useClickableBoxes.ts` |
| Utility | camelCase `.ts` | `rateLimit.ts` |
| Shared type | PascalCase export in `src/types/` | `ApiResponse` |
| Feature directory | lowercase or product name | `infcraft` |
| Database table | snake_case | `email_verification_tokens` |
| Environment variable | UPPER_SNAKE_CASE | `DB_HOST` |
| Asset directory | lowercase | `src/img/logo/` |

Use kebab-case for route directories and URL segments. Use PascalCase for exported components and types. Do not mix `snake_case`, `kebab-case`, and camelCase within the same kind of file.

---

## Environment Variables

### Convention

- Use `UPPER_SNAKE_CASE`.
- Put secrets in `.env` and never commit that file.
- Keep secrets server-side.
- Only expose a value to client code with the `NEXT_PUBLIC_` prefix.
- Document every required variable in `.env.example`.
- Validate environment-dependent configuration at the boundary where practical.

### Required variables

```env
DB_HOST=db
DB_NAME=infhub_database
DB_USER=infhub_user
DB_PASSWORD=
DB_ROOT_PASSWORD=
LOUNGE_HOST=lounge
LOUNGE_PORT=9000
SESSION_SECRET=
UPSTASH_REDIS_REST_URL=
UPSTASH_REDIS_REST_TOKEN=
NEXT_PUBLIC_URL=http://localhost:8080
```

### Rules

1. Use strong, unique secrets in every environment.
2. Do not put database or Upstash credentials in client components.
3. Do not commit `.env`.
4. Keep Compose defaults aligned with `.env.example`.
5. Treat a missing required variable as a deployment error, not as a reason to silently fall back to production infrastructure.

---

## Docker and Permissions

### Image boundaries

- The Next.js production target is `nextjs-runtime`.
- The runtime image contains the built application, dependencies, and `src/img/` assets.
- The legacy PHP target remains available only for historical reference and is not the active web service.
- The Compose `web` service must build `nextjs-runtime`, not the intermediate build stage.
- The `web` service exposes container port `3000`; the host mapping is `8080:3000`.

### Ownership

The runtime image should run as the Node user and own `/app`:

```dockerfile
RUN chown -R node:node /app
USER node
```

This prevents host bind mounts or root-owned build artifacts from becoming unreadable inside the container.

### Safe management scripts

Use [`update-infhub-website.sh`](../update-infhub-website.sh) for updates and
[`restart-infhub-website.sh`](../restart-infhub-website.sh) for routine restarts.
Both scripts:

- resolve the project directory dynamically
- validate the Compose file before changing containers
- remove only verified legacy `php-app` containers
- stop the current Next.js container before rebinding port `8080`
- refuse to replace an unknown port owner
- preserve persistent volumes
- verify service health after startup

The restart wrapper runs the update script in restart-only mode and is the
preferred plug-and-play recovery command.

### Source mounts

Do not bind-mount the repository's `src/` over `/app/src/` in the production Compose service. It can:

- Replace built assets with host-owned files
- Bypass the asset import and optimisation pipeline
- Introduce inconsistent ownership and permissions
- Make the running image differ from the image that passed the build

For local source watching, use `npm run dev` directly or a dedicated development Compose profile. Production Compose should run the immutable built image.

### 403 diagnosis

A browser-level `403 Forbidden` from `Server: cloudflare` and an Apache signature is not a Next.js asset error. It means the request is still reaching an old Apache/reverse-proxy origin or an old deployment path.

Check the deployment host in this order:

1. Confirm the new service is running:

   ```bash
   docker compose ps
   docker compose logs --tail=100 web
   ```

2. Test the container directly:

   ```bash
   curl -i http://127.0.0.1:3000/api/health
   curl -i http://127.0.0.1:8080/api/health
   ```

3. Check listeners:

   ```bash
   ss -ltnp | grep -E ':(80|3000|8080)\\b'
   ```

4. Confirm the reverse proxy points to the Next.js backend on port `3000` (or host port `8080`, depending on proxy placement).
5. Confirm Cloudflare origin settings point to the current server and not an old origin.
6. Check ownership and read permissions on the deployment checkout if a reverse proxy serves files directly.

`robots.txt` can prevent indexing, but it does not normally cause a browser request to receive an Apache 403.

---

## Legacy Migration

Legacy files are preserved under `src/legacy/` for history and comparison. They are not active application code.

### Migration map

| Legacy area | Next.js destination | Migration form |
|---|---|---|
| `src/legacy/php/pages/` | `src/app/[feature]/page.tsx` | Server Component |
| `src/legacy/php/templates/` | `src/app/components/` or feature `components/` | Reusable component |
| `src/legacy/php/api/` | `src/app/api/` | Authenticated route handler |
| `src/legacy/css/` | CSS Modules in the matching module | Scoped styles |
| `src/legacy/js/` | Client component or `hooks/` | Typed React behaviour |
| `src/legacy/index.php` | No active replacement | Historical reference only |

### Migration checklist

- [ ] Create the route module under `src/app/`.
- [ ] Convert PHP/HTML to TSX.
- [ ] Move presentation styles to a CSS Module.
- [ ] Convert JavaScript event handlers to React handlers or a typed hook.
- [ ] Move shared server logic to `src/lib/` or feature `lib/`.
- [ ] Convert API endpoints to `route.ts` handlers with authentication and rate limiting.
- [ ] Move assets to `src/img/` and import or read them from there.
- [ ] Add TypeScript types for props, API payloads, and database rows.
- [ ] Remove all active references to `src/legacy/`.
- [ ] Test desktop and mobile viewports.
- [ ] Verify API routes are authenticated, rate-limited, and not indexed.

---

## Review Checklist

Before merging a page or feature:

- [ ] The route is represented by the correct `page.tsx` or `route.ts`.
- [ ] The page is organised as a module with co-located concerns.
- [ ] Server and client boundaries are intentional and minimal.
- [ ] All props and external data are typed.
- [ ] No new `any` types were introduced.
- [ ] Styles are scoped to a CSS Module or feature style directory.
- [ ] No active code references `public/`.
- [ ] All active assets are under `src/img/`.
- [ ] Legacy code is only referenced for migration context.
- [ ] API routes are authenticated and rate-limited unless explicitly public.
- [ ] API errors use the standard JSON shape.
- [ ] Metadata and robots settings do not enable indexing for APIs.
- [ ] The Docker runtime target is `nextjs-runtime`.
- [ ] The production container runs as a non-root user with readable assets.
- [ ] The reverse proxy points to the current Next.js service.
