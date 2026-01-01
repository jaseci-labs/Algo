# Header Component
# Application header with title and architecture info

cl import from "@jac-client/utils" { jacLogout, useNavigate }

cl def:pub Header() -> any {
    navigate = useNavigate();
    
    def handleLogout(e: any) -> None {
        e.preventDefault();
        jacLogout();
        navigate("/login");
    }
    
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
        <div style={{"display": "flex", "alignItems": "center", "gap": "1.5rem"}}>
            <span style={{"fontSize": "0.875rem", "color": "#6b7280"}}>
                {"Voice Agent → Backend Intelligence → Tools"}
            </span>
            <button
                onClick={handleLogout}
                style={{
                    "padding": "0.5rem 1rem",
                    "fontSize": "0.875rem",
                    "fontWeight": "500",
                    "color": "#ffffff",
                    "background": "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
                    "border": "none",
                    "borderRadius": "6px",
                    "cursor": "pointer",
                    "transition": "all 0.2s",
                    "boxShadow": "0 2px 4px rgba(0,0,0,0.1)"
                }}
            >
                Logout
            </button>
        </div>
    </div>;
}
