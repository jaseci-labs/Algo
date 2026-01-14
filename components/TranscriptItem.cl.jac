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
        "flex flex-col",
        ("items-end" if isUser else "items-start")
    );
    
    # Message bubble styling based on role
    bubbleClass = cn(
        "max-w-lg px-3 py-2 rounded-xl",
        (("bg-secondary text-secondary-foreground") if isUser else (
            ("bg-warning/20 text-text-primary") if isSystem else 
            "bg-surface-hover text-text-primary"
        ))
    );
    
    # Role label styling
    labelClass = cn(
        "text-xs mb-1 uppercase font-semibold",
        ("text-text-secondary/70" if isUser else "text-text-secondary")
    );
    
    return <div className={containerClass}>
        <div className={bubbleClass}>
            <div className={labelClass}>
                {role}
            </div>
            <div className="text-sm leading-relaxed">{content}</div>
        </div>
    </div>;
}
