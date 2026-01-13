# UserAvatar Component
# Displays user avatar with name and role (no dropdown interaction)

import from react { memo, useState, useEffect }
import from "lucide-react" { ChevronDown }

def UserAvatarComponent() -> any {
    [username, setUsername] = useState("User");
    [initials, setInitials] = useState("U");

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
                            # Get initials from username
                            nameParts = payload.username.split(" ");
                            if nameParts.length >= 2 {
                                setInitials(nameParts[0][0].toUpperCase() + nameParts[1][0].toUpperCase());
                            } else {
                                setInitials(payload.username[0].toUpperCase());
                            }
                        }
                    }
                } except Exception as decode_error {
                    console.error("Failed to decode token:", decode_error);
                }
            }
        },
        []
    );

    return <button className="flex items-center gap-3 px-3 py-2 rounded-xl bg-secondary/50 border border-border/50 hover:bg-secondary/70 transition-colors group">
        <div className="w-8 h-8 rounded-full bg-primary flex items-center justify-center ring-2 ring-primary/20">
            <span className="text-primary-foreground font-semibold text-xs">{initials}</span>
        </div>
        <div className="text-left">
            <p className="text-sm font-medium text-foreground">{username}</p>
            <p className="text-[10px] text-muted-foreground">{"Pro Member"}</p>
        </div>
        <ChevronDown className="w-4 h-4 text-muted-foreground group-hover:text-foreground transition-colors" />
    </button>;
}

glob:pub UserAvatar = memo(UserAvatarComponent);
