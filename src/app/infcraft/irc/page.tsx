import { headers } from 'next/headers';

export default async function InfcraftIrcPage() {
    const headersList = await headers();
    const protocol = headersList.get('x-forwarded-proto') || 'https';
    const host = headersList.get('host') || 'localhost:3000';

    // Use The Lounge URL (falls back to irc.infhub.org for local dev)
    const loungeHost = process.env.LOUNGE_HOST || 'irc.infhub.org';
    const loungePort = process.env.LOUNGE_PORT || '443';
    const loungeUrl = `https://${loungeHost}:${loungePort}`;

    return (
        <div style={{ width: '100%', height: '800px' }}>
            <iframe
                src={loungeUrl}
                style={{ width: '100%', height: '100%', border: 'none' }}
                title="INFHUB IRC Chat"
            />
        </div>
    );
}
