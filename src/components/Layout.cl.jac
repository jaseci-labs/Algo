# Layout Component
# Simple shared layout wrapper for all pages

import from ..hooks.useHead { useHead, DEFAULT_META }

def:pub Layout(props: any) -> any {
    children = props.children;
    meta = props.meta or DEFAULT_META;
    
    # Merge with defaults
    finalMeta = {
        "title": meta.title or DEFAULT_META.title,
        "description": meta.description or DEFAULT_META.description,
        "favicon": meta.favicon or DEFAULT_META.favicon,
        "themeColor": meta.themeColor or DEFAULT_META.themeColor,
        "ogImage": meta.ogImage or DEFAULT_META.ogImage
    };
    
    # Apply head configuration
    useHead(finalMeta);
    
    return <div className="min-h-screen bg-background text-text-primary font-sans">
        {children}
    </div>;
}
