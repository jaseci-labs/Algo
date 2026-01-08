# ControlBar Component
# Bottom control bar with connection, PTT, and audio controls

import from ..utils.mergeCls { cn }

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
    
    # Button classes with conditional styling
    connectBtnClass = cn(
        "text-white text-base py-2 w-36 rounded-md border-none transition-all",
        ("bg-error cursor-pointer hover:opacity-90" if isConnected else (
            "bg-secondary cursor-not-allowed opacity-70" if isConnecting else 
            "bg-black cursor-pointer hover:opacity-90"
        ))
    );
    
    micBtnClass = cn(
        "text-white px-4 py-2 rounded-md border-none transition-all flex items-center justify-center min-w-12",
        ("cursor-not-allowed bg-text-secondary" if not isConnected else (
            "cursor-pointer" + (" bg-error" if isMicMuted else " bg-black hover:opacity-90")
        ))
    );
    
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
        className="block"
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
        className="block"
    >
        <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
        <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
        <line x1="12" x2="12" y1="19" y2="22" />
        <line x1="2" x2="22" y1="2" y2="22" />
    </svg>;

    # Choose the correct icon based on mute state
    micIcon = micIconMuted if isMicMuted else micIconUnmuted;
    
    # Talk button class
    talkBtnClass = cn(
        "px-4 py-1 border-none rounded-md transition-all",
        ("cursor-not-allowed text-text-secondary bg-gray-200" if not isPTTActive else (
            "cursor-pointer text-black" + (" bg-gray-300" if isPTTUserSpeaking else " bg-gray-200 hover:bg-gray-300")
        ))
    );
    
    # Save button class
    saveBtnClass = cn(
        "text-white text-sm px-4 py-2 rounded-md border-none font-semibold transition-all",
        ("cursor-not-allowed bg-text-secondary" if not isConnected else 
         "cursor-pointer bg-success hover:opacity-90")
    );

    return <div className="p-4 flex flex-row items-center justify-center gap-8 border-t border-border bg-surface">
        <button
            onClick={onToggleConnection}
            disabled={isConnecting}
            className={connectBtnClass}
        >
            {connectBtnText}
        </button>

        <button
            onClick={onToggleMicMute}
            disabled={not isConnected}
            title={micBtnTitle}
            className={micBtnClass}
        >
            {micIcon}
        </button>

        <div className="flex flex-row items-center gap-2">
            <input
                id="push-to-talk"
                type="checkbox"
                checked={isPTTActive}
                onChange={lambda e: any -> None { setIsPTTActive(e.target.checked); }}
                disabled={not isConnected}
                className="w-4 h-4 accent-primary"
            />
            <label htmlFor="push-to-talk" className="flex items-center cursor-pointer text-text-primary">
                {"Push to talk"}
            </label>
            <button
                onMouseDown={onTalkDown}
                onMouseUp={onTalkUp}
                onTouchStart={onTalkDown}
                onTouchEnd={onTalkUp}
                disabled={not isPTTActive}
                className={talkBtnClass}
            >
                {"Talk"}
            </button>
        </div>
        
        <div className="flex flex-row items-center gap-1">
            <input
                id="audio-playback"
                type="checkbox"
                checked={isAudioPlaybackEnabled}
                onChange={lambda e: any -> None { setIsAudioPlaybackEnabled(e.target.checked); }}
                disabled={not isConnected}
                className="w-4 h-4 accent-primary"
            />
            <label htmlFor="audio-playback" className="flex items-center cursor-pointer text-text-primary">
                {"Audio playback"}
            </label>
        </div>
        
        <button
            onClick={onSaveAndRestart}
            disabled={not isConnected}
            className={saveBtnClass}
        >
            {"Save & Restart"}
        </button>
    </div>;
}