import Link from 'next/link';
import styles from './Header.module.css';

export function Header() {
    return (
        <header className={styles.header}>
            <Link href="/" className={styles.logo}>
                <h1>INFHUB</h1>
            </Link>
        </header>
    );
}
