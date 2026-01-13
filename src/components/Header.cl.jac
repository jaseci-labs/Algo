# Header Component
# Application header with logo, user info, and controls

import from react { memo }
import from "lucide-react" { Briefcase, LogOut }
import from .ThemeToggle { ThemeToggle }
import from .UserAvatar { UserAvatar }

def HeaderComponent(isDarkMode: bool, onToggleTheme: any) -> any {
    return <header className="px-6 py-3 flex justify-between items-center border-b border-border bg-surface">
        <div className="flex items-center gap-3">
            # <div className="text-primary">
            #     <Briefcase className="w-7 h-7" />
            # </div>
             <div className="header-logo-icon">
                <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="currentColor"
                    className="w-6 h-6"
                >
                    <path d="M19.5 21a3 3 0 003-3v-4.5a3 3 0 00-3-3h-15a3 3 0 00-3 3V18a3 3 0 003 3h15zM1.5 10.146V6a3 3 0 013-3h5.379a2.25 2.25 0 011.59.659l2.122 2.121c.14.141.331.22.53.22H19.5a3 3 0 013 3v1.146A4.483 4.483 0 0019.5 9h-15a4.483 4.483 0 00-3 1.146z" />
                </svg>
            </div>
            <div className="flex flex-col">
                <span className="text-lg font-bold text-text-primary leading-tight">{"Algo"}</span>
                <span className="text-xs text-text-secondary">{"AI Assistant"}</span>
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
