# useTheme Hook
# Custom hook for managing light/dark theme

import from react { useState, useEffect }

def:pub useTheme() -> dict {
    # Initialize theme from localStorage or system preference
    [isDarkMode, setIsDarkMode] = useState(True);

    # Load saved theme on mount
    useEffect(
        lambda -> None {
            savedTheme = localStorage.getItem("theme");
            if savedTheme {
                setIsDarkMode(savedTheme == "dark");
            } else {
                # Check system preference
                prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
                setIsDarkMode(prefersDark);
            }
        },
        []
    );

    # Apply theme class to document
    useEffect(
        lambda -> None {
            if isDarkMode {
                document.documentElement.classList.add("dark");
            } else {
                document.documentElement.classList.remove("dark");
            }
            # Save to localStorage
            localStorage.setItem("theme", "dark" if isDarkMode else "light");
        },
        [isDarkMode]
    );

    # Toggle function
    def toggleTheme() -> None {
        setIsDarkMode(not isDarkMode);
    }

    return {
        "isDarkMode": isDarkMode,
        "toggleTheme": toggleTheme
    };
}
