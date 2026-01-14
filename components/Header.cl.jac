# Header Component
# Application header with title and username display

import from "@jac-client/utils" { jacLogout, useNavigate }
import from ..utils.mergeCls { cn }

def:pub Header() -> any {
    navigate = useNavigate();
    has username: str = "User";

    def handleLogout(e: any) -> None {
        e.preventDefault();
        jacLogout();
        navigate("/login");
    }

    return <header className="px-5 py-4 text-lg font-semibold flex justify-between items-center border-b border-border bg-surface">
        <div className="flex items-center gap-2">
            <span className="text-2xl">{"🎙️"}</span>
            <span className="text-text-primary">{"Algo - Your Personal AI Assistant"}</span>
        </div>
        <div className="flex items-center gap-6">
            <span className="text-sm text-text-secondary font-medium">
                {f"👤 {username}"}
            </span>
            <button
                onClick={handleLogout}
                className="px-4 py-2 text-sm font-medium text-primary-foreground bg-gradient-to-br from-primary to-secondary border-none rounded-md cursor-pointer transition-all shadow-md hover:opacity-90 hover:-translate-y-0.5 active:translate-y-0"
            >
                {"Logout"}
            </button>
        </div>
    </header>;
}
