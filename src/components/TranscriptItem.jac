# TranscriptItem Component
# Renders a single transcript message with role-based styling

cl def TranscriptItem(props: any) -> any {
    item = props.item;
    role = item.role;
    content = item.content;
    
    isUser = role == "user";
    isSystem = role == "system" or role == "tool";
    
    bgColor = "#1f2937" if isUser else ("#fef3c7" if isSystem else "#f3f4f6");
    textColor = "#fff" if isUser else "#000";
    
    return <div style={{
        "display": "flex",
        "flexDirection": "column",
        "alignItems": ("flex-end" if isUser else "flex-start")
    }}>
        <div style={{
            "maxWidth": "32rem",
            "padding": "0.75rem",
            "borderRadius": "0.75rem",
            "backgroundColor": bgColor,
            "color": textColor
        }}>
            <div style={{
                "fontSize": "0.75rem",
                "color": ("#9ca3af" if isUser else "#6b7280"),
                "marginBottom": "0.25rem",
                "textTransform": "uppercase",
                "fontWeight": "600"
            }}>
                {role}
            </div>
            <div>{content}</div>
        </div>
    </div>;
}
