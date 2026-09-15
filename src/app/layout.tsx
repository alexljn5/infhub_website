import type { Metadata } from 'next';
import './globals.css';
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
                {children}
                <Footer />
            </body>
        </html>
    );
}
