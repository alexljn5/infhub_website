export interface User {
    id: number;
    username: string;
    email: string;
    role: 'user' | 'moderator' | 'admin';
    avatarUrl?: string;
    bio?: string;
}

export interface Session {
    userId: string;
    username: string;
    role: 'user' | 'moderator' | 'admin';
}

export interface ApiResponse<T = unknown> {
    data?: T;
    error?: string;
    status: number;
}

export interface ServerBoxData {
    id: string;
    name: string;
    imageSrc: string;
    imageAlt: string;
    href: string;
}
