import Link from 'next/link';
import styles from './styles/infcraft.module.css';

export default function InfcraftPage() {
    return (
        <div className={styles.mainContent}>
            <h2>Welcome to INFCRAFT</h2>
            <p>This is the forum page for INFCRAFT discussions and community.</p>
            <div className={styles.infcraftButtons}>
                <Link href="/" className={styles.infcraftBtn}>
                    ← Back
                </Link>
                <a
                    href="http://infcraft.infhub.org:8123"
                    target="_blank"
                    rel="noopener noreferrer"
                    className={styles.infcraftBtn}
                >
                    BlueMap
                </a>
            </div>
        </div>
    );
}
