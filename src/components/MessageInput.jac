# MessageInput Component
# Text input field with send button

cl def:pub MessageInput(props: any) -> any {
    userText = props.userText;
    setUserText = props.setUserText;
    onSend = props.onSend;
    
    return <div style={{
        "padding": "1rem",
        "borderTop": "1px solid #e5e7eb",
        "display": "flex",
        "gap": "0.5rem"
    }}>
        <input
            type="text"
            value={userText}
            onChange={lambda e: any -> None { setUserText(e.target.value); }}
            onKeyPress={lambda e: any -> None { if e.key == "Enter" { onSend(); } }}
            placeholder="Type a message..."
            style={{
                "flex": "1",
                "padding": "0.75rem",
                "border": "1px solid #e5e7eb",
                "borderRadius": "0.5rem",
                "fontSize": "1rem"
            }}
        />
        <button
            onClick={onSend}
            style={{
                "padding": "0.75rem 1.5rem",
                "backgroundColor": "#000",
                "color": "#fff",
                "border": "none",
                "borderRadius": "0.5rem",
                "cursor": "pointer",
                "fontWeight": "500"
            }}
        >
            {"Send"}
        </button>
    </div>;
}
