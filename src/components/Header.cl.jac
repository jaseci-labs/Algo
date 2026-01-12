# Header Component
# Application header with logo, user info, and controls

import from react { memo }
import from "@jac-client/utils" { jacLogout, useNavigate }
import from .ThemeToggle { ThemeToggle }
import from .UserAvatar { UserAvatar }

def HeaderComponent(isDarkMode: bool, onToggleTheme: any) -> any {
    navigate = useNavigate();

    def handleLogout(e: any) -> None {
        e.preventDefault();
        jacLogout();
        navigate("/login");
    }

    return <header className="px-5 py-3 flex justify-between items-center border-b border-border bg-surface">
        <div className="flex items-center gap-3">
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

        <div className="flex items-center gap-4">
            <ThemeToggle isDarkMode={isDarkMode} onToggle={onToggleTheme} />
            <UserAvatar />
            <button
                onClick={handleLogout}
                className="header-logout-btn"
                title="Logout"
            >
                <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="currentColor"
                    className="w-5 h-5"
                >
                    <path fillRule="evenodd" d="M7.5 3.75A1.5 1.5 0 006 5.25v13.5a1.5 1.5 0 001.5 1.5h6a1.5 1.5 0 001.5-1.5V15a.75.75 0 011.5 0v3.75a3 3 0 01-3 3h-6a3 3 0 01-3-3V5.25a3 3 0 013-3h6a3 3 0 013 3V9A.75.75 0 0115 9V5.25a1.5 1.5 0 00-1.5-1.5h-6zm10.72 4.72a.75.75 0 011.06 0l3 3a.75.75 0 010 1.06l-3 3a.75.75 0 11-1.06-1.06l1.72-1.72H9a.75.75 0 010-1.5h10.94l-1.72-1.72a.75.75 0 010-1.06z" clipRule="evenodd" />
                </svg>
            </button>
        </div>
    </header>;
}

glob:pub Header = memo(HeaderComponent);
