# AchievementBadge Component
# Displays an achievement with rarity styling

import from "lucide-react" { Trophy, Lock, Sparkles }
import from react { useState, Fragment }

import from ..utils.mergeCls { cn }

def AchievementBadgeComponent(achievement: dict = {}) -> any {
    [showTooltip, setShowTooltip] = useState(False);

    hasUnlocked = False;
    if achievement.unlocked_at and achievement.unlocked_at != "" {
        hasUnlocked = True;
    }

    # Get rarity styling
    getRarityStyle = lambda -> dict {
        rarity = achievement.rarity or "common";
        if rarity == "common" {
            return {
                "bg": "bg-slate-500/20",
                "border": "border-slate-500/50",
                "text": "text-slate-400",
                "icon": "text-slate-500"
            };
        }
        if rarity == "rare" {
            return {
                "bg": "bg-blue-500/20",
                "border": "border-blue-500/50",
                "text": "text-blue-400",
                "icon": "text-blue-500"
            };
        }
        if rarity == "epic" {
            return {
                "bg": "bg-purple-500/20",
                "border": "border-purple-500/50",
                "text": "text-purple-400",
                "icon": "text-purple-500"
            };
        }
        if rarity == "legendary" {
            return {
                "bg": "bg-gradient-to-br from-yellow-500/30 to-orange-500/30",
                "border": "border-yellow-500/50",
                "text": "text-yellow-400",
                "icon": "text-yellow-500"
            };
        }
        return {
            "bg": "bg-slate-500/20",
            "border": "border-slate-500/50",
            "text": "text-slate-400",
            "icon": "text-slate-500"
        };
    };

    rarityStyle = getRarityStyle();

    # Determine opacity and hover classes
    opacityClass = "opacity-40";
    hoverClass = "";
    if hasUnlocked {
        opacityClass = "opacity-100";
        hoverClass = "hover:scale-105";
    }

    # Determine subtitle text color
    subtitleColor = "text-muted-foreground";
    if hasUnlocked {
        subtitleColor = rarityStyle.text;
    }

    # Determine if show sparkles
    showSparkles = False;
    if rarityStyle.icon == "text-yellow-500" and hasUnlocked {
        showSparkles = True;
    }

    # ========== Pre-compute all conditional JSX elements ==========
    # Icon element (trophy if unlocked, lock if not)
    iconElement = <Lock className="w-8 h-8 mb-1 text-muted-foreground" />;
    if hasUnlocked {
        iconElement = <Trophy className={cn("w-8 h-8 mb-1", rarityStyle.icon)} />;
    }

    # Sparkles element (only show for legendary unlocked achievements)
    sparklesElement = <Fragment />;
    if showSparkles {
        sparklesElement = <Sparkles className="absolute -top-1 -right-1 w-4 h-4 text-yellow-500 animate-pulse" />;
    }

    # Unlocked date text (for tooltip)
    unlockedDateText = <Fragment />;
    if hasUnlocked {
        unlockedDateText = <p className="text-xs text-green-500 mt-1">
            Unlocked {achievement.unlocked_at or ""}
        </p>;
    }

    # Tooltip element
    tooltipElement = <Fragment />;
    if showTooltip {
        unlockedInfo = unlockedDateText;
        tooltipElement = <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 p-2 rounded-lg bg-background border border-border/50 shadow-lg z-10 w-48 block">
            <p className="text-sm font-medium text-foreground mb-1">
                {achievement.title or "Achievement"}
            </p>
            <p className="text-xs text-muted-foreground">
                {achievement.description or ""}
            </p>
            {unlockedInfo}
            # Arrow
            <div className="absolute top-full left-1/2 -translate-x-1/2 -mt-1">
                <div className="border-4 border-transparent border-t-background" />
            </div>
        </div>;
    }

    return <div
        className="relative"
        onMouseEnter={lambda -> any { setShowTooltip(True); } }
        onMouseLeave={lambda -> any { setShowTooltip(False); } }
    >
        <div className={cn(
            "p-3 rounded-xl border transition-all cursor-pointer",
            rarityStyle.bg,
            rarityStyle.border,
            opacityClass,
            hoverClass
        )}>
            <div className="flex flex-col items-center text-center">
                {iconElement}
                {sparklesElement}
                <p className={cn("text-xs font-medium", rarityStyle.text)}>
                    {achievement.title or "Achievement"}
                </p>
                <p className={cn("text-xs mt-1", subtitleColor)}>
                    {achievement.rarity or "common"}
                </p>
            </div>
        </div>

        # Tooltip
        {tooltipElement}
    </div>;
}

glob:pub AchievementBadge = AchievementBadgeComponent;
