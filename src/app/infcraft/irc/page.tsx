import styles from '../styles/infcraft.module.css';

export default function InfcraftIrcPage() {
    // Use The Lounge service inside Compose, with a public fallback for local use.
    const loungeHost = process.env.LOUNGE_HOST || 'irc.infhub.org';
    const loungePort = process.env.LOUNGE_PORT || '443';
    const loungeUrl = `https://${loungeHost}:${loungePort}`;

    return (
        <div className={styles.ircFrameWrapper}>
            <iframe
                className={styles.ircFrame}
                src={loungeUrl}
                title="INFHUB IRC Chat"
            />
        </div>
    );
}
