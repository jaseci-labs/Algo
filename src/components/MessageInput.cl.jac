# MessageInput Component
# Text input field with send button, voice call button (with hover trigger for floating control bar)

import from "lucide-react" { Phone, Send }
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

    buttonLabel = ("End voice session" if isConnected else ("Connecting..." if isConnecting else "Start voice session"));

    return <div className="p-4 flex flex-col gap-3">
        <div className="flex gap-2 items-center">
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
                title={buttonLabel}
                className={voiceBtnClass}
            >
                <Phone className="w-5 h-5" />
            </button>
            <button
                onClick={onSend}
                className="w-10 h-10 bg-primary text-white border-none rounded-full cursor-pointer flex items-center justify-center transition-all hover:opacity-90"
                title="Send message"
            >
                <Send className="w-5 h-5" />
            </button>
        </div>
        {isConnected and <div className="text-sm text-text-secondary text-center">
            {buttonLabel}
        </div>}
    </div>;
}
