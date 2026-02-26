# Header Component
# Application header with logo, user info, and controls

import from react { memo, Fragment }
import from "lucide-react" { Bot, LogOut, ChevronDown, BarChart3 }
import from .ThemeToggle { ThemeToggle }
import from .UserAvatar { UserAvatar }
import from "@jac/runtime" { jacLogout, useNavigate }

def HeaderComponent(isDarkMode: bool, onToggleTheme: any, onToggleAnalytics: any = None) -> any {
    navigate = useNavigate();

    def handleLogout(e: any) -> None {
        e.preventDefault();
        jacLogout();
        navigate("/login");
    }
    return <header className="h-16 px-2 md:px-6 flex items-center justify-between border-b border-border/50 bg-card/50 backdrop-blur-xl">
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
            {
                (<button onClick={onToggleAnalytics} className="control-button w-9 h-9 bg-muted/50 text-muted-foreground hover:bg-muted hover:text-foreground">
                    <BarChart3 className="w-4 h-4" />
                </button>) if onToggleAnalytics else (<Fragment />)
            }
            <UserAvatar />
            <button onClick={lambda e:any -> None {handleLogout(e);}} className="control-button w-9 h-9 bg-destructive/10 text-destructive hover:bg-destructive/20">
                <LogOut  className="w-4 h-4" />
            </button>
        </div>
    </header>;
}

glob:pub Header = memo(HeaderComponent);
