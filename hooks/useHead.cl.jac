# useHead Hook
# Manage document head metadata (title, description, favicon, etc.)

# Default meta configuration
glob:pub DEFAULT_META = {
    "title": "Algo",
    "description": "Your Personal AI Assistant with Voice Interface",
    "favicon": "/static/assets/favicon.ico",
    "themeColor": "#ff7743",
    "ogImage": "/static/assets/og-image.png"
};

def:pub useHead(config: any) -> None {
    # Using new can with [dep] entry syntax
    can with [config] entry {
        # Title
        if config and config.title {
            document.title = config.title;
        }

        # Helper to set or create meta tag
        def setMeta(name: str, content: str, isProperty: bool) -> None {
            attr = "property" if isProperty else "name";
            selector = f'meta[{attr}="{name}"]';
            existing = document.querySelector(selector);

            if existing {
                existing.content = content;
            } else {
                meta = document.createElement('meta');
                meta.setAttribute(attr, name);
                meta.content = content;
                document.head.appendChild(meta);
            }
        }

        # Helper to set or create link tag
        def setLink(rel: str, href: str) -> None {
            selector = f'link[rel="{rel}"]';
            existing = document.querySelector(selector);

            if existing {
                existing.href = href;
            } else {
                link = document.createElement('link');
                link.rel = rel;
                link.href = href;
                document.head.appendChild(link);
            }
        }

        # Viewport (mobile support)
        setMeta("viewport", "width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no", False);

        # Description
        if config and config.description {
            setMeta("description", config.description, False);
        }

        # Theme color (for mobile browsers)
        if config and config.themeColor {
            setMeta("theme-color", config.themeColor, False);
        }

        # Favicon
        if config and config.favicon {
            setLink("icon", config.favicon);
        }

        # Open Graph tags (for social sharing)
        if config and config.title {
            setMeta("og:title", config.title, True);
        }
        if config and config.description {
            setMeta("og:description", config.description, True);
        }
        if config and config.ogImage {
            setMeta("og:image", config.ogImage, True);
        }

        # Twitter Card
        setMeta("twitter:card", "summary_large_image", False);
    }
}
