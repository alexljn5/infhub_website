'use client';

import { useState, useRef, useEffect } from 'react';
import styles from '../styles/auth.module.css';

export function AuthControls() {
    const [isOpen, setIsOpen] = useState(false);
    const toggleRef = useRef<HTMLButtonElement>(null);
    const dropdownRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        function handleClickOutside(event: MouseEvent) {
            if (
                dropdownRef.current &&
                !dropdownRef.current.contains(event.target as Node) &&
                toggleRef.current &&
                !toggleRef.current.contains(event.target as Node)
            ) {
                setIsOpen(false);
            }
        }

        document.addEventListener('click', handleClickOutside);
        return () => document.removeEventListener('click', handleClickOutside);
    }, []);

    const handleToggle = () => {
        setIsOpen((prev) => !prev);
    };

    return (
        <div className={styles.headerControls}>
            <button id="ircButton" className={styles.ircButton}>
                IRC
            </button>
            <button
                ref={toggleRef}
                id="loginToggleBtn"
                className={styles.loginToggle}
                onClick={handleToggle}
                aria-expanded={isOpen}
                aria-haspopup="true"
            >
                Login/Register
            </button>
            <div
                ref={dropdownRef}
                id="headerAuthDropdown"
                className={`${styles.headerAuthDropdown} ${isOpen ? styles.open : ''}`}
                aria-hidden={!isOpen}
            >
                <div className={`${styles.formContainer} ${styles.compact}`}>
                    <div className={styles.formTabs}>
                        <button className={`${styles.tabButton} ${styles.active}`} data-tab="login">
                            Login
                        </button>
                        <button className={styles.tabButton} data-tab="register">
                            Register
                        </button>
                    </div>

                    <form id="loginForm" className={`${styles.form} ${styles.active}`} method="POST" action="">
                        <div className={styles.formGroup}>
                            <label htmlFor="loginUsername">Username:</label>
                            <input type="text" id="loginUsername" name="username" required />
                        </div>
                        <div className={styles.formGroup}>
                            <label htmlFor="loginPassword">Password:</label>
                            <input type="password" id="loginPassword" name="password" required />
                        </div>
                        <button type="submit" className={styles.submitBtn}>
                            Login
                        </button>
                    </form>

                    <form id="registerForm" className={styles.form} method="POST" action="">
                        <div className={styles.formGroup}>
                            <label htmlFor="registerUsername">Username:</label>
                            <input type="text" id="registerUsername" name="username" required />
                        </div>
                        <div className={styles.formGroup}>
                            <label htmlFor="registerEmail">Email:</label>
                            <input type="email" id="registerEmail" name="email" required />
                        </div>
                        <div className={styles.formGroup}>
                            <label htmlFor="registerPassword">Password:</label>
                            <input type="password" id="registerPassword" name="password" required />
                        </div>
                        <div className={styles.formGroup}>
                            <label htmlFor="registerConfirm">Confirm Password:</label>
                            <input type="password" id="registerConfirm" name="confirm_password" required />
                        </div>
                        <button type="submit" className={styles.submitBtn}>
                            Register
                        </button>
                    </form>
                </div>
            </div>
        </div>
    );
}
