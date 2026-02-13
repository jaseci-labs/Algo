# InsightCard Component
# Displays a single insight with actions to view, act upon, or dismiss

import from "lucide-react" { Lightbulb, CheckCircle, X, ThumbsUp, Eye }
import from react { useState, Fragment }

import from ..utils.mergeCls { cn }

def InsightCardComponent(insight: dict = {}, onView: any = None, onAct: any = None, onDismiss: any = None) -> any {
    [isExpanded, setIsExpanded] = useState(False);

    # Determine category color
    getCategoryColor = lambda -> str {
        category = insight.category or "general";
        if category == "productivity" {
            return "bg-blue-500/20 text-blue-500 border-blue-500/30";
        }
        if category == "behavioral" {
            return "bg-purple-500/20 text-purple-500 border-purple-500/30";
        }
        if category == "predictive" {
            return "bg-green-500/20 text-green-500 border-green-500/30";
        }
        if category == "celebratory" {
            return "bg-yellow-500/20 text-yellow-500 border-yellow-500/30";
        }
        if category == "proactive" {
            return "bg-orange-500/20 text-orange-500 border-orange-500/30";
        }
        return "bg-muted/50 text-muted-foreground border-border/50";
    };

    categoryColor = getCategoryColor();

    # Determine opacity class
    opacityClass = "opacity-100";
    if insight.viewed {
        opacityClass = "opacity-60";
    }

    # Determine ring class
    ringClass = "";
    if insight.acted_upon {
        ringClass = "ring-2 ring-green-500/50";
    }

    # Determine icon color
    iconColor = "text-primary";
    if insight.acted_upon {
        iconColor = "text-green-500";
    }

    # Determine button text
    btnText = "Act on this";
    if insight.acted_upon {
        btnText = "Acted";
    }

    # Determine button class
    btnClass = "bg-primary/20 text-primary hover:bg-primary/30";
    if insight.acted_upon {
        btnClass = "bg-green-500/20 text-green-500 cursor-default";
    }

    # Determine more/less text
    moreLessText = "More";
    if isExpanded {
        moreLessText = "Less";
    }

    # Check if show view button
    showViewBtn = True;
    if insight.viewed {
        showViewBtn = False;
    }

    # Check if actionable
    isActionable = insight.actionable or False;

    # Check if show actionable button
    showActionBtn = False;
    if isActionable {
        showActionBtn = True;
    }

    # ========== Pre-compute all conditional JSX elements ==========
    # Acted on badge
    actedOnBadge = <Fragment />;
    if insight.acted_upon {
        actedOnBadge = <span className="text-xs px-2 py-0.5 rounded-full bg-green-500/20 text-green-500">
            Acted on
        </span>;
    }

    # Actionable recommendation
    actionableRec = <Fragment />;
    if isExpanded and insight.actionable_recommendation {
        actionableRec = <p className="text-xs text-muted-foreground mb-3">
            {insight.actionable_recommendation or ""}
        </p>;
    }

    # View button
    viewButton = <Fragment />;
    if showViewBtn {
        viewButton = <button
            onClick={lambda -> any {
                if onView { onView(); }
                newExpanded = not isExpanded;
                setIsExpanded(newExpanded);
            }}
            className="text-xs px-2 py-1 rounded bg-muted/50 hover:bg-muted text-muted-foreground hover:text-foreground transition-colors flex items-center gap-1"
        >
            <Eye className="w-3 h-3" />
            {moreLessText}
        </button>;
    }

    # Action button
    actionButton = <Fragment />;
    if showActionBtn {
        actionButton = <button
            onClick={lambda -> any {
                if onAct { onAct(); }
            }}
            disabled={insight.acted_upon}
            className={cn("text-xs px-2 py-1 rounded transition-colors flex items-center gap-1", btnClass)}
        >
            <ThumbsUp className="w-3 h-3" />
            {btnText}
        </button>;
    }

    # Category tag
    categoryTag = <Fragment />;
    if insight.category {
        categoryTag = <div className="mt-2 pt-2 border-t border-border/50">
            <span className="text-xs text-muted-foreground">
                Category: {insight.category or "General"}
            </span>
        </div>;
    }

    return <div className={cn(
        "p-3 rounded-lg border transition-all",
        categoryColor,
        opacityClass,
        ringClass
    )}>
        <div className="flex items-start justify-between mb-2">
            <div className="flex items-center gap-2 flex-1">
                <Lightbulb className={cn("w-4 h-4", iconColor)} />
                <h4 className="text-sm font-medium text-foreground flex-1">
                    {insight.title or "Insight"}
                </h4>
            </div>
            {actedOnBadge}
        </div>

        <p className="text-xs text-muted-foreground mb-2">
            {insight.description or insight.message or ""}
        </p>

        {actionableRec}

        # Action buttons
        <div className="flex items-center gap-2">
            {viewButton}
            {actionButton}
            <button
                onClick={lambda -> any {
                    if onDismiss { onDismiss(); }
                }}
                className="text-xs px-2 py-1 rounded bg-destructive/10 hover:bg-destructive/20 text-destructive transition-colors flex items-center gap-1"
            >
                <X className="w-3 h-3" />
                Dismiss
            </button>
        </div>

        # Category tag
        {categoryTag}
    </div>;
}

glob:pub InsightCard = InsightCardComponent;
