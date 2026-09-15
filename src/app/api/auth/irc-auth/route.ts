import { NextRequest, NextResponse } from 'next/server';
import { ratelimit } from '@/lib/rateLimit';
import { verifySession } from '@/lib/auth';
import { z } from 'zod';

const loginSchema = z.object({
    username: z.string().min(1),
    password: z.string().min(1),
});

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

    // Validate input
    const body = await request.json();
    const parsed = loginSchema.safeParse(body);
    if (!parsed.success) {
        return NextResponse.json({ error: 'Missing username or password' }, { status: 400 });
    }

    const { username, password } = parsed.data;

    // Database connection (uses environment variables)
    const host = process.env.DB_HOST || '127.0.0.1';
    const db = process.env.DB_NAME || 'infhub_database';
    const user = process.env.DB_USER || 'infhub_user';
    const pass = process.env.DB_PASSWORD || '';
    const charset = 'utf8mb4';

    const dsn = `mysql:host=${host};dbname=${db};charset=${charset}`;

    try {
        const { default: mysql } = await import('mysql2/promise');
        const connection = await mysql.createConnection({ host, database: db, user, password: pass, charset });

        const [rows] = await connection.execute(
            'SELECT id, username, password_hash, role FROM users WHERE username = ? LIMIT 1',
            [username]
        );
        const userData = (rows as any[])[0];

        await connection.end();

        if (!userData) {
            return NextResponse.json({ valid: false }, { status: 401 });
        }

        return NextResponse.json({
            valid: true,
            user: {
                id: userData.id,
                username: userData.username,
                role: userData.role,
            },
        });
    } catch {
        return NextResponse.json({ error: 'Database connection failed' }, { status: 500 });
    }
}
