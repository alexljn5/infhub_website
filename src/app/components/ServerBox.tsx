'use client';

import Image, { type StaticImageData } from 'next/image';
import Link from 'next/link';
import styles from './ServerBox.module.css';

interface ServerBoxProps {
    id: string;
    name: string;
    imageSrc: StaticImageData;
    imageAlt: string;
    href: string;
}

export function ServerBox({ id, name, imageSrc, imageAlt, href }: ServerBoxProps) {
    return (
        <Link href={href} className={`${styles.serverBox} ${styles[id] || ''}`} data-server={id}>
            <Image src={imageSrc} alt={imageAlt} className={styles.serverImage} />
            <p>{name}</p>
        </Link>
    );
}
