# TranscriptItem Component
# Renders a single transcript message with role-based styling

import from ..utils.mergeCls { cn }

def:pub TranscriptItem(item: any, showThinking: bool = True) -> any {
    role = item.role;
    content = item.content;
    thinking = item.thinking;

    isUser = role == "user";
    isSystem = role == "system" or role == "tool";
    isAssistant = role == "assistant";

    # State for expandable thinking details
    # Using new has syntax for reactive state
    has showDetails: bool = False;
    
    # Container alignment based on role
    containerClass = cn(
        "flex flex-col gap-1",
        ("items-end" if isUser else "items-start")
    );
    
    # Message bubble styling based on role
    # bubbleClass = cn(
    #     "max-w-lg px-3 py-2 rounded-xl animate-fade-in",
    #     (("bg-secondary text-secondary-foreground") if isUser else (
    #         ("bg-warning/20 text-text-primary") if isSystem else 
    #         "bg-primary-hover text-text-primary"
    #     ))
    # );
    bubbleClass = cn(
    "max-w-[80%] text-[14px] leading-[1] animate-fade-in",
    (("chat-bubble-user") if isUser else (
        ("bg-warning/20 text-text-primary  px-4 py-3 rounded-2xl border border-border/30") if isSystem else 
        "chat-bubble-assistant"
    ))
);
    
    # Role label styling
    labelClass = cn(
        "text-[10px] uppercase tracking-wider  mb-1 block px-2",
        ("text-muted-foreground/70" if isUser else "text-muted-foreground")
    );
    
    # Thinking bubble styling
    thinkingBubbleClass = "text-xs italic text-text-secondary bg-primary/50 px-2 py-1 rounded-lg max-w-lg";
    
    # Check if thinking has any non-empty values
    hasThinking = False;
    if isAssistant and thinking and showThinking {
        emotional = thinking.emotional or "";
        intent = thinking.intent or "";
        tasks = thinking.tasks or "";
        pattern = thinking.pattern or "";
        hasThinking = emotional != "" or intent != "" or tasks != "" or pattern != "";
    }

    return <div className={containerClass}>
        {hasThinking and (
            <div className="flex flex-col gap-1 max-w-lg w-full">
                {thinking.emotional and thinking.emotional != "" and (
                    <div className={thinkingBubbleClass}>💭 {thinking.emotional}</div>
                )}
                {thinking.intent and thinking.intent != "" and (
                    <div className={thinkingBubbleClass}>💭 {thinking.intent}</div>
                )}
                {thinking.tasks and thinking.tasks != "" and (
                    <div className={thinkingBubbleClass}>💭 {thinking.tasks}</div>
                )}
                {thinking.pattern and thinking.pattern != "" and (
                    <div className={thinkingBubbleClass}>💭 {thinking.pattern}</div>
                )}
            </div>
        )}
        
        <div>
            <div className={labelClass}>
                {role}
            </div>
            <div className={bubbleClass}>{content}</div>
        </div>
    </div>;
}
