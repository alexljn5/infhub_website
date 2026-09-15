'use client';

import { useState, useCallback } from 'react';

interface ClickState {
    count: number;
    isClicked: boolean;
}

export function useClickableBoxes(serverIds: string[]) {
    const [clicks, setClicks] = useState<Record<string, ClickState>>(() => {
        const initial: Record<string, ClickState> = {};
        serverIds.forEach((id) => {
            initial[id] = { count: 0, isClicked: false };
        });
        return initial;
    });

    const handleClick = useCallback((serverId: string) => {
        setClicks((prev) => ({
            ...prev,
            [serverId]: { count: prev[serverId].count + 1, isClicked: true },
        }));

        setTimeout(() => {
            setClicks((prev) => ({
                ...prev,
                [serverId]: { ...prev[serverId], isClicked: false },
            }));
        }, 200);
    }, []);

    const handleMouseEnter = useCallback((serverId: string) => {
        // Hover effect handled via CSS class
    }, []);

    const handleMouseLeave = useCallback((serverId: string) => {
        // Hover reset handled via CSS class
    }, []);

    const getClickCount = useCallback((serverId: string) => {
        return clicks[serverId]?.count || 0;
    }, [clicks]);

    const isClicked = useCallback((serverId: string) => {
        return clicks[serverId]?.isClicked || false;
    }, [clicks]);

    return {
        clicks,
        handleClick,
        handleMouseEnter,
        handleMouseLeave,
        getClickCount,
        isClicked,
    };
}
