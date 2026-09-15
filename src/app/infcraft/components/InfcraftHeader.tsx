import { AuthControls } from './AuthControls';
import styles from '../styles/header.module.css';

export function InfcraftHeader() {
    return (
        <header className={styles.header}>
            <h1>INFCRAFT</h1>
            <AuthControls />
        </header>
    );
}
