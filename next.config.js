/** @type {import('next').NextConfig} */
const nextConfig = {
    experimental: {
        // Enable server actions for form submissions
        serverActions: true,
    },
    // API route size limit for large payloads
    api: {
        bodyParser: {
            sizeLimit: '1mb',
        },
    },
    // Images optimization
    images: {
        unoptimized: false,
    },
    // Strict mode for better development experience
    reactStrictMode: true,
};

module.exports = nextConfig;
