import { ServerBox } from '@/app/components/ServerBox';
import styles from './page.module.css';

export default function HomePage() {
    return (
        <div className={styles.container}>
            {/* ASCII Art Section */}
            <div className={styles.asciiWrapper}>
                <pre className={styles.bunnyAsciiLeft}>
                    {/* Server-side rendered via server component — no client JS needed */}
                    Bunny ASCII art renders here (server component)
                </pre>
                <div className={styles.logoContainer}>
                    <pre className={styles.logoAscii}>
                        INFHUB ASCII logo renders here (server component)
                    </pre>
                </div>
                <pre className={styles.bunnyAsciiRight}>
                    Bunny ASCII art renders here (server component)
                </pre>
            </div>

            {/* Server Boxes */}
            <div className={styles.boxContainers}>
                <ServerBox
                    id="infcraftBox"
                    name="INFCRAFT"
                    imageSrc="/img/logo/infcraft/infcraft_logo.png"
                    imageAlt="INFCRAFT"
                    href="https://infcraft.infhub.org"
                />
                <ServerBox
                    id="inftaleBox"
                    name="INFTALE"
                    imageSrc="/img/misc/pixel_art_burger.png"
                    imageAlt="INFTALE"
                    href="/infcraft"
                />
                <ServerBox
                    id="infrrariaBox"
                    name="INFRRARIA"
                    imageSrc="/img/misc/pixel_art_burger.png"
                    imageAlt="INFRRARIA"
                    href="/infcraft"
                />
            </div>
        </div>
    );
}
