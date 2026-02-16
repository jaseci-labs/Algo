# GoalProgressRing Component
# Circular progress indicator for goals

import from "lucide-react" { Target }
import from react { useEffect, useRef, useState, Fragment }

import from ..utils.mergeCls { cn }

def GoalProgressRingComponent(progress: int = 0, size: int = 60, strokeWidth: int = 4, goalType: str = "", showLabel: bool = True) -> any {
    svgRef = useRef(None);
    [animatedProgress, setAnimatedProgress] = useState(0);

    # Animate progress on mount
    useEffect(
        lambda -> any {
            timer = setTimeout(
                lambda -> any { setAnimatedProgress(progress); },
                100
            );
            return lambda -> any { clearTimeout(timer); };
        },
        [progress]
    );

    # Calculate SVG circle properties
    radius = (size - strokeWidth) / 2;
    circumference = radius * 2 * 3.14159;
    strokeDashoffset = circumference - (animatedProgress / 100) * circumference;

    # Get color based on progress
    getColor = lambda -> str {
        if animatedProgress >= 100 {
            return "text-green-500";
        }
        if animatedProgress >= 75 {
            return "text-blue-500";
        }
        if animatedProgress >= 50 {
            return "text-yellow-500";
        }
        return "text-muted-foreground";
    };

    color = getColor();

    # Determine center icon
    showCheckmark = False;
    if animatedProgress >= 100 {
        showCheckmark = True;
    }

    # Center icon element (pre-compute to avoid ternary in JSX)
    centerIcon = <Target className="w-4 h-4" />;
    if showCheckmark {
        centerIcon = <span className="text-lg font-bold">✓</span>;
    }

    # Label element (pre-compute to avoid ternary in JSX)
    labelElement = <Fragment />;
    if showLabel {
        labelElement = <div className="mt-1 text-center">
            <p className="text-xs font-medium text-foreground">{goalType or "Goal"}</p>
            <p className={cn("text-xs font-semibold", color)}>{String(animatedProgress)}%</p>
        </div>;
    }

    return <div className="flex flex-col items-center">
        <div className="relative" style={{"width": String(size) + "px", "height": String(size) + "px"}}>
            <svg
                ref={svgRef}
                width={size}
                height={size}
                className={cn("transform -rotate-90", color)}
            >
                # Background circle
                <circle
                    cx={size / 2}
                    cy={size / 2}
                    r={radius}
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={strokeWidth}
                    className="opacity-20"
                />
                # Progress circle
                <circle
                    cx={size / 2}
                    cy={size / 2}
                    r={radius}
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={strokeWidth}
                    strokeDasharray={String(circumference)}
                    strokeDashoffset={String(strokeDashoffset)}
                    strokeLinecap="round"
                    className="transition-all duration-500 ease-out"
                />
            </svg>

            # Center icon/text
            <div className="absolute inset-0 flex items-center justify-center">
                {centerIcon}
            </div>
        </div>

        {labelElement}
    </div>;
}

glob:pub GoalProgressRing = GoalProgressRingComponent;
