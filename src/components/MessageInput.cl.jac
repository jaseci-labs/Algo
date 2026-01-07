# MessageInput Component
# Text input field with send button

import from ..utils.mergeCls { cn }

def:pub MessageInput(props: any) -> any {
    userText = props.userText;
    setUserText = props.setUserText;
    onSend = props.onSend;
    
    return <div className="p-4 border-t border-border flex gap-2 bg-surface">
        <input
            type="text"
            value={userText}
            onChange={lambda e: any -> None { setUserText(e.target.value); }}
            onKeyPress={lambda e: any -> None { if e.key == "Enter" { onSend(); } }}
            placeholder="Type a message..."
            className="flex-1 px-4 py-3 border border-border rounded-lg text-base bg-surface text-text-primary placeholder:text-text-secondary focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary transition-all"
        />
        <button
            onClick={onSend}
            className="px-6 py-3 bg-secondary text-secondary-foreground border-none rounded-lg cursor-pointer font-medium transition-all hover:opacity-90 hover:-translate-y-0.5 active:translate-y-0"
        >
            {"Send"}
        </button>
    </div>;
}