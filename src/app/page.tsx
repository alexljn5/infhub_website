import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { ServerBox } from '@/app/components/ServerBox';
import infcraftLogo from '@/img/logo/infcraft/infcraft_logo.png';
import pixelArtBurger from '@/img/misc/pixel_art_burger.png';
import styles from './page.module.css';

async function readAssetText(relativePath: string): Promise<string> {
    return readFile(path.join(process.cwd(), 'src', 'img', relativePath), 'utf8');
}

export default async function HomePage() {
    const bunnyAscii = await readAssetText('misc/bnuuyascii.txt');
    const infhubAscii = await readAssetText('logo/infhub/infhub_ascii.txt');

    return (
        <div className={styles.container}>
            <div className={styles.asciiWrapper}>
                <pre className={styles.bunnyAsciiLeft}>{bunnyAscii}</pre>
                <div className={styles.logoContainer}>
                    <pre className={styles.logoAscii}>{infhubAscii}</pre>
                </div>
                <pre className={styles.bunnyAsciiRight}>{bunnyAscii}</pre>
            </div>

            <div className={styles.boxContainers}>
                <ServerBox
                    id="infcraftBox"
                    name="INFCRAFT"
                    imageSrc={infcraftLogo}
                    imageAlt="INFCRAFT"
                    href="https://infcraft.infhub.org"
                />
                <ServerBox
                    id="inftaleBox"
                    name="INFTALE"
                    imageSrc={pixelArtBurger}
                    imageAlt="INFTALE"
                    href="/infcraft"
                />
                <ServerBox
                    id="infrrariaBox"
                    name="INFRRARIA"
                    imageSrc={pixelArtBurger}
                    imageAlt="INFRRARIA"
                    href="/infcraft"
                />
            </div>
        </div>
    );
}
