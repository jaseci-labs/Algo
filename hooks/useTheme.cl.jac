# useTheme Hook
# Custom hook for managing light/dark theme
import from react { useEffect }

def:pub useTheme() -> dict {
    # Initialize theme from localStorage or system preference
    has isDarkMode: bool = True;

    # Load saved theme on mount
    useEffect(
        lambda -> None { 
            savedTheme = localStorage.getItem("theme");
            if savedTheme {
                isDarkMode = savedTheme == "dark";
            } else {
                # Check system preference
                prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
                isDarkMode = prefersDark;
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
            localStorage.setItem("theme", "dark" if isDarkMode else "light");},
            [isDarkMode]
        );

    # Toggle function
    def toggleTheme() -> None {
        isDarkMode = not isDarkMode;
    }

    return {"isDarkMode": isDarkMode, "toggleTheme": toggleTheme};
}
