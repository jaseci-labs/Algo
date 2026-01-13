# ControlBar Component
# Bottom control bar with connection, PTT, and audio controls

import from "lucide-react" { Mic, MicOff }
import from ..utils.mergeCls { cn }

def:pub ControlBar(
    sessionStatus: str,
    isPTTActive: bool,
    setIsPTTActive: any,
    isPTTUserSpeaking: bool,
    onTalkDown: any,
    onTalkUp: any,
    isAudioPlaybackEnabled: bool,
    setIsAudioPlaybackEnabled: any,
    isMicMuted: bool,
    onToggleMicMute: any,
    onSaveAndRestart: any
) -> any {
    # Computed values
    isConnected = sessionStatus == "CONNECTED";
    
    micBtnClass = cn(
        "text-primary-foreground px-4 py-2 rounded-md border-none transition-all flex items-center justify-center min-w-12",
        ("cursor-not-allowed bg-muted" if not isConnected else (
            "cursor-pointer" + (" bg-destructive" if isMicMuted else " bg-primary hover:opacity-90")
        ))
    );
    
    micBtnTitle = "Mute microphone" if not isMicMuted else "Unmute microphone";
    
    # Talk button class
    talkBtnClass = cn(
        "px-4 py-1 border-none rounded-md transition-all",
        ("cursor-not-allowed text-muted-foreground bg-muted" if not isPTTActive else (
            "cursor-pointer text-foreground" + (" bg-secondary" if isPTTUserSpeaking else " bg-secondary/50 hover:bg-secondary")
        ))
    );
    
    # Save button class
    saveBtnClass = cn(
        "text-success-foreground text-sm px-4 py-2 rounded-md border-none font-semibold transition-all",
        ("cursor-not-allowed bg-muted" if not isConnected else 
         "cursor-pointer bg-success hover:opacity-90")
    );

    return <div className="p-4 flex flex-row items-center justify-center gap-8 border-t border-border bg-card">;
        <button
            onClick={onToggleMicMute}
            disabled={not isConnected}
            title={micBtnTitle}
            className={micBtnClass}
        >
            {(<MicOff className="w-5 h-5" />) if isMicMuted else (<Mic className="w-5 h-5" />)}
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