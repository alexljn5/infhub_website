import styles from './Footer.module.css';

export function Footer() {
    const year = new Date().getFullYear();

    return (
        <footer className={styles.footer}>
            <p>&copy; {year} INFHUB Project by alexljn5.</p>
        </footer>
    );
}
