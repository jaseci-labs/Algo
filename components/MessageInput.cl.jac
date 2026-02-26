# MessageInput Component
# Text input field with send button, voice call button (with hover trigger for floating control bar)

import from "lucide-react" { Phone, PhoneOff, Send }
import from ..utils.mergeCls { cn }
import from .SuggestionChips { SuggestionChips }

def:pub MessageInput(
    userText: str,
    setUserText: any,
    onSend: any,
    sessionStatus: str = "DISCONNECTED",
    onToggleConnection: any = None,
    onShowControlBar: any = None,
    onHideControlBar: any = None,
    suggestions: list = [],
    onSelectSuggestion: any = None,
) -> any {

    # Compute connection state
    isConnected = sessionStatus == "CONNECTED";
    isConnecting = sessionStatus == "CONNECTING";

    # Voice button styling - solid colors for better visibility
    voiceBtnClass = cn(
        "control-button w-9 h-9 rounded-lg",
        (
            "bg-destructive text-destructive-foreground hover:bg-destructive/90" if isConnected else (
                "bg-muted text-muted-foreground cursor-not-allowed opacity-70" if isConnecting else
                "bg-primary text-primary-foreground hover:bg-primary/90"
            )
        )
    );

    buttonLabel = ("Disconnect voice" if isConnected else ("Connecting..." if isConnecting else "Connect voice"));

    return <div className="p-4 border-t border-border/30">
     <SuggestionChips
            suggestions={suggestions}
            onSelectSuggestion={onSelectSuggestion}
        />
        <div className="flex items-center gap-2 bg-secondary/50 rounded-xl p-1.5 border border-border/30 focus-within:border-primary/50 transition-colors">
            <input
                type="text"
                value={userText}
                onChange={lambda e: any -> None { setUserText(e.target.value); }}
                onKeyPress={lambda e: any -> None { if e.key == "Enter" { onSend(); } }}
                placeholder="Type a message..."
                className="flex-1 bg-transparent px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none"
            />
            <button
                onClick={onToggleConnection}
                onMouseEnter={onShowControlBar}
                onMouseLeave={onHideControlBar}
                disabled={isConnecting}
                title={buttonLabel}
                className={voiceBtnClass}
            >
                {(<PhoneOff className="w-4 h-4" />) if isConnected else (<Phone className="w-4 h-4" />)}
            </button>
            <button
                onClick={onSend}
                className="control-button w-9 h-9 bg-primary text-primary-foreground hover:bg-primary/90 rounded-lg"
                title="Send message"
            >
                <Send className="w-4 h-4" />
            </button>
        </div>
    </div>;
}
