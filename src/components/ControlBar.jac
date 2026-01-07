# ControlBar Component
# Bottom control bar with connection, PTT, and audio controls

cl{ 
def:pub ControlBar(props: any) -> any {
    # Props
    sessionStatus = props.sessionStatus;
    onToggleConnection = props.onToggleConnection;
    isPTTActive = props.isPTTActive;
    setIsPTTActive = props.setIsPTTActive;
    isPTTUserSpeaking = props.isPTTUserSpeaking;
    onTalkDown = props.onTalkDown;
    onTalkUp = props.onTalkUp;
    isAudioPlaybackEnabled = props.isAudioPlaybackEnabled;
    setIsAudioPlaybackEnabled = props.setIsAudioPlaybackEnabled;
    isMicMuted = props.isMicMuted;
    onToggleMicMute = props.onToggleMicMute;
    onSaveAndRestart = props.onSaveAndRestart;
    
    # Computed values
    isConnected = sessionStatus == "CONNECTED";
    isConnecting = sessionStatus == "CONNECTING";
    
    connectBtnText = "Disconnect" if isConnected else ("Connecting..." if isConnecting else "Connect");
    connectBtnBg = "#dc2626" if isConnected else ("#1f2937" if isConnecting else "#000");
    
    # Mic mute button computed values
    micBtnBg = "#000000" if not isMicMuted else "#dc2626";
    micBtnTitle = "Mute microphone" if not isMicMuted else "Unmute microphone";

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
        style={{"display": "block"}}
    >
        <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
        <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
        <line x1="12" x2="12" y1="19" y2="22" />
        <line x1="8" x2="16" y1="22" y2="22" />
    </svg>;

    # Mic icon SVG - muted
    micIconMuted = <svg
        width="20"
        height="20"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        style={{"display": "block"}}
    >
        <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
        <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
        <line x1="12" x2="12" y1="19" y2="22" />
        <line x1="2" x2="22" y1="2" y2="22" />
    </svg>;

    # Choose the correct icon based on mute state
    micIcon = micIconMuted if isMicMuted else micIconUnmuted;

    return <div style={{
        "padding": "1rem",
        "display": "flex",
        "flexDirection": "row",
        "alignItems": "center",
        "justifyContent": "center",
        "gap": "2rem",
        "borderTop": "1px solid #e5e7eb",
        "backgroundColor": "#fff"
    }}>
        <button
            onClick={onToggleConnection}
            disabled={isConnecting}
            style={{
                "color": "#fff",
                "fontSize": "1rem",
                "padding": "0.5rem",
                "width": "9rem",
                "borderRadius": "0.375rem",
                "border": "none",
                "cursor": ("not-allowed" if isConnecting else "pointer"),
                "backgroundColor": connectBtnBg
            }}
        >
            {connectBtnText}
        </button>

        <button
            onClick={onToggleMicMute}
            disabled={not isConnected}
            title={micBtnTitle}
            style={{
                "color": "#fff",
                "padding": "0.5rem 1rem",
                "borderRadius": "0.375rem",
                "border": "none",
                "cursor": ("not-allowed" if not isConnected else "pointer"),
                "backgroundColor": (micBtnBg if isConnected else "#9ca3af"),
                "transition": "all 0.2s ease",
                "display": "flex",
                "alignItems": "center",
                "justifyContent": "center",
                "minWidth": "3rem"
            }}
        >
            {micIcon}
        </button>

        <div style={{"display": "flex", "flexDirection": "row", "alignItems": "center", "gap": "0.5rem"}}>
            <input
                id="push-to-talk"
                type="checkbox"
                checked={isPTTActive}
                onChange={lambda e: any -> None { setIsPTTActive(e.target.checked); }}
                disabled={not isConnected}
                style={{"width": "1rem", "height": "1rem"}}
            />
            <label htmlFor="push-to-talk" style={{"display": "flex", "alignItems": "center", "cursor": "pointer"}}>
                {"Push to talk"}
            </label>
            <button
                onMouseDown={onTalkDown}
                onMouseUp={onTalkUp}
                onTouchStart={onTalkDown}
                onTouchEnd={onTalkUp}
                disabled={not isPTTActive}
                style={{
                    "padding": "0.25rem 1rem",
                    "border": "none",
                    "borderRadius": "0.375rem",
                    "cursor": ("pointer" if isPTTActive else "not-allowed"),
                    "backgroundColor": ("#d1d5db" if isPTTUserSpeaking else "#e5e7eb"),
                    "color": ("#6b7280" if not isPTTActive else "#000")
                }}
            >
                {"Talk"}
            </button>
        </div>
        
        <div style={{"display": "flex", "flexDirection": "row", "alignItems": "center", "gap": "0.25rem"}}>
            <input
                id="audio-playback"
                type="checkbox"
                checked={isAudioPlaybackEnabled}
                onChange={lambda e: any -> None { setIsAudioPlaybackEnabled(e.target.checked); }}
                disabled={not isConnected}
                style={{"width": "1rem", "height": "1rem"}}
            />
            <label htmlFor="audio-playback" style={{"display": "flex", "alignItems": "center", "cursor": "pointer"}}>
                {"Audio playback"}
            </label>
        </div>
        
        <button
            onClick={onSaveAndRestart}
            disabled={not isConnected}
            style={{
                "color": "#fff",
                "fontSize": "0.875rem",
                "padding": "0.5rem 1rem",
                "borderRadius": "0.375rem",
                "border": "none",
                "cursor": ("not-allowed" if not isConnected else "pointer"),
                "backgroundColor": ("#9ca3af" if not isConnected else "#16a34a"),
                "fontWeight": "600"
            }}
        >
            {"Save & Restart"}
        </button>
    </div>;
}
}