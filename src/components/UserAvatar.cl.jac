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
        <div className="user-avatar-circle">
            <span className="user-avatar-initials">{initials}</span>
        </div>
        <div className="flex flex-col">
            <span className="text-sm font-medium text-text-primary">{username}</span>
            <span className="text-xs text-text-secondary">{"Pro Member"}</span>
        </div>
        <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 20 20"
            fill="currentColor"
            className="w-4 h-4 text-text-secondary"
        >
            <path fillRule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clipRule="evenodd" />
        </svg>
    </div>;
}

glob:pub UserAvatar = memo(UserAvatarComponent);
