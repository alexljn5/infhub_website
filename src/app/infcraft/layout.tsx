import { InfcraftHeader } from './components/InfcraftHeader';
import styles from './styles/infcraft.module.css';

export default function InfcraftLayout({
    children,
}: Readonly<{
    children: React.ReactNode;
}>) {
    return (
        <div className={styles.infcraftPage}>
            <InfcraftHeader />
            <div className={styles.mainContent}>{children}</div>
        </div>
    );
}
