# AnalyticsPanel Component
# Enhanced analytics dashboard with patterns, goals, achievements, and proactive insights

import from "lucide-react" {
    BarChart3,
    RefreshCw,
    Download,
    X,
    Flame,
    Target,
    Trophy,
    Clock,
    TrendingUp,
    Sparkles,
    CheckCircle,
    Zap,
    AlertCircle
}
import from react { useState, useEffect, Fragment }

import from ..hooks.useAnalytics { useAnalytics }
import from ..utils.mergeCls { cn }
import from .InsightCard { InsightCard }
import from .AchievementBadge { AchievementBadge }

def AnalyticsPanelComponent(onClose: any = None) -> any {
    # Use the analytics hook with React state
    analytics = useAnalytics();

    has activeTab: str = "overview";
    [currentTab, setCurrentTab] = useState("overview");
    [showGoalDialog, setShowGoalDialog] = useState(False);

    # Fetch data when component mounts
    useEffect(
        lambda -> any {
            analytics.fetchAllAnalytics();
        },
        []
    );

    # ========== Pre-compute all values that depend on conditions ==========
    # Category button classes
    allClass = "bg-primary text-primary-foreground";
    if analytics.selectedCategory != "all" {
        allClass = "bg-muted/50 text-muted-foreground hover:bg-muted";
    }

    productivityClass = "bg-primary text-primary-foreground";
    if analytics.selectedCategory != "productivity" {
        productivityClass = "bg-muted/50 text-muted-foreground hover:bg-muted";
    }

    behavioralClass = "bg-primary text-primary-foreground";
    if analytics.selectedCategory != "behavioral" {
        behavioralClass = "bg-muted/50 text-muted-foreground hover:bg-muted";
    }

    comparativeClass = "bg-primary text-primary-foreground";
    if analytics.selectedCategory != "comparative" {
        comparativeClass = "bg-muted/50 text-muted-foreground hover:bg-muted";
    }

    # Loading state
    if analytics.isLoading and not analytics.activityReport {
        return <div className="glass-panel rounded-xl h-full flex flex-col p-6">
            <div className="flex items-center justify-center h-full">
                <div className="text-center">
                    <RefreshCw className="w-8 h-8 animate-spin text-primary mx-auto mb-2" />
                    <p className="text-muted-foreground">Loading analytics...</p>
                </div>
            </div>
        </div>;
    }

    # Error state
    if analytics.error and not analytics.activityReport {
        return <div className="glass-panel rounded-xl h-full flex flex-col p-6">
            <div className="flex items-center justify-center h-full">
                <div className="text-center">
                    <AlertCircle className="w-8 h-8 text-destructive mx-auto mb-2" />
                    <p className="text-destructive mb-2">{analytics.error}</p>
                    <button
                        onClick={lambda -> any { analytics.refreshAnalytics(); } }
                        className="text-primary hover:underline"
                    >
                        Try again
                    </button>
                </div>
            </div>
        </div>;
    }

    # Tab configurations
    tabs = [
        {"id": "overview", "label": "Overview", "icon": BarChart3},
        {"id": "patterns", "label": "Patterns", "icon": Sparkles},
        {"id": "goals", "label": "Goals", "icon": Target},
        {"id": "achievements", "label": "Achievements", "icon": Trophy},
        {"id": "insights", "label": "Insights", "icon": Zap}
    ];

    # Render tab buttons
    tabButtons = tabs.map(lambda tab: any, idx: int -> any {
        Icon = tab.icon;
        isActive = currentTab == tab.id;

        # Determine button class using if/else
        buttonClass = "flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-colors";
        if isActive {
            buttonClass = buttonClass + " bg-primary text-primary-foreground";
        } else {
            buttonClass = buttonClass + " text-muted-foreground hover:bg-muted/50 hover:text-foreground";
        }

        # Determine icon class
        iconClass = "w-4 h-4";
        if isActive {
            iconClass = iconClass + " text-primary-foreground";
        }

        return <button
            key={idx}
            onClick={lambda -> any { setCurrentTab(tab.id); } }
            className={buttonClass}
        >
            <Icon className={iconClass} />
            <span className="hidden sm:inline">{tab.label}</span>
        </button>;
    });

    # ========== Pre-compute conditional JSX blocks ==========
    # Header close button
    headerCloseButton = <Fragment />;
    if onClose {
        headerCloseButton = <button
            onClick={onClose}
            className="p-2 rounded-lg bg-destructive/10 hover:bg-destructive/20 text-destructive transition-colors"
            title="Close"
        >
            <X className="w-4 h-4" />
        </button>;
    }

    # ========== Header ==========
    header = <div className="flex items-center justify-between p-4 border-b border-border/50">
        <h2 className="text-lg font-semibold text-foreground flex items-center gap-2">
            <BarChart3 className="w-5 h-5 text-primary" />
            Analytics
        </h2>
        <div className="flex items-center gap-2">
            <button
                onClick={lambda -> any { analytics.refreshAnalytics(); } }
                disabled={analytics.isLoading}
                className={cn("p-2 rounded-lg bg-muted/50 hover:bg-muted text-muted-foreground hover:text-foreground transition-colors", analytics.isLoading and "opacity-50 cursor-not-allowed")}
                title="Refresh"
            >
                <RefreshCw className={cn("w-4 h-4", analytics.isLoading and "animate-spin")} />
            </button>
            <button
                onClick={lambda -> any { analytics.exportData("json"); } }
                className="p-2 rounded-lg bg-muted/50 hover:bg-muted text-muted-foreground hover:text-foreground transition-colors"
                title="Export data"
            >
                <Download className="w-4 h-4" />
            </button>
            {headerCloseButton}
        </div>
    </div>;

    # ========== Tab Navigation ==========
    tabNav = <div className="flex items-center gap-1 p-2 overflow-x-auto">
        {tabButtons}
    </div>;

    # ========== Build Overview Tab Content ==========
    overviewBlocks = [];

    # Activity Report block
    if analytics.activityReport {
        overviewBlocks.push(<div className="glass-panel rounded-xl p-4">
            <h3 className="text-sm font-medium text-foreground mb-3 flex items-center gap-2">
                <BarChart3 className="w-4 h-4 text-primary" />
                Activity Report
            </h3>
            <div className="grid grid-cols-2 gap-3">
                <div className="bg-muted/30 rounded-lg p-3">
                    <p className="text-xs text-muted-foreground">Total Tasks</p>
                    <p className="text-2xl font-semibold text-foreground">
                        {String(analytics.activityReport.total_tasks or 0)}
                    </p>
                </div>
                <div className="bg-muted/30 rounded-lg p-3">
                    <p className="text-xs text-muted-foreground">Total Sessions</p>
                    <p className="text-2xl font-semibold text-foreground">
                        {String(analytics.activityReport.total_sessions or 0)}
                    </p>
                </div>
                <div className="bg-muted/30 rounded-lg p-3">
                    <p className="text-xs text-muted-foreground">Current Tasks</p>
                    <p className="text-2xl font-semibold text-foreground">
                        {String(analytics.activityReport.current_task_count or 0)}
                    </p>
                </div>
                <div className="bg-muted/30 rounded-lg p-3">
                    <p className="text-xs text-muted-foreground">Total Events</p>
                    <p className="text-2xl font-semibold text-foreground">
                        {String(analytics.activityReport.total_events or 0)}
                    </p>
                </div>
            </div>
        </div>);
    }

    # Productivity Metrics block
    if analytics.productivityMetrics {
        overviewBlocks.push(<div className="glass-panel rounded-xl p-4">
            <h3 className="text-sm font-medium text-foreground mb-3 flex items-center gap-2">
                <TrendingUp className="w-4 h-4 text-primary" />
                Productivity
            </h3>
            <div className="grid grid-cols-2 gap-3">
                <div className="bg-muted/30 rounded-lg p-3">
                    <p className="text-xs text-muted-foreground">Efficiency</p>
                    <p className="text-2xl font-semibold text-foreground">
                        {String(Math.round(analytics.productivityMetrics.efficiency_score or 0, 1))}%
                    </p>
                </div>
                <div className="bg-muted/30 rounded-lg p-3">
                    <p className="text-xs text-muted-foreground">Consistency</p>
                    <p className="text-2xl font-semibold text-foreground">
                        {String(Math.round(analytics.productivityMetrics.consistency_score or 0, 1))}%
                    </p>
                </div>
                <div className="bg-gradient-to-br from-orange-500/20 to-red-500/20 rounded-lg p-3 border border-orange-500/30">
                    <p className="text-xs text-muted-foreground flex items-center gap-1">
                        <Flame className="w-3 h-3 text-orange-500" />
                        Current Streak
                    </p>
                    <p className="text-2xl font-semibold text-orange-500">
                        {String(analytics.productivityMetrics.current_streak or 0)} days
                    </p>
                </div>
                <div className="bg-muted/30 rounded-lg p-3">
                    <p className="text-xs text-muted-foreground">Days Tracked</p>
                    <p className="text-2xl font-semibold text-foreground">
                        {String(analytics.productivityMetrics.days_tracked or 0)}
                    </p>
                </div>
            </div>
        </div>);
    }

    # Proactive Insights block
    proactiveInsightsItems = [];
    if analytics.proactiveInsights and analytics.proactiveInsights.length > 0 {
        for insight in analytics.proactiveInsights {
            urgencyText = "";
            if insight.urgency {
                urgencyText = <p className="text-xs text-muted-foreground mt-1">
                    Urgency: {insight.urgency or "low"}
                </p>;
            }

            proactiveInsightsItems.push(<div key={insight.id or "default"} className="p-3 bg-background/50 rounded-lg border border-border/50">
                <p className="text-sm text-foreground">{insight.message or insight.title or ""}</p>
                {urgencyText}
            </div>);
        }
    }

    if analytics.proactiveInsights and analytics.proactiveInsights.length > 0 {
        overviewBlocks.push(<div className="glass-panel rounded-xl p-4 bg-gradient-to-br from-primary/5 to-primary/10 border-primary/20">
            <h3 className="text-sm font-medium text-foreground mb-3 flex items-center gap-2">
                <Sparkles className="w-4 h-4 text-primary" />
                Proactive Insights
            </h3>
            <div className="space-y-2">
                {proactiveInsightsItems}
            </div>
        </div>);
    }

    # Temporal Insights block
    if analytics.temporalInsights {
        overviewBlocks.push(<div className="glass-panel rounded-xl p-4">
            <h3 className="text-sm font-medium text-foreground mb-3 flex items-center gap-2">
                <Clock className="w-4 h-4 text-primary" />
                Peak Activity Times
            </h3>
            <div className="grid grid-cols-2 gap-3">
                <div className="bg-muted/30 rounded-lg p-3">
                    <p className="text-xs text-muted-foreground">Peak Hour</p>
                    <p className="text-lg font-semibold text-foreground">
                        {analytics.temporalInsights.peak_hour or "N/A"}
                    </p>
                </div>
                <div className="bg-muted/30 rounded-lg p-3">
                    <p className="text-xs text-muted-foreground">Peak Day</p>
                    <p className="text-lg font-semibold text-foreground">
                        {analytics.temporalInsights.peak_day or "N/A"}
                    </p>
                </div>
            </div>
        </div>);
    }

    overviewContent = <div className="space-y-4">
        {overviewBlocks}
    </div>;

    # ========== Build Patterns Tab Content ==========
    patternBlocks = [];

    # Discovered Patterns block
    if analytics.discoveredPatterns and analytics.discoveredPatterns.length > 0 {
        patternItems = [];
        for pattern in analytics.discoveredPatterns {
            confidence = pattern.confidence or 0;
            confidencePercent = Math.round(confidence * 100, 0);

            # Determine confidence color
            confidenceClass = "bg-yellow-500/20 text-yellow-500";
            if confidence > 0.8 {
                confidenceClass = "bg-green-500/20 text-green-500";
            }

            taskList = "";
            hasTaskList = False;
            if pattern.task_sequence {
                taskList = pattern.task_sequence.join(" -> ") or "";
                hasTaskList = True;
            }

            taskListElement = <Fragment />;
            if hasTaskList {
                taskListElement = <p className="text-xs text-muted-foreground mt-2">
                    Tasks: {taskList}
                </p>;
            }

            patternItems.push(<div key={pattern.pattern_name or pattern.name or "pattern"} className="p-3 bg-muted/30 rounded-lg mb-2">
                <div className="flex items-center justify-between mb-2">
                    <h4 className="text-sm font-medium text-foreground">{pattern.pattern_name or pattern.name or "Pattern"}</h4>
                    <span className={cn("text-xs px-2 py-1 rounded-full", confidenceClass)}>
                        {String(confidencePercent)}% confidence
                    </span>
                </div>
                <p className="text-xs text-muted-foreground">{pattern.description or ""}</p>
                {taskListElement}
            </div>);
        }

        patternBlocks.push(<div className="glass-panel rounded-xl p-4">
            <h3 className="text-sm font-medium text-foreground mb-3 flex items-center gap-2">
                <Sparkles className="w-4 h-4 text-primary" />
                Discovered Routines
            </h3>
            {patternItems}
        </div>);
    } else {
        patternBlocks.push(<div className="glass-panel rounded-xl p-4">
            <h3 className="text-sm font-medium text-foreground mb-3 flex items-center gap-2">
                <Sparkles className="w-4 h-4 text-primary" />
                Discovered Routines
            </h3>
            <p className="text-sm text-muted-foreground">No patterns discovered yet. Keep tracking your routines!</p>
        </div>);
    }

    # Connection Patterns block
    if analytics.behavioralPatterns and analytics.behavioralPatterns.connection_patterns {
        patternBlocks.push(<div className="glass-panel rounded-xl p-4">
            <h3 className="text-sm font-medium text-foreground mb-3">Connection Patterns</h3>
            <div className="grid grid-cols-2 gap-3">
                <div className="bg-muted/30 rounded-lg p-3">
                    <p className="text-xs text-muted-foreground">Sequential</p>
                    <p className="text-xl font-semibold text-foreground">
                        {String(analytics.behavioralPatterns.connection_patterns.sequential or 0)}
                    </p>
                </div>
                <div className="bg-muted/30 rounded-lg p-3">
                    <p className="text-xs text-muted-foreground">Parallel</p>
                    <p className="text-xl font-semibold text-foreground">
                        {String(analytics.behavioralPatterns.connection_patterns.parallel or 0)}
                    </p>
                </div>
                <div className="bg-muted/30 rounded-lg p-3">
                    <p className="text-xs text-muted-foreground">Conditional</p>
                    <p className="text-xl font-semibold text-foreground">
                        {String(analytics.behavioralPatterns.connection_patterns.conditional or 0)}
                    </p>
                </div>
                <div className="bg-muted/30 rounded-lg p-3">
                    <p className="text-xs text-muted-foreground">Convergent</p>
                    <p className="text-xl font-semibold text-foreground">
                        {String(analytics.behavioralPatterns.connection_patterns.convergent or 0)}
                    </p>
                </div>
            </div>
        </div>);
    }

    patternsContent = <div className="space-y-4">
        {patternBlocks}
    </div>;

    # ========== Build Goals Tab Content ==========
    goalItems = [];
    if analytics.userGoals and analytics.userGoals.length > 0 {
        for goal in analytics.userGoals {
            targetVal = goal.target_value or 1;
            currentVal = goal.current_value or 0;
            progress = currentVal / targetVal * 100;
            isAchieved = goal.achieved or False;
            clampedProgress = Math.min(progress, 100);

            checkIcon = <Fragment />;
            if isAchieved {
                checkIcon = <CheckCircle className="w-4 h-4 text-green-500" />;
            }

            goalItems.push(<div key={goal.goal_type or "goal"} className="p-3 bg-muted/30 rounded-lg mb-2">
                <div className="flex items-center justify-between mb-2">
                    <h4 className="text-sm font-medium text-foreground">{goal.goal_type or "Goal"}</h4>
                    {checkIcon}
                </div>
                <div className="w-full bg-muted rounded-full h-2 mb-1">
                    <div
                        className="bg-primary rounded-full h-2 transition-all"
                        style={{"width": String(clampedProgress) + "%"}}
                    />
                </div>
                <p className="text-xs text-muted-foreground">
                    {String(currentVal)} / {String(targetVal)}
                </p>
            </div>);
        }
    } else {
        goalItems.push(<p className="text-sm text-muted-foreground">No goals yet. Create one to track your progress!</p>);
    }

    # Goal dialog content
    goalDialogContent = <Fragment />;
    if showGoalDialog {
        goalDialogContent = <div className="glass-panel rounded-xl p-4 border border-dashed border-border">
            <h3 className="text-sm font-medium text-foreground mb-2">Quick Goal Templates</h3>
            <div className="grid grid-cols-2 gap-2">
                <button
                    onClick={lambda -> any { analytics.createNewGoal("daily_tasks", 5); } }
                    className="p-2 bg-muted/30 rounded-lg text-xs text-left hover:bg-muted/50 transition-colors"
                >
                    <p className="font-medium">5 Tasks/Day</p>
                    <p className="text-muted-foreground">Daily task goal</p>
                </button>
                <button
                    onClick={lambda -> any { analytics.createNewGoal("weekly_streak", 7); } }
                    className="p-2 bg-muted/30 rounded-lg text-xs text-left hover:bg-muted/50 transition-colors"
                >
                    <p className="font-medium">7 Day Streak</p>
                    <p className="text-muted-foreground">Weekly consistency</p>
                </button>
                <button
                    onClick={lambda -> any { analytics.createNewGoal("voice_usage", 10); } }
                    className="p-2 bg-muted/30 rounded-lg text-xs text-left hover:bg-muted/50 transition-colors"
                >
                    <p className="font-medium">10 Voice Commands</p>
                    <p className="text-muted-foreground">Voice interaction goal</p>
                </button>
                <button
                    onClick={lambda -> any { analytics.createNewGoal("total_tasks", 100); } }
                    className="p-2 bg-muted/30 rounded-lg text-xs text-left hover:bg-muted/50 transition-colors"
                >
                    <p className="font-medium">100 Total Tasks</p>
                    <p className="text-muted-foreground">Long-term milestone</p>
                </button>
            </div>
        </div>;
    }

    goalsContent = <div className="space-y-4">
        <div className="glass-panel rounded-xl p-4">
            <div className="flex items-center justify-between mb-3">
                <h3 className="text-sm font-medium text-foreground flex items-center gap-2">
                    <Target className="w-4 h-4 text-primary" />
                    Your Goals
                </h3>
                <button
                    onClick={lambda -> any { setShowGoalDialog(True); } }
                    className="text-xs px-3 py-1 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors"
                >
                    + New Goal
                </button>
            </div>
            {goalItems}
        </div>
        {goalDialogContent}
    </div>;

    # ========== Build Achievements Tab Content ==========
    # Pre-calculate achievement counts
    unlockedCount = 0;
    lockedCount = 0;
    for achievement in analytics.userAchievements {
        if achievement.unlocked_at and achievement.unlocked_at != "" {
            unlockedCount = unlockedCount + 1;
        } else {
            lockedCount = lockedCount + 1;
        }
    }
    totalCount = analytics.userAchievements.length;

    # Achievement grid items
    achievementGridItems = [];
    if analytics.userAchievements and analytics.userAchievements.length > 0 {
        for achievement in analytics.userAchievements {
            achievementGridItems.push(<AchievementBadge key={achievement.achievement_id or "achievement"} achievement={achievement} />);
        }
    } else {
        achievementGridItems.push(<p className="text-sm text-muted-foreground col-span-full">No achievements yet. Complete tasks and maintain streaks to unlock them!</p>);
    }

    achievementsContent = <div className="space-y-4">
        # Achievement Stats
        <div className="grid grid-cols-3 gap-3">
            <div className="glass-panel rounded-xl p-3 text-center">
                <p className="text-2xl font-semibold text-foreground">
                    {String(unlockedCount)}
                </p>
                <p className="text-xs text-muted-foreground">Unlocked</p>
            </div>
            <div className="glass-panel rounded-xl p-3 text-center">
                <p className="text-2xl font-semibold text-foreground">
                    {String(lockedCount)}
                </p>
                <p className="text-xs text-muted-foreground">Locked</p>
            </div>
            <div className="glass-panel rounded-xl p-3 text-center">
                <p className="text-2xl font-semibold text-primary">
                    {String(totalCount)}
                </p>
                <p className="text-xs text-muted-foreground">Total</p>
            </div>
        </div>

        # Achievements Grid
        <div className="glass-panel rounded-xl p-4">
            <h3 className="text-sm font-medium text-foreground mb-3 flex items-center gap-2">
                <Trophy className="w-4 h-4 text-primary" />
                Achievement Collection
            </h3>
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                {achievementGridItems}
            </div>
        </div>

        # Check for new achievements button
        <button
            onClick={lambda -> any { analytics.checkForAchievements(); } }
            className="w-full p-3 bg-primary/10 rounded-xl text-primary font-medium hover:bg-primary/20 transition-colors flex items-center justify-center gap-2"
        >
            <Trophy className="w-4 h-4" />
            Check for New Achievements
        </button>
    </div>;

    # ========== Build Insights Tab Content ==========
    insightBlocks = [];

    # Personalized Insights block
    insightListItems = [];
    if analytics.insights and analytics.insights.length > 0 {
        for insight in analytics.insights {
            insightListItems.push(<InsightCard
                key={insight.id or "insight"}
                insight={insight}
                onView={lambda -> any { analytics.markInsightAsViewed(insight.id or ""); } }
                onAct={lambda -> any { analytics.markInsightAsActedUpon(insight.id or ""); } }
                onDismiss={lambda -> any { analytics.dismissInsightById(insight.id or ""); } }
            />);
        }
    } else {
        insightListItems.push(<p className="text-sm text-muted-foreground">No insights available yet. Keep using Algo to get personalized recommendations!</p>);
    }

    if analytics.insights {
        insightBlocks.push(<div className="glass-panel rounded-xl p-4">
            <h3 className="text-sm font-medium text-foreground mb-3 flex items-center gap-2">
                <Zap className="w-4 h-4 text-primary" />
                Personalized Insights
            </h3>
            <div className="space-y-3">
                {insightListItems}
            </div>
        </div>);
    }

    # Category Filter buttons
    categoryFilter = <div className="flex items-center gap-2 flex-wrap">
        <button
            onClick={lambda -> any { analytics.fetchInsights("all"); } }
            className={cn("text-xs px-3 py-1 rounded-full transition-colors", allClass)}
        >
            All
        </button>
        <button
            onClick={lambda -> any { analytics.fetchInsights("productivity"); } }
            className={cn("text-xs px-3 py-1 rounded-full transition-colors", productivityClass)}
        >
            Productivity
        </button>
        <button
            onClick={lambda -> any { analytics.fetchInsights("behavioral"); } }
            className={cn("text-xs px-3 py-1 rounded-full transition-colors", behavioralClass)}
        >
            Behavioral
        </button>
        <button
            onClick={lambda -> any { analytics.fetchInsights("comparative"); } }
            className={cn("text-xs px-3 py-1 rounded-full transition-colors", comparativeClass)}
        >
            Comparative
        </button>
    </div>;

    # Comparative Insights block
    comparativeItems = [];
    if analytics.comparativeInsights and analytics.comparativeInsights.length > 0 {
        for comp in analytics.comparativeInsights {
            changePct = comp.change_percentage or 0;
            isPositive = changePct > 0;
            changeStr = "";
            if isPositive {
                changeStr = "+" + String(changePct);
            } else {
                changeStr = String(changePct);
            }

            changeClass = "bg-green-500/20 text-green-500";
            if not isPositive {
                changeClass = "bg-red-500/20 text-red-500";
            }

            comparativeItems.push(<div key={comp.comparison_type or "comp"} className="p-3 bg-muted/30 rounded-lg mb-2">
                <div className="flex items-center justify-between">
                    <p className="text-sm text-foreground">{comp.narrative or "Comparison data"}</p>
                    <span className={cn("text-xs px-2 py-1 rounded-full", changeClass)}>
                        {changeStr}%
                    </span>
                </div>
            </div>);
        }
    } else {
        comparativeItems.push(<p className="text-sm text-muted-foreground">Not enough data for comparisons yet.</p>);
    }

    if analytics.comparativeInsights {
        insightBlocks.push(<div className="glass-panel rounded-xl p-4">
            <h3 className="text-sm font-medium text-foreground mb-3 flex items-center gap-2">
                <TrendingUp className="w-4 h-4 text-primary" />
                Week over Week
            </h3>
            {comparativeItems}
        </div>);
    }

    insightsContent = <div className="space-y-4">
        {insightBlocks}
        {categoryFilter}
    </div>;

    # ========== Main Render ==========
    # Determine which content to show based on current tab
    contentToShow = <Fragment />;
    if currentTab == "overview" {
        contentToShow = <Fragment>{overviewContent}</Fragment>;
    } elif currentTab == "patterns" {
        contentToShow = <Fragment>{patternsContent}</Fragment>;
    } elif currentTab == "goals" {
        contentToShow = <Fragment>{goalsContent}</Fragment>;
    } elif currentTab == "achievements" {
        contentToShow = <Fragment>{achievementsContent}</Fragment>;
    } elif currentTab == "insights" {
        contentToShow = <Fragment>{insightsContent}</Fragment>;
    }

    return <div className="glass-panel rounded-xl h-full flex flex-col">
        {header}
        {tabNav}

        <div className="flex-1 overflow-auto p-4">
            {contentToShow}
        </div>
    </div>;
}

glob:pub AnalyticsPanel = AnalyticsPanelComponent;
