import { NextRequest, NextResponse } from 'next/server';

const SUBDOMAIN_MAP: Record<string, string> = {
    'cjwijz.infhub.org': '/cjwijz',
    'infcraft.infhub.org': '/infcraft',
};

export function middleware(request: NextRequest) {
    const host = request.headers.get('host')?.split(':')[0] || '';
    const rewrite = SUBDOMAIN_MAP[host];

    if (rewrite) {
        const pathname = request.nextUrl.pathname;

        // Skip internal Next.js paths and static assets
        if (pathname.startsWith('/_next/') || pathname.startsWith('/_headers') || pathname.startsWith('/_redirects')) {
            return NextResponse.next();
        }

        const url = request.nextUrl.clone();
        url.pathname = rewrite + pathname;
        return NextResponse.rewrite(url);
    }

    return NextResponse.next();
}

export const config = {
    matcher: '/:path*',
};
