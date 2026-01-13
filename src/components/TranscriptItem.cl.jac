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
        "max-w-lg px-4 py-3 rounded-2xl",
        (("bg-primary text-white") if isUser else (
            ("bg-warning/20 text-text-primary") if isSystem else 
            "bg-surface-hover text-text-primary"
        ))
    );
    
    return <div className={containerClass}>
        <div className="text-[10px] uppercase font-semibold tracking-wide px-2 text-text-secondary/60">
            {labelText}
        </div>
        <div className={bubbleClass}>
            <div className="text-sm leading-relaxed">{content}</div>
        </div>
    </div>;
}
