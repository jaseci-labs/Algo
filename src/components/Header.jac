# Header Component
# Application header with title and architecture info

cl def Header() -> any {
    return <div style={{
        "padding": "1.25rem",
        "fontSize": "1.125rem",
        "fontWeight": "600",
        "display": "flex",
        "justifyContent": "space-between",
        "alignItems": "center",
        "borderBottom": "1px solid #e5e7eb"
    }}>
        <div style={{"display": "flex", "alignItems": "center"}}>
            <span>{"🎙️ Algo - Your Personal AI Assistant"}</span>
        </div>
        <div style={{"fontSize": "0.875rem", "color": "#6b7280"}}>
            {"Voice Agent → Backend Intelligence → Tools"}
        </div>
    </div>;
}
