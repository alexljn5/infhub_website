import type { Metadata } from 'next';
import './globals.css';
import { Header } from '@/app/components/Header';
import { Footer } from '@/app/components/Footer';

export const metadata: Metadata = {
    title: 'INFHUB',
    description: 'Official website for the INFHUB project',
    robots: {
        index: false,
        follow: true,
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
                <Header />
                <main style={{ flex: 1, width: '100%' }}>{children}</main>
                <Footer />
            </body>
        </html>
    );
}
