# Header Component
# Application header with logo, user info, and controls

import from react { memo }
import from "lucide-react" { Bot, LogOut, ChevronDown }
import from .ThemeToggle { ThemeToggle }
import from .UserAvatar { UserAvatar }

def HeaderComponent(isDarkMode: bool, onToggleTheme: any) -> any {
    return <header className="h-16 px-6 flex items-center justify-between border-b border-border/50 bg-card/50 backdrop-blur-xl">
        <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
                <Bot className="w-5 h-5 text-primary" />
            </div>
            <div>
                <h1 className="text-lg font-semibold text-foreground">{"Algo"}</h1>
                <p className="text-xs text-muted-foreground">{"AI Assistant"}</p>
            </div>
        </div>

        <div className="flex items-center gap-3">
            <ThemeToggle isDarkMode={isDarkMode} onToggle={onToggleTheme} />
            <UserAvatar />
            <button className="control-button w-9 h-9 bg-destructive/10 text-destructive hover:bg-destructive/20">
                <LogOut className="w-4 h-4" />
            </button>
        </div>
    </header>;
}

glob:pub Header = memo(HeaderComponent);
