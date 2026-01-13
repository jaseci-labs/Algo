# FloatingControlBar Component
# Floating pill-shaped control bar with icon-only buttons

import from react { memo, useEffect, useRef }
import from "lucide-react" { Mic, MicOff, Volume2, VolumeX, Radio, Save, RotateCcw }
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
            {(<MicOff className="w-5 h-5" />) if isMicMuted else (<Mic className="w-5 h-5" />)}
        </button>

        <button
            onClick={onToggleAudioPlayback}
            disabled={not isConnected}
            className={audioBtnClass}
            title={("Enable audio") if not isAudioPlaybackEnabled else ("Disable audio")}
        >
            {(<VolumeX className="w-5 h-5" />) if not isAudioPlaybackEnabled else (<Volume2 className="w-5 h-5" />)}
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
            <Radio className="w-6 h-6" />
        </button>

        <button
            onClick={onSaveAndRestart}
            disabled={not isConnected}
            className={actionBtnClass}
            title="Save"
        >
            <Save className="w-5 h-5" />
        </button>

        <button
            onClick={onSaveAndRestart}
            disabled={not isConnected}
            className={actionBtnClass}
            title="Restart"
        >
            <RotateCcw className="w-5 h-5" />
        </button>
    </div>;
}

glob:pub FloatingControlBar = memo(FloatingControlBarComponent);
