import { NextRequest, NextResponse } from 'next/server';
import { getRatelimit } from '@/lib/rateLimit';
import { verifySession } from '@/lib/auth';
import { z } from 'zod';

const loginSchema = z.object({
    username: z.string().min(1),
    password: z.string().min(1),
});

export async function POST(request: NextRequest) {
    // Rate limit
    const { success } = await getRatelimit().limit('lounge-auth');
    if (!success) {
        return NextResponse.json({ error: 'Too many requests' }, { status: 429 });
    }

    // Authentication check
    const session = await verifySession();
    if (!session) {
        return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // Validate input
    const body = await request.json();
    const parsed = loginSchema.safeParse(body);
    if (!parsed.success) {
        return NextResponse.json({ error: 'Missing username or password' }, { status: 400 });
    }

    const { username, password } = parsed.data;

    // The Lounge server details (uses environment variables)
    const loungeHost = process.env.LOUNGE_HOST || 'irc.infhub.org';
    const loungePort = process.env.LOUNGE_PORT || '443';
    const loungeUrl = `https://${loungeHost}:${loungePort}/api/v4/auth/login`;

    const loungeData = JSON.stringify({
        username,
        password,
    });

    try {
        const response = await fetch(loungeUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: loungeData,
            signal: AbortSignal.timeout(10000),
        });

        if (response.status === 200) {
            const loungeResponse = await response.json();

            return NextResponse.json({
                valid: true,
                token: loungeResponse.token ?? null,
                user: {
                    username,
                },
            });
        }

        return NextResponse.json({ valid: false, error: 'Invalid credentials' }, { status: 401 });
    } catch {
        return NextResponse.json({ valid: false, error: 'Authentication service unavailable' }, { status: 503 });
    }
}
