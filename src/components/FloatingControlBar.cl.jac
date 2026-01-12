# FloatingControlBar Component
# Floating pill-shaped control bar with icon-only buttons

import from react { memo, useEffect, useRef }
import from ..utils.mergeCls { cn }

def FloatingControlBarComponent(
    isVisible: bool,
    sessionStatus: str,
    isMicMuted: bool,
    onToggleMicMute: any,
    isAudioPlaybackEnabled: bool,
    onToggleAudioPlayback: any,
    isPTTUserSpeaking: bool,
    onTalkDown: any,
    onTalkUp: any,
    onSaveAndRestart: any,
    onMouseEnter: any,
    onMouseLeave: any
) -> any {
    isConnected = sessionStatus == "CONNECTED";

    # Container classes with visibility animation
    containerClass = cn(
        "floating-control-bar",
        ("floating-control-bar-visible" if isVisible else "floating-control-bar-hidden")
    );

    # Mic button class
    micBtnClass = cn(
        "floating-control-btn",
        ("floating-control-btn-disabled" if not isConnected else (
            "floating-control-btn-active" if isMicMuted else ""
        ))
    );

    # Audio button class
    audioBtnClass = cn(
        "floating-control-btn",
        ("floating-control-btn-disabled" if not isConnected else (
            "floating-control-btn-active" if not isAudioPlaybackEnabled else ""
        ))
    );

    # Voice button class (center, larger)
    voiceBtnClass = cn(
        "floating-voice-btn",
        ("floating-voice-btn-speaking" if isPTTUserSpeaking else ""),
        ("floating-control-btn-disabled" if not isConnected else "")
    );

    # Save and Restart button classes
    actionBtnClass = cn(
        "floating-control-btn",
        ("floating-control-btn-disabled" if not isConnected else "")
    );

    # Mic icon - unmuted
    micIconUnmuted = <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="w-5 h-5"
    >
        <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
        <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
        <line x1="12" x2="12" y1="19" y2="22" />
    </svg>;

    # Mic icon - muted
    micIconMuted = <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="w-5 h-5"
    >
        <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
        <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
        <line x1="12" x2="12" y1="19" y2="22" />
        <line x1="2" x2="22" y1="2" y2="22" />
    </svg>;

    # Audio/headphones icon
    audioIcon = <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="w-5 h-5"
    >
        <path d="M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a9 9 0 0 1 18 0v7a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3" />
    </svg>;

    # Voice/wave icon
    voiceIcon = <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="currentColor"
        className="w-6 h-6"
    >
        <path d="M8.25 4.5a3.75 3.75 0 117.5 0v8.25a3.75 3.75 0 11-7.5 0V4.5z" />
        <path d="M6 10.5a.75.75 0 01.75.75v1.5a5.25 5.25 0 1010.5 0v-1.5a.75.75 0 011.5 0v1.5a6.751 6.751 0 01-6 6.709v2.291h3a.75.75 0 010 1.5h-7.5a.75.75 0 010-1.5h3v-2.291a6.751 6.751 0 01-6-6.709v-1.5A.75.75 0 016 10.5z" />
    </svg>;

    # Save/document icon
    saveIcon = <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="w-5 h-5"
    >
        <path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z" />
        <polyline points="14 2 14 8 20 8" />
    </svg>;

    # Restart/refresh icon
    restartIcon = <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="w-5 h-5"
    >
        <path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8" />
        <path d="M21 3v5h-5" />
        <path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16" />
        <path d="M8 16H3v5" />
    </svg>;

    return <div
        className={containerClass}
        onMouseEnter={onMouseEnter}
        onMouseLeave={onMouseLeave}
    >
        <button
            onClick={onToggleMicMute}
            disabled={not isConnected}
            className={micBtnClass}
            title={("Unmute microphone") if isMicMuted else ("Mute microphone")}
        >
            {micIconMuted if isMicMuted else micIconUnmuted}
        </button>

        <button
            onClick={onToggleAudioPlayback}
            disabled={not isConnected}
            className={audioBtnClass}
            title={("Enable audio") if not isAudioPlaybackEnabled else ("Disable audio")}
        >
            {audioIcon}
        </button>

        <button
            onMouseDown={onTalkDown}
            onMouseUp={onTalkUp}
            onTouchStart={onTalkDown}
            onTouchEnd={onTalkUp}
            disabled={not isConnected}
            className={voiceBtnClass}
            title="Hold to talk"
        >
            {voiceIcon}
        </button>

        <button
            onClick={onSaveAndRestart}
            disabled={not isConnected}
            className={actionBtnClass}
            title="Save"
        >
            {saveIcon}
        </button>

        <button
            onClick={onSaveAndRestart}
            disabled={not isConnected}
            className={actionBtnClass}
            title="Restart"
        >
            {restartIcon}
        </button>
    </div>;
}

glob:pub FloatingControlBar = memo(FloatingControlBarComponent);
