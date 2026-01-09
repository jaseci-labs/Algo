# useViewport Hook
# Detects viewport size and provides mobile/tablet/desktop categorization
# Uses window.matchMedia API for efficient, event-driven detection

import from react { useState, useEffect }

def:pub useViewport() -> any {
    # Calculate viewport state based on window dimensions
    def getViewportState() -> any {
        width = window.innerWidth;
        height = window.innerHeight;

        # Determine viewport category based on Tailwind breakpoints
        # Mobile: < 640px
        # Tablet: 640px - 1023px
        # Desktop: >= 1024px
        viewport = "desktop";
        if width < 640 {
            viewport = "mobile";
        } elif width < 1024 {
            viewport = "tablet";
        }

        return {
            "viewport": viewport,
            "isMobile": viewport == "mobile",
            "isTablet": viewport == "tablet",
            "isDesktop": viewport == "desktop",
            "width": width,
            "height": height
        };
    }

    # Initialize state with current viewport
    [viewportState, setViewportState] = useState(getViewportState());

    # Set up media query listeners for breakpoint changes
    useEffect(
        lambda -> any {
            # Create media queries for each breakpoint
            mobileQuery = window.matchMedia("(max-width: 639px)");
            tabletQuery = window.matchMedia("(min-width: 640px) and (max-width: 1023px)");
            desktopQuery = window.matchMedia("(min-width: 1024px)");

            # Handler for media query changes
            def handleChange(e: any) -> None {
                setViewportState(getViewportState());
            }

            # Add event listeners to all breakpoints
            mobileQuery.addEventListener("change", handleChange);
            tabletQuery.addEventListener("change", handleChange);
            desktopQuery.addEventListener("change", handleChange);

            # Cleanup function - remove listeners on unmount
            return lambda -> None {
                mobileQuery.removeEventListener("change", handleChange);
                tabletQuery.removeEventListener("change", handleChange);
                desktopQuery.removeEventListener("change", handleChange);
            };
        },
        []
    );

    return viewportState;
}
