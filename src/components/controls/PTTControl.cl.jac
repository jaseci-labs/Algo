# PTTControl Component
# Atomic Push-to-Talk control (checkbox + label + talk button)

import from ...utils.mergeCls { cn }

def:pub PTTControl(
    isPTTActive: bool,
    setIsPTTActive: any,
    isPTTUserSpeaking: bool,
    onTalkDown: any,
    onTalkUp: any,
    isConnected: bool
) -> any {
    # Talk button class with conditional styling
    talkBtnClass = cn(
        "px-4 py-1 border-none rounded-md transition-all",
        (
            "cursor-not-allowed text-text-secondary bg-gray-200" if not isPTTActive else (
                "cursor-pointer text-black" + (" bg-gray-300" if isPTTUserSpeaking else " bg-gray-200 hover:bg-gray-300")
            )
        )
    );

    return <div className="flex flex-row items-center gap-2">
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
    </div>;
}
