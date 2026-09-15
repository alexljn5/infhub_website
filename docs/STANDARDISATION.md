# STANDARDISATION

This document defines the architectural conventions, coding standards, and organisational patterns for the INFHUB website project. All code must adhere to these guidelines to ensure consistency, maintainability, and scalability.

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Next.js Conventions](#nextjs-conventions)
3. [Page as Module Pattern](#page-as-module-pattern)
4. [Component Standards](#component-standards)
5. [CSS Organisation](#css-organisation)
6. [JavaScript / TypeScript Standards](#javascript--typescript-standards)
7. [API Route Standards](#api-route-standards)
8. [Asset Management](#asset-management)
9. [Naming Conventions](#naming-conventions)
10. [Environment Variables](#environment-variables)

---

## Project Structure

The project follows the **Next.js App Router** convention with a modular, feature-based organisation:

```
project-root/
├── docs/
│   └── STANDARDISATION.md          # This document
├── src/
│   ├── app/                        # Next.js App Router root
│   │   ├── layout.tsx              # Root layout (wraps all pages)
│   │   ├── page.tsx                # Home page (/)
│   │   ├── globals.css             # Global styles (resets, tokens)
│   │   ├── error.tsx               # Global error boundary
│   │   ├── not-found.tsx           # Global 404 page
│   │   ├── loading.tsx             # Global loading UI
│   │   ├── api/                    # API route handlers
│   │   │   ├── auth/
│   │   │   │   ├── irc-auth/
│   │   │   │   │   └── route.ts    # POST /api/auth/irc-auth
│   │   │   │   └── lounge-auth/
│   │   │   │       └── route.ts    # POST /api/auth/lounge-auth
│   │   │   └── health/
│   │   │       └── route.ts        # GET /api/health
│   │   ├── infcraft/               # Infcraft feature module
│   │   │   ├── layout.tsx          # Infcraft section layout
│   │   │   ├── page.tsx            # /infcraft
│   │   │   ├── irc/
│   │   │   │   └── page.tsx        # /infcraft/irc
│   │   │   ├── components/         # Infcraft-specific components
│   │   │   │   ├── InfcraftHeader.tsx
│   │   │   │   ├── AuthControls.tsx
│   │   │   │   └── ServerBox.tsx
│   │   │   ├── hooks/              # Infcraft-specific hooks
│   │   │   │   └── useAuth.ts
│   │   │   └── styles/             # Infcraft module styles
│   │   │       ├── infcraft.css
│   │   │       ├── header.css
│   │   │       └── auth.css
│   │   └── components/             # Shared/global components
│   │       ├── Header.tsx
│   │       ├── Footer.tsx
│   │       ├── ServerBox.tsx
│   │       └── ClickableBox.tsx
│   ├── lib/                        # Shared utilities & helpers
│   │   ├── db.ts                   # Database connection
│   │   ├── auth.ts                 # Auth utilities
│   │   └── rateLimit.ts            # Rate limiting utility
│   ├── types/                      # TypeScript type definitions
│   │   └── index.ts
│   ├── database/
│   │   └── schema.sql              # Database schema
│   ├── img/                        # Static images & assets
│   │   ├── logo/
│   │   └── misc/
│   └── legacy/                     # Legacy PHP code (phased out)
│       ├── php/
│       ├── css/
│       └── js/
├── public/                         # Static files served at root
│   ├── img/
│   ├── favicon.ico
│   └── ...
├── next.config.js
├── tsconfig.json
├── package.json
└── docker-compose.yml
```

### Key Principles

- **Feature-first organisation**: Each feature (e.g., `infcraft`) owns its pages, components, styles, and hooks.
- **Shared components** live in `src/app/components/` and are imported where needed.
- **No mixing of concerns**: A component file contains only its markup; styles are co-located or in a matching `styles/` directory.
- **Legacy code** is preserved under `src/legacy/` for reference but is not served.

---

## Next.js Conventions

### App Router

This project uses the **Next.js App Router** (`src/app/`). All pages, layouts, and API routes live under this directory.

### File-based Routing

| Route | File |
|-------|------|
| `/` | `src/app/page.tsx` |
| `/infcraft` | `src/app/infcraft/page.tsx` |
| `/infcraft/irc` | `src/app/infcraft/irc/page.tsx` |
| `/api/auth/irc-auth` | `src/app/api/auth/irc-auth/route.ts` |
| `/api/auth/lounge-auth` | `src/app/api/auth/lounge-auth/route.ts` |

### Layouts

- **Root layout** (`src/app/layout.tsx`): Defines `<html>` and `<body>`, imports `globals.css`, includes `<Header />` and `<Footer />`.
- **Feature layouts** (e.g., `src/app/infcraft/layout.tsx`): Wrap feature-specific pages with feature-specific chrome (headers, navigation, etc.).

### Server vs Client Components

- **Default to Server Components**: Pages and components that don't need interactivity or browser APIs should be Server Components.
- **Mark Client Components** with `'use client'` at the top of the file when they use:
  - Event handlers (`onClick`, `onSubmit`, etc.)
  - Browser APIs (`window`, `document`, `localStorage`)
  - React hooks (`useState`, `useEffect`, etc.)
  - Third-party libraries that depend on the browser

---

## Page as Module Pattern

Every page is treated as a **self-contained module**. Its associated files (markup, styles, scripts, data-fetching logic) are grouped together or referenced from a co-located directory.

### Module Anatomy

```
src/app/infcraft/
├── page.tsx              # Page markup (Server Component by default)
├── layout.tsx            # Layout wrapper for this section
├── styles/
│   ├── infcraft.css      # Page/section-level styles
│   └── components.css    # Styles for components in this module
├── components/
│   ├── InfcraftHeader.tsx
│   └── ServerBox.tsx
├── hooks/
│   └── useInfcraftData.ts
└── lib/
    └── fetchServer.ts
```

### Rules

1. **Co-location**: Styles and components that belong to a page live in or near that page's directory.
2. **No global scope pollution**: CSS is scoped to the module. Global styles only exist in `globals.css` (resets, CSS custom properties, typography).
3. **Single responsibility**: Each component does one thing well.
4. **Explicit imports**: Components and styles are imported explicitly — no implicit assumptions about file locations.

---

## Component Standards

### Structure

```tsx
// src/app/infcraft/components/InfcraftHeader.tsx
'use client';  // Only if using hooks or event handlers

import styles from './InfcraftHeader.module.css';

export function InfcraftHeader() {
  return (
    <header className={styles.header}>
      <h1>INFCRAFT</h1>
    </header>
  );
}
```

### Rules

1. **Named exports**: Use named exports (`export function ComponentName`), not default exports.
2. **PascalCase filenames**: `InfcraftHeader.tsx`, not `infcraft_header.tsx` or `InfcraftHeader.jsx`.
3. **CSS Modules preferred**: Use `.module.css` or `.module.scss` for component-scoped styles. For module-level styles that don't fit CSS Modules, use a `styles/` directory with regular CSS files imported into the page or layout.
4. **Props typed**: All props are explicitly typed with TypeScript interfaces or types.
5. **No side effects in render**: Data fetching and side effects belong in Server Components, `useEffect`, or dedicated data-fetching layers.
6. **Accessibility**: All interactive elements have appropriate ARIA attributes, keyboard handlers, and semantic HTML.

---

## CSS Organisation

### Layers

| Layer | Location | Purpose |
|-------|----------|---------|
| Global | `src/app/globals.css` | CSS resets, custom properties (design tokens), typography, utility classes |
| Module | `src/app/[feature]/styles/` | Feature-level and component-level styles |
| Component | `Component.module.css` (co-located) | Scoped styles for a single component |

### CSS Custom Properties (Design Tokens)

Define in `globals.css`:

```css
:root {
  /* Colors */
  --color-bg-primary: #000000;
  --color-bg-secondary: #1a1a1a;
  --color-text-primary: #ffffff;
  --color-text-secondary: #cccccc;
  --color-accent-green: #00FF00;
  --color-accent-red: #FF0000;
  --color-accent-green-dim: #457c46;
  --color-accent-red-dim: #960a0a;

  /* Spacing */
  --space-xs: 4px;
  --space-sm: 8px;
  --space-md: 16px;
  --space-lg: 24px;
  --space-xl: 32px;

  /* Typography */
  --font-family-base: Arial, sans-serif;
  --font-family-mono: monospace;
  --font-size-sm: 12px;
  --font-size-base: 14px;
  --font-size-md: 16px;
  --font-size-lg: 20px;

  /* Borders */
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 12px;

  /* Transitions */
  --transition-fast: 0.15s ease;
  --transition-base: 0.3s ease;
}
```

### Rules

1. **No inline styles** except for truly dynamic values (e.g., `style={{ width: `${percentage}%` }}`).
2. **Use CSS custom properties** for any value that may change or be themed.
3. **BEM or CSS Modules** for naming — no flat global class names outside `globals.css`.
4. **Responsive design**: Use media queries in module CSS, not inline.
5. **Vendor prefixes**: Use Autoprefixer (via Next.js/CSS pipeline) — do not manually add.

---

## JavaScript / TypeScript Standards

### Language

- **TypeScript** is the default for all new code.
- Existing JavaScript files should be migrated to TypeScript when touched.

### File Locations

| Type | Location | Example |
|------|----------|---------|
| Page scripts | Page component itself | `src/app/page.tsx` |
| Client hooks | `hooks/` in feature dir | `src/app/infcraft/hooks/useAuth.ts` |
| Shared hooks | `src/app/hooks/` | `src/app/hooks/useClickOutside.ts` |
| Utilities | `src/app/lib/` | `src/app/lib/api.ts` |
| Types | `src/app/types/` | `src/app/types/index.ts` |

### Rules

1. **TypeScript strict mode**: Enable `strict: true` in `tsconfig.json`.
2. **No `any` types**: Use explicit types, interfaces, or generics.
3. **Named exports only**: `export function`, `export const`, `export class`.
4. **No side effects at module level**: Wrap in functions or use explicit initialisation patterns.
5. **Event handlers**: Use `'use client'` directive and React event types:
   ```tsx
   const handleClick = (e: React.MouseEvent<HTMLButtonElement>) => { ... };
   ```
6. **DOM manipulation**: Avoid `document`/`window` in Server Components. Use refs or client hooks.
7. **Legacy JS migration**: Files under `src/legacy/js/` are preserved but should not be referenced by new code. Migrate functionality to React hooks or client components as needed.

### Legacy JS Migration Map

| Legacy File | New Location | Convert To |
|-------------|-------------|------------|
| `src/js/infhub/infhub_main.js` | `src/app/components/ClickableBox.tsx` | React component with event handler |
| `src/js/infhub/clickableboxes.js` | `src/app/hooks/useClickableBoxes.ts` | Custom hook |
| `src/js/infcraft/infcraft_main.js` | `src/app/infcraft/components/InfcraftHeader.tsx` | React component |
| `src/js/infcraft/infcraft_registration_login_form.js` | `src/app/infcraft/components/AuthControls.tsx` | Client component |

---

## API Route Standards

### Authentication

All API routes **must** be authenticated unless explicitly documented as public (e.g., health check).

### Rate Limiting

All API routes **must** implement rate limiting. Use a shared middleware or utility:

```ts
// src/app/lib/rateLimit.ts
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

export const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(10, '10 s'),
});
```

### Route Handler Pattern

```ts
// src/app/api/auth/irc-auth/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { ratelimit } from '@/lib/rateLimit';
import { verifySession } from '@/lib/auth';

export async function POST(request: NextRequest) {
  // Rate limit
  const { success } = await ratelimit.limit('irc-auth');
  if (!success) {
    return NextResponse.json({ error: 'Too many requests' }, { status: 429 });
  }

  // Authentication check
  const session = await verifySession();
  if (!session) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  // Handle request
  const body = await request.json();
  // ... process ...

  return NextResponse.json({ /* response */ });
}
```

### Rules

1. **All API routes are POST/GET/PUT/DELETE** as appropriate — no GET for mutations.
2. **All routes return JSON** with consistent error format: `{ "error": "message" }`.
3. **All routes are excluded from indexing** via `route.ts` (API routes are not crawlable by default in Next.js, but ensure no `metadata` enables indexing).
4. **Input validation**: Validate all inputs before processing (use Zod or similar).
5. **Error handling**: Catch all errors and return appropriate HTTP status codes.
6. **No secrets in responses**: Never return passwords, tokens, or PII beyond what's necessary.

---

## Asset Management

### Static Assets

- **Images, icons, fonts**: Place in `public/` for files referenced by absolute path (e.g., `/img/logo.png`).
- **Imported assets**: Place in `src/` and import directly (Next.js handles hashing and optimisation).

### Organising Assets

```
public/
├── img/
│   ├── logo/
│   │   ├── favicon.ico
│   │   ├── infhub/
│   │   └── infcraft/
│   └── misc/
├── fonts/
└── ...
```

### Rules

1. **No assets in `src/app/`**: Static assets belong in `public/` or `src/` (imported), never in page directories.
2. **Optimised formats**: Use WebP/AVIF where possible; provide fallbacks.
3. **SVG icons**: Inline small SVGs as React components; store larger SVGs in `public/`.
4. **Legacy assets**: `src/legacy/` preserves old asset paths during migration.

---

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Page file | kebab-case, `page.tsx` | `src/app/infcraft/page.tsx` |
| Component file | PascalCase, `.tsx` | `InfcraftHeader.tsx` |
| Hook file | camelCase, `use*.ts` | `useAuth.ts` |
| API route dir | kebab-case, `route.ts` | `src/app/api/auth/irc-auth/route.ts` |
| CSS module | PascalCase, `.module.css` | `InfcraftHeader.module.css` |
| Styles dir | lowercase, `styles/` | `src/app/infcraft/styles/` |
| Utility file | camelCase, `.ts` | `rateLimit.ts` |
| Type definition | camelCase, `.ts` | `index.ts` |
| Database table | snake_case | `email_verification_tokens` |
| Environment variable | UPPER_SNAKE_CASE | `DB_HOST`, `LOUNGE_PORT` |

---

## Environment Variables

### Convention

- All environment variables are **uppercase with underscores**.
- `.env.example` documents all required and optional variables.
- Runtime variables (Next.js) use `NEXT_PUBLIC_` prefix for client-exposed values.

### Required Variables

```env
DB_HOST=
DB_NAME=
DB_USER=
DB_PASSWORD=
LOUNGE_HOST=
LOUNGE_PORT=
SESSION_SECRET=
```

### Rules

1. **Never commit `.env`** — it is in `.gitignore`.
2. **All secrets are server-side only**: No `NEXT_PUBLIC_` prefix for secrets.
3. **Type-safe access**: Use a validated config object (e.g., with Zod) rather than `process.env` directly.
4. **Docker Compose**: Environment variables are set in `docker-compose.yml` for containerised services.

---

## Migration Checklist

When migrating from legacy PHP/JS to Next.js:

- [ ] Create the page module directory under `src/app/`
- [ ] Convert HTML to TSX (Server Component by default)
- [ ] Move CSS to module-scoped styles
- [ ] Convert JS event handlers to React event handlers
- [ ] Extract shared logic into custom hooks
- [ ] Convert API endpoints to route handlers with auth + rate limiting
- [ ] Add the module to the relevant layout
- [ ] Update `globals.css` with any new design tokens
- [ ] Add TypeScript types for all props and data shapes
- [ ] Test the page at all target viewports
- [ ] Verify API routes are authenticated and rate-limited
- [ ] Confirm no API route is indexed (check robots.txt / metadata)
