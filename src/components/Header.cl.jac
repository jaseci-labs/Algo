# Header Component
# Application header with title and username display

import from react { useState, useEffect }
import from "@jac-client/utils" { jacLogout, useNavigate }
import from ..utils.mergeCls { cn }

def:pub Header() -> any {
    navigate = useNavigate();
    [username, setUsername] = useState("User");
    
    # Extract username from JWT token on mount
    useEffect(
        lambda -> None {
            token = localStorage.getItem("jac_token");
            if token {
                try {
                    parts = token.split(".");
                    if parts.length > 1 {
                        payload = JSON.parse(atob(parts[1]));
                        if payload.username {
                            setUsername(payload.username);
                        }
                    }
                } except Exception as decode_error {
                    console.error("Failed to decode token:", decode_error);
                }
            }
        },
        []
    );
    
    def handleLogout(e: any) -> None {
        e.preventDefault();
        jacLogout();
        navigate("/login");
    }
    
    return <header className="px-3 md:px-5 py-3 md:py-4 text-base md:text-lg font-semibold flex justify-between items-center border-b border-border bg-surface">
        <div className="flex items-center gap-1 md:gap-2">
            <span className="text-xl md:text-2xl">{"🎙️"}</span>
            <span className="text-text-primary text-sm md:text-base">{"Algo - Your Personal AI Assistant"}</span>
        </div>
        <div className="flex items-center gap-2 md:gap-6">
            <span className="text-xs md:text-sm text-text-secondary font-medium hidden sm:inline">
                {f"👤 {username}"}
            </span>
            <button
                onClick={handleLogout}
                className="px-3 md:px-4 py-1.5 md:py-2 text-xs md:text-sm font-medium text-primary-foreground bg-gradient-to-br from-primary to-secondary border-none rounded-md cursor-pointer transition-all shadow-md hover:opacity-90 hover:-translate-y-0.5 active:translate-y-0"
            >
                {"Logout"}
            </button>
        </div>
    </header>;
}