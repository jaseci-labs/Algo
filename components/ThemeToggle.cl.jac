# ThemeToggle Component
# A button to toggle between light and dark themes

import from react { memo }
import from "lucide-react" { Sun, Moon }

def ThemeToggleComponent(isDarkMode: bool, onToggle: any) -> any {
    return <button
        onClick={onToggle}
        className="p-2 rounded-lg bg-secondary/50 hover:bg-secondary transition-colors duration-200 flex items-center gap-2"
        title={("Switch to light mode") if isDarkMode else ("Switch to dark mode")}
    >
        {(<Sun className="w-5 h-5 text-yellow-400" />) if isDarkMode else (<Moon className="w-5 h-5 text-muted-foreground" />)}
    </button>;
}

glob:pub ThemeToggle = memo(ThemeToggleComponent);
