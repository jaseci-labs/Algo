# SuggestionChips Component
# Displays clickable suggestion chips for quick responses

import from ..utils.mergeCls { cn }

def:pub SuggestionChips(
    suggestions: list,
    onSelectSuggestion: any
) -> any {
    
    # Don't render if no suggestions
    if not suggestions or suggestions.length == 0 {
        return None;
    }
    
    return <div className="px-4 pb-2 flex gap-2 items-center flex-wrap">
        <span className="text-xs text-text-secondary font-medium">
            {"Quick replies:"}
        </span>
        {suggestions.map(lambda suggestion: any, idx: int -> any {
            return <button
                key={idx}
                onClick={lambda -> None { onSelectSuggestion(suggestion); }}
                className="px-3 py-1.5 bg-surface-elevated text-text-primary text-sm rounded-full border border-border cursor-pointer transition-all hover:bg-primary hover:text-primary-foreground hover:border-primary hover:-translate-y-0.5 active:translate-y-0 font-medium"
            >
                {suggestion}
            </button>;
        })}
    </div>;
}
