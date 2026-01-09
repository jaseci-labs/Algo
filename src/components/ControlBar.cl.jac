# ControlBar Component
# Bottom control bar with connection, PTT, and audio controls
# Refactored to use atomic components for flexibility

import from .controls.ConnectButton { ConnectButton }
import from .controls.MicButton { MicButton }
import from .controls.PTTControl { PTTControl }
import from .controls.AudioPlaybackToggle { AudioPlaybackToggle }
import from .controls.SaveButton { SaveButton }

def:pub ControlBar(
    sessionStatus: str,
    onToggleConnection: any,
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
    # Computed value for connected state
    isConnected = sessionStatus == "CONNECTED";

    return <div className="p-4 flex flex-row items-center justify-center gap-8 border-t border-border bg-surface">
        <ConnectButton
            sessionStatus={sessionStatus}
            onToggleConnection={onToggleConnection}
        />

        <MicButton
            isMicMuted={isMicMuted}
            onToggleMicMute={onToggleMicMute}
            isConnected={isConnected}
        />

        <PTTControl
            isPTTActive={isPTTActive}
            setIsPTTActive={setIsPTTActive}
            isPTTUserSpeaking={isPTTUserSpeaking}
            onTalkDown={onTalkDown}
            onTalkUp={onTalkUp}
            isConnected={isConnected}
        />

        <AudioPlaybackToggle
            isAudioPlaybackEnabled={isAudioPlaybackEnabled}
            setIsAudioPlaybackEnabled={setIsAudioPlaybackEnabled}
            isConnected={isConnected}
        />

        <SaveButton
            onSaveAndRestart={onSaveAndRestart}
            isConnected={isConnected}
        />
    </div>;
}