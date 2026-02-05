# AnalyticsPanel Component
# Minimal analytics dashboard that displays user behavioral insights

import from "lucide-react" { BarChart3, RefreshCw, Download, X }
import from react { useState, useEffect, Fragment }

import from ..hooks.useAnalytics { useAnalytics }
import from ..utils.mergeCls { cn }

def AnalyticsPanelComponent(onClose: any = None) -> any {
    # Use the analytics hook with React state
    analytics = useAnalytics();

    has activeTab: str = "overview";
    [currentTab, setCurrentTab] = useState("overview");

    # Fetch data when component mounts
    useEffect(
        lambda -> any {
            console.log("[AnalyticsPanel] Component mounted, fetching analytics...");
            analytics.fetchAllAnalytics();
        },
        []
    );

    # Pre-compute insight items (map must be outside JSX to avoid parsing issues)
    insightItems = [];
    if analytics.insights {
        insightItems = analytics.insights.map(lambda insight: any, idx: int -> any {
            return <div key={idx} className="p-3 bg-muted/30 rounded-lg">
                <h4 className="text-sm font-medium text-foreground">{insight.title or "Insight"}</h4>
                <p className="text-xs text-muted-foreground">{insight.description or ""}</p>
            </div>;
        });
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
    if analytics.error {
        return <div className="glass-panel rounded-xl h-full flex flex-col p-6">
            <div className="flex items-center justify-center h-full">
                <div className="text-center">
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

    # Overview tab
    if currentTab == "overview" {
        return <div className="glass-panel rounded-xl h-full flex flex-col">
            <div className="flex items-center justify-between p-4 border-b border-border/50">
                <h2 className="text-lg font-semibold text-foreground flex items-center gap-2">
                    <BarChart3 className="w-5 h-5 text-primary" />
                    Analytics
                </h2>
                <div className="flex items-center gap-2">
                    <button
                        onClick={lambda -> any { analytics.refreshAnalytics(); } }
                        disabled={analytics.isLoading}
                        className={cn("p-2 rounded-lg bg-muted/50 hover:bg-muted text-muted-foreground hover:text-foreground transition-colors", analytics.isLoading and "opacity-50 cursor-not-allowed")}
                    >
                        <RefreshCw className={cn("w-4 h-4", analytics.isLoading and "animate-spin")} />
                    </button>
                    <button
                        onClick={lambda -> any { analytics.exportData("json"); } }
                        className="p-2 rounded-lg bg-muted/50 hover:bg-muted text-muted-foreground hover:text-foreground transition-colors"
                    >
                        <Download className="w-4 h-4" />
                    </button>
                    {
                        (<button
                            onClick={onClose}
                            className="p-2 rounded-lg bg-destructive/10 hover:bg-destructive/20 text-destructive transition-colors"
                        >
                            <X className="w-4 h-4" />
                        </button>) if onClose else (<Fragment />)
                    }
                </div>
            </div>

            <div className="flex-1 overflow-auto p-4">
                <div className="space-y-4">
                    {
                        (<div className="glass-panel rounded-xl p-4">
                            <h3 className="text-sm font-medium text-foreground mb-3">Activity Report</h3>
                            <div className="grid grid-cols-2 gap-3">
                                <div>
                                    <p className="text-xs text-muted-foreground">Total Tasks</p>
                                    <p className="text-2xl font-semibold text-foreground">
                                        {String(analytics.activityReport.total_tasks or 0)}
                                    </p>
                                </div>
                                <div>
                                    <p className="text-xs text-muted-foreground">Total Sessions</p>
                                    <p className="text-2xl font-semibold text-foreground">
                                        {String(analytics.activityReport.total_sessions or 0)}
                                    </p>
                                </div>
                                <div>
                                    <p className="text-xs text-muted-foreground">Current Tasks</p>
                                    <p className="text-2xl font-semibold text-foreground">
                                        {String(analytics.activityReport.current_task_count or 0)}
                                    </p>
                                </div>
                                <div>
                                    <p className="text-xs text-muted-foreground">Total Events</p>
                                    <p className="text-2xl font-semibold text-foreground">
                                        {String(analytics.activityReport.total_events or 0)}
                                    </p>
                                </div>
                            </div>
                        </div>) if analytics.activityReport else (<Fragment />)
                    }
                    {
                        (<div className="glass-panel rounded-xl p-4">
                            <h3 className="text-sm font-medium text-foreground mb-3">Productivity</h3>
                            <div className="grid grid-cols-2 gap-3">
                                <div>
                                    <p className="text-xs text-muted-foreground">Efficiency</p>
                                    <p className="text-2xl font-semibold text-foreground">
                                        {String(Math.round(analytics.productivityMetrics.efficiency_score or 0, 1))}%
                                    </p>
                                </div>
                                <div>
                                    <p className="text-xs text-muted-foreground">Consistency</p>
                                    <p className="text-2xl font-semibold text-foreground">
                                        {String(Math.round(analytics.productivityMetrics.consistency_score or 0, 1))}%
                                    </p>
                                </div>
                                <div>
                                    <p className="text-xs text-muted-foreground">Current Streak</p>
                                    <p className="text-2xl font-semibold text-foreground">
                                        {String(analytics.productivityMetrics.current_streak or 0)} days
                                    </p>
                                </div>
                                <div>
                                    <p className="text-xs text-muted-foreground">Days Tracked</p>
                                    <p className="text-2xl font-semibold text-foreground">
                                        {String(analytics.productivityMetrics.days_tracked or 0)}
                                    </p>
                                </div>
                            </div>
                        </div>) if analytics.productivityMetrics else (<Fragment />)
                    }
                    {
                        (<div className="glass-panel rounded-xl p-4">
                            <h3 className="text-sm font-medium text-foreground mb-3">Insights</h3>
                            <div className="space-y-2">
                                {insightItems}
                            </div>
                        </div>) if (analytics.insights and insightItems.length > 0) else (<Fragment />)
                    }
                </div>
            </div>
        </div>;
    }

    # Fallback
    return <div className="glass-panel rounded-xl h-full flex flex-col p-6">
        <p>Analytics panel loaded</p>
    </div>;
}

glob:pub AnalyticsPanel = AnalyticsPanelComponent;
