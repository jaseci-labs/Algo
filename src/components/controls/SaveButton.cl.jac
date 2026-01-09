# SaveButton Component
# Atomic save and restart button

import from ...utils.mergeCls { cn }

def:pub SaveButton(
    onSaveAndRestart: any,
    isConnected: bool
) -> any {
    # Button class with conditional styling
    btnClass = cn(
        "text-white text-sm px-4 py-2 rounded-md border-none font-semibold transition-all",
        (
            "cursor-not-allowed bg-text-secondary" if not isConnected else
            "cursor-pointer bg-success hover:opacity-90"
        )
    );

    return <button
        onClick={onSaveAndRestart}
        disabled={not isConnected}
        className={btnClass}
    >
        {"Save & Restart"}
    </button>;
}
