# UserAvatar Component
# Displays user avatar with name and role (no dropdown interaction)

import from react { memo, useState, useEffect }

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

    return <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-full bg-primary flex items-center justify-center">
            <span className="text-white font-semibold text-sm">{initials}</span>
        </div>
        <div className="flex flex-col">
            <span className="text-sm font-semibold text-text-primary">{username}</span>
            <span className="text-xs text-text-secondary">{"Pro Member"}</span>
        </div>
    </div>;
}

glob:pub UserAvatar = memo(UserAvatarComponent);
