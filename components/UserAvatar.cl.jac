# UserAvatar Component
# Displays user avatar with name and role (no dropdown interaction)

import from react { memo, useState, useEffect }
import from "lucide-react" { ChevronDown, User }

def UserAvatarComponent() -> any {
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

    return <button className="flex items-center gap-3 md:px-3 md:py-2 rounded-xl bg-secondary/50 md:border border-border/50 hover:bg-secondary/70 transition-colors group">
        <div className="md:w-8 md:h-8 rounded-full bg-primary flex items-center justify-center md:ring-2 ring-primary/20">
            <User className="w-5 h-5 text-primary-foreground" />
        </div>
        <div className="text-left md:block hidden">
            <p className="text-sm font-medium text-foreground">{username}</p>

        </div>

    </button>;
}

glob:pub UserAvatar = memo(UserAvatarComponent);
