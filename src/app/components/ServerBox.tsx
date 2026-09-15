'use client';

import Link from 'next/link';
import styles from './ServerBox.module.css';

interface ServerBoxProps {
    id: string;
    name: string;
    imageSrc: string;
    imageAlt: string;
    href: string;
}

export function ServerBox({ id, name, imageSrc, imageAlt, href }: ServerBoxProps) {
    return (
        <Link href={href} className={`${styles.serverBox} ${styles[id] || ''}`} data-server={id}>
            <img src={imageSrc} alt={imageAlt} className={styles.serverImage} />
            <p>{name}</p>
        </Link>
    );
}
