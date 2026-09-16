import yokImage from '@/img/pages/cjwijz/yok.png';
import styles from './page.module.css';

export default function CjwijzPage() {
    return (
        <main className={styles.main}>
            <div className={styles.yokContainer}>
                <img
                    src={yokImage.src}
                    alt="yok"
                    className={styles.yokImage}
                />
            </div>
        </main>
    );
}
