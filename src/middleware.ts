import { NextRequest, NextResponse } from 'next/server';

/**
 * Hostname-based routing for INFHUB subdomains.
 *
 * Maps incoming hostnames to internal application paths:
 *   cjwijz.infhub.org       → /cjwijz
 *   infcraft.infhub.org     → /infcraft
 *   www.infcraft.infhub.org → /infcraft
 *
 * Uses internal rewrites so the browser URL remains unchanged.
 * Framework internals and API routes are excluded.
 */
const SUBDOMAIN_MAP: Record<string, string> = {
    'cjwijz.infhub.org': '/cjwijz',
    'infcraft.infhub.org': '/infcraft',
    'www.infcraft.infhub.org': '/infcraft',
};

export function middleware(request: NextRequest) {
    const host = request.headers.get('host')?.split(':')[0] || '';
    const rewrite = SUBDOMAIN_MAP[host];

    if (!rewrite) {
        return NextResponse.next();
    }

    const pathname = request.nextUrl.pathname;

    // Skip framework internals and API routes
    if (
        pathname.startsWith('/_next/') ||
        pathname.startsWith('/_headers') ||
        pathname.startsWith('/_redirects') ||
        pathname.startsWith('/api/')
    ) {
        return NextResponse.next();
    }

    // Avoid routing loops: if already rewritten, don't rewrite again
    if (pathname.startsWith(rewrite)) {
        return NextResponse.next();
    }

    const url = request.nextUrl.clone();
    url.pathname = rewrite + pathname;
    return NextResponse.rewrite(url);
}

export const config = {
    matcher: '/:path*',
};
