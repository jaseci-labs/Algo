# TranscriptItem Component
# Renders a single transcript message with role-based styling

import from ..utils.mergeCls { cn }

def:pub TranscriptItem(item: any) -> any {
    role = item.role;
    content = item.content;
    
    isUser = role == "user";
    isSystem = role == "system" or role == "tool";
    
    # Container alignment based on role
    containerClass = cn(
        "flex flex-col gap-1",
        ("items-end" if isUser else "items-start")
    );
    
    # Role label - small text above or inside bubble
    labelText = ("YOU" if isUser else ("SYSTEM" if isSystem else "ASSISTANT"));
    
    # Message bubble styling based on role
    bubbleClass = cn(
        "max-w-[80%]",
        (("chat-bubble-user") if isUser else (
            ("bg-warning/20 text-text-primary px-4 py-3 rounded-2xl border border-border/30") if isSystem else 
            "chat-bubble-assistant"
        ))
    );
    
    return <div className={cn(containerClass, "animate-fade-in")}>
        <span className="text-[10px] uppercase tracking-wider text-muted-foreground mb-1 block px-2">
            {labelText}
        </span>
        <div className={bubbleClass}>
            <p className="text-sm leading-relaxed">{content}</p>
        </div>
    </div>;
}
