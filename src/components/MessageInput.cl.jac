# MessageInput Component
# Text input field with send button, voice call button (with hover trigger for floating control bar)

import from ..utils.mergeCls { cn }

def:pub MessageInput(
    userText: str,
    setUserText: any,
    onSend: any,
    sessionStatus: str = "DISCONNECTED",
    onToggleConnection: any = None,
    onShowControlBar: any = None,
    onHideControlBar: any = None
) -> any {

    # Compute connection state
    isConnected = sessionStatus == "CONNECTED";
    isConnecting = sessionStatus == "CONNECTING";

    # Voice button styling - coral/primary color
    voiceBtnClass = cn(
        "w-10 h-10 rounded-full border-none flex items-center justify-center transition-all",
        (
            "bg-primary text-white cursor-pointer hover:opacity-90" if isConnected else (
                "bg-gray-300 text-gray-500 cursor-not-allowed opacity-70" if isConnecting else
                "bg-primary text-white cursor-pointer hover:opacity-90"
            )
        )
    );

    # Voice call icon SVG - phone
    voiceIcon = <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="currentColor"
        className="w-5 h-5"
    >
        <path fillRule="evenodd" d="M1.5 4.5a3 3 0 013-3h1.372c.86 0 1.61.586 1.819 1.42l1.105 4.423a1.875 1.875 0 01-.694 1.955l-1.293.97c-.135.101-.164.249-.126.352a11.285 11.285 0 006.697 6.697c.103.038.25.009.352-.126l.97-1.293a1.875 1.875 0 011.955-.694l4.423 1.105c.834.209 1.42.959 1.42 1.82V19.5a3 3 0 01-3 3h-2.25C8.552 22.5 1.5 15.448 1.5 6.75V4.5z" clipRule="evenodd" />
    </svg>;

    # Send arrow icon
    sendIcon = <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="currentColor"
        className="w-5 h-5"
    >
        <path d="M3.478 2.404a.75.75 0 00-.926.941l2.432 7.905H13.5a.75.75 0 010 1.5H4.984l-2.432 7.905a.75.75 0 00.926.94 60.519 60.519 0 0018.445-8.986.75.75 0 000-1.218A60.517 60.517 0 003.478 2.404z" />
    </svg>;

    return <div className="p-4 flex gap-2 items-center">
        <input
            type="text"
            value={userText}
            onChange={lambda e: any -> None { setUserText(e.target.value); }}
            onKeyPress={lambda e: any -> None { if e.key == "Enter" { onSend(); } }}
            placeholder="Type a message..."
            className="flex-1 px-4 py-3 border border-border rounded-lg text-base bg-surface text-text-primary placeholder:text-text-secondary focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary transition-all"
        />
        <button
            onClick={onToggleConnection}
            onMouseEnter={onShowControlBar}
            onMouseLeave={onHideControlBar}
            disabled={isConnecting}
            title={("End voice session" if isConnected else ("Connecting..." if isConnecting else "Start voice session"))}
            className={voiceBtnClass}
        >
            {voiceIcon}
        </button>
        <button
            onClick={onSend}
            className="w-10 h-10 bg-primary text-white border-none rounded-full cursor-pointer flex items-center justify-center transition-all hover:opacity-90"
            title="Send message"
        >
            {sendIcon}
        </button>
    </div>;
}
