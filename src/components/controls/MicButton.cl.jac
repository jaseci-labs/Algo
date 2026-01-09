# MicButton Component
# Atomic microphone mute/unmute toggle button

import from ...utils.mergeCls { cn }

def:pub MicButton(
    isMicMuted: bool,
    onToggleMicMute: any,
    isConnected: bool
) -> any {
    # Button styling with conditional states
    btnClass = cn(
        "text-white px-4 py-2 rounded-md border-none transition-all flex items-center justify-center min-w-12",
        (
            "cursor-not-allowed bg-text-secondary" if not isConnected else (
                "cursor-pointer" + (" bg-error" if isMicMuted else " bg-black hover:opacity-90")
            )
        )
    );

    btnTitle = "Mute microphone" if not isMicMuted else "Unmute microphone";

    # Mic icon SVG - unmuted
    micIconUnmuted = <svg
        width="20"
        height="20"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="block"
    >\n        <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
        <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
        <line x1="12" x2="12" y1="19" y2="22" />
        <line x1="8" x2="16" y1="22" y2="22" />
    </svg>;

    # Mic icon SVG - muted (with slash)
    micIconMuted = <svg
        width="20"
        height="20"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="block"
    >
        <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
        <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
        <line x1="12" x2="12" y1="19" y2="22" />
        <line x1="2" x2="22" y1="2" y2="22" />
    </svg>;

    # Choose icon based on mute state
    micIcon = micIconMuted if isMicMuted else micIconUnmuted;

    return <button
        onClick={onToggleMicMute}
        disabled={not isConnected}
        title={btnTitle}
        className={btnClass}
    >
        {micIcon}
    </button>;
}
