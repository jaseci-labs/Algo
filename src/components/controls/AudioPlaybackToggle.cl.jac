# AudioPlaybackToggle Component
# Atomic audio playback enable/disable toggle

def:pub AudioPlaybackToggle(
    isAudioPlaybackEnabled: bool,
    setIsAudioPlaybackEnabled: any,
    isConnected: bool
) -> any {
    return <div className="flex flex-row items-center gap-1">
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
    </div>;
}
