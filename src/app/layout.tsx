import type { Metadata } from 'next';
import './globals.css';
import { Footer } from '@/app/components/Footer';
import faviconIco from '@/img/logo/favicon/favicon.ico';
import faviconSvg from '@/img/logo/favicon/favicon.svg';

export const metadata: Metadata = {
    title: 'INFHUB',
    description: 'Official website for the INFHUB project',
    robots: {
        index: false,
        follow: true,
    },
    icons: {
        icon: [
            { url: faviconIco.src },
            { url: faviconSvg.src, type: 'image/svg+xml' },
        ],
    },
};

export default function RootLayout({
    children,
}: Readonly<{
    children: React.ReactNode;
}>) {
    return (
        <html lang="en">
            <body>
                {children}
                <Footer />
            </body>
        </html>
    );
}
