# MessageInput Component
# Text input field with send button, voice call button, and suggestion chips

import from ..utils.mergeCls { cn }
import from .SuggestionChips { SuggestionChips }

def:pub MessageInput(
    userText: str,
    setUserText: any,
    onSend: any,
    suggestions: list = [],
    onSelectSuggestion: any = None,
    sessionStatus: str = "DISCONNECTED",
    onToggleConnection: any = None
) -> any {
    
    # Compute connection state
    isConnected = sessionStatus == "CONNECTED";
    isConnecting = sessionStatus == "CONNECTING";
    
    # Voice button styling
    voiceBtnClass = cn(
        "w-12 h-12 rounded-full border-none flex items-center justify-center transition-all",
        (
            "bg-error text-white cursor-pointer hover:opacity-90" if isConnected else (
                "bg-gray-300 text-gray-500 cursor-not-allowed opacity-70" if isConnecting else 
                "bg-success text-white cursor-pointer hover:opacity-90"
            )
        )
    );
    
    # Voice call icon SVG - for connecting
    voiceConnectIcon = <svg
        width="20"
        height="20"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
    >
        <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z" />
    </svg>;
    
    # Voice disconnect icon SVG - phone with X/hang up
    voiceDisconnectIcon = <svg
        width="20"
        height="20"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
    >
        <path d="M10.68 13.31a16 16 0 0 0 3.41 2.6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7 2 2 0 0 1 1.72 2v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.42 19.42 0 0 1-3.33-2.67m-2.67-3.34a19.79 19.79 0 0 1-3.07-8.63A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91" />
        <line x1="22" x2="2" y1="2" y2="22" />
    </svg>;
    
    # Choose icon based on connection state
    voiceIcon = voiceDisconnectIcon if isConnected else voiceConnectIcon;
    
    return <div className="border-t border-border bg-surface">
        <SuggestionChips 
            suggestions={suggestions}
            onSelectSuggestion={onSelectSuggestion}
        />
        
        <div className="p-4 flex gap-2">
            <input
                type="text"
                value={userText}
                onChange={lambda e: any -> None { setUserText(e.target.value); }}
                onKeyPress={lambda e: any -> None { if e.key == "Enter" { onSend(); } }}
                placeholder="Click the 📞 for the best experience or type your message here..."
                className="flex-1 px-4 py-3 border border-border rounded-lg text-base bg-surface text-text-primary placeholder:text-text-secondary focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary transition-all"
            />
            <button
                onClick={onToggleConnection}
                disabled={isConnecting}
                title={("Disconnect voice" if isConnected else ("Connecting..." if isConnecting else "Connect voice"))}
                className={voiceBtnClass}
            >
                {voiceIcon}
            </button>
            <button
                onClick={onSend}
                className="px-6 py-3 bg-secondary text-secondary-foreground border-none rounded-lg cursor-pointer font-medium transition-all hover:opacity-90 hover:-translate-y-0.5 active:translate-y-0"
            >
                {"Send"}
            </button>
        </div>
    </div>;
}