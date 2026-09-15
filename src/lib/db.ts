/**
 * Database connection utility
 *
 * Uses environment variables for configuration.
 * In production, use a connection pool.
 */

export interface DbConfig {
    host: string;
    database: string;
    user: string;
    password: string;
    charset: string;
}

export function getDbConfig(): DbConfig {
    return {
        host: process.env.DB_HOST || '127.0.0.1',
        database: process.env.DB_NAME || 'infhub_database',
        user: process.env.DB_USER || 'infhub_user',
        password: process.env.DB_PASSWORD || '',
        charset: 'utf8mb4',
    };
}
