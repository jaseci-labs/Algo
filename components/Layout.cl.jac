# Layout Component
# Simple shared layout wrapper for all pages

import from ..hooks.useHead { useHead, DEFAULT_META }

def:pub Layout(
    children: any,
    meta: any = None
) -> any {
    activeMeta = meta or DEFAULT_META;
    
    # Merge with defaults
    finalMeta = {
        "title": activeMeta.title or DEFAULT_META.title,
        "description": activeMeta.description or DEFAULT_META.description,
        "favicon": activeMeta.favicon or DEFAULT_META.favicon,
        "themeColor": activeMeta.themeColor or DEFAULT_META.themeColor,
        "ogImage": activeMeta.ogImage or DEFAULT_META.ogImage
    };
    
    # Apply head configuration
    useHead(finalMeta);
    
    return <div className="min-h-screen bg-background text-text-primary font-sans">
        {children}
    </div>;
}