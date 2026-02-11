# useAnalytics Hook
# Enhanced analytics state management hook for behavioral insights, trends, patterns, and goals
# Uses React useState for proper reactivity

import from react { useState, useEffect, useRef }
import from ..api.analytics {
    getActivityReport,
    getTrendAnalysis,
    getBehavioralPatterns,
    getProductivityMetrics,
    getInsights,
    exportAnalyticsData,
    logActivityEvent,
    discoverPatterns,
    getTemporalInsights,
    getComparativeInsights,
    createGoal,
    getGoals,
    updateGoalProgress,
    checkAchievements,
    getAchievements,
    getProactiveInsights,
    markInsightViewed,
    markInsightActedUpon,
    dismissInsight
}

def:pub useAnalytics() -> any {
    # React state for analytics data
    [activityReport, setActivityReport] = useState(None);
    [trendData, setTrendData] = useState(None);
    [behavioralPatterns, setBehavioralPatterns] = useState(None);
    [productivityMetrics, setProductivityMetrics] = useState(None);
    [insights, setInsights] = useState([]);
    [isLoading, setIsLoading] = useState(False);
    [error, setError] = useState("");
    [selectedPeriod, setSelectedPeriod] = useState("week");
    [selectedCategory, setSelectedCategory] = useState("all");

    # NEW: Enhanced analytics state
    [discoveredPatterns, setDiscoveredPatterns] = useState([]);
    [temporalInsights, setTemporalInsights] = useState(None);
    [comparativeInsights, setComparativeInsights] = useState(None);
    [userGoals, setUserGoals] = useState([]);
    [userAchievements, setUserAchievements] = useState([]);
    [proactiveInsights, setProactiveInsights] = useState([]);

    # Track if initial fetch has been done
    hasInitializedRef = useRef(False);

    # ========== Fetch All Analytics Data ==========
    async def fetchAllAnalytics() -> None {
        setIsLoading(True);
        setError("");

        console.log("[useAnalytics] Fetching all analytics data...");

        # Log analytics view event
        try {
            await logActivityEvent("insights_requested", {}, "", "", "", 0);
        } except Exception as e {
            console.error("[useAnalytics] Failed to log event:", e);
        }

        # Fetch each independently and handle errors
        activityResult = {"success": False};
        try {
            activityResult = await getActivityReport({});
        } except Exception as e {
            console.error("[useAnalytics] Activity report failed:", e);
        }

        trendResult = {"success": False};
        try {
            trendResult = await getTrendAnalysis(selectedPeriod);
        } except Exception as e {
            console.error("[useAnalytics] Trend analysis failed:", e);
        }

        patternsResult = {"success": False};
        try {
            patternsResult = await getBehavioralPatterns();
        } except Exception as e {
            console.error("[useAnalytics] Behavioral patterns failed:", e);
        }

        productivityResult = {"success": False};
        try {
            productivityResult = await getProductivityMetrics();
        } except Exception as e {
            console.error("[useAnalytics] Productivity metrics failed:", e);
        }

        insightsResult = {"success": False};
        try {
            insightsResult = await getInsights(selectedCategory);
        } except Exception as e {
            console.error("[useAnalytics] Insights failed:", e);
        }

        # NEW: Fetch enhanced analytics
        discoveredResult = {"success": False};
        try {
            discoveredResult = await discoverPatterns(30);
        } except Exception as e {
            console.error("[useAnalytics] Pattern discovery failed:", e);
        }

        temporalResult = {"success": False};
        try {
            temporalResult = await getTemporalInsights(30);
        } except Exception as e {
            console.error("[useAnalytics] Temporal insights failed:", e);
        }

        goalsResult = {"success": False};
        try {
            goalsResult = await getGoals();
        } except Exception as e {
            console.error("[useAnalytics] Goals fetch failed:", e);
        }

        achievementsResult = {"success": False};
        try {
            achievementsResult = await getAchievements();
        } except Exception as e {
            console.error("[useAnalytics] Achievements fetch failed:", e);
        }

        proactiveResult = {"success": False};
        try {
            proactiveResult = await getProactiveInsights();
        } except Exception as e {
            console.error("[useAnalytics] Proactive insights failed:", e);
        }

        # Process successful results
        if activityResult.success {
            setActivityReport(activityResult.data);
        }
        if trendResult.success {
            setTrendData(trendResult.data);
        }
        if patternsResult.success {
            setBehavioralPatterns(patternsResult.data);
        }
        if productivityResult.success {
            setProductivityMetrics(productivityResult.data);
        }
        if insightsResult.success {
            if insightsResult.data.insights {
                setInsights(insightsResult.data.insights);
            } else {
                setInsights(insightsResult.data);
            }
        }
        if discoveredResult.success {
            setDiscoveredPatterns(discoveredResult.data.patterns or []);
        }
        if temporalResult.success {
            setTemporalInsights(temporalResult.data);
        }
        if goalsResult.success {
            setUserGoals(goalsResult.data.goals or []);
        }
        if achievementsResult.success {
            setUserAchievements(achievementsResult.data.achievements or []);
        }
        if proactiveResult.success {
            setProactiveInsights(proactiveResult.data.insights or []);
        }

        setIsLoading(False);
    }

    # ========== Pattern Discovery ==========
    async def fetchDiscoveredPatterns(timeWindowDays: int = 30) -> None {
        setIsLoading(True);
        try {
            result = await discoverPatterns(timeWindowDays);
            if result.success {
                setDiscoveredPatterns(result.data.patterns or []);
            } else {
                setError(result.error or "Failed to discover patterns");
            }
        } except Exception as e {
            setError(String(e));
        }
        setIsLoading(False);
    }

    # ========== Temporal Insights ==========
    async def fetchTemporalInsights(lookbackDays: int = 30) -> None {
        setIsLoading(True);
        try {
            result = await getTemporalInsights(lookbackDays);
            if result.success {
                setTemporalInsights(result.data);
            } else {
                setError(result.error or "Failed to get temporal insights");
            }
        } except Exception as e {
            setError(String(e));
        }
        setIsLoading(False);
    }

    # ========== Comparative Insights ==========
    async def fetchComparativeInsights(periodType: str = "week") -> None {
        setIsLoading(True);
        try {
            result = await getComparativeInsights(periodType);
            if result.success {
                setComparativeInsights(result.data);
            } else {
                setError(result.error or "Failed to get comparative insights");
            }
        } except Exception as e {
            setError(String(e));
        }
        setIsLoading(False);
    }

    # ========== Goal Management ==========
    async def fetchGoals() -> None {
        try {
            result = await getGoals();
            if result.success {
                setUserGoals(result.data.goals or []);
            }
        } except Exception as e {
            console.error("[useAnalytics] Failed to fetch goals:", e);
        }
    }

    async def createNewGoal(goalType: str, targetValue: int) -> dict {
        setIsLoading(True);
        try {
            result = await createGoal(goalType, targetValue);
            setIsLoading(False);
            if result.success {
                # Refresh goals after creating
                await fetchGoals();
            }
            return result;
        } except Exception as e {
            setError(String(e));
            setIsLoading(False);
            return {"success": False, "error": String(e)};
        }
    }

    async def updateGoal(goalType: str, progress: int) -> dict {
        setIsLoading(True);
        try {
            result = await updateGoalProgress(goalType, progress);
            setIsLoading(False);
            if result.success {
                # Refresh goals after updating
                await fetchGoals();
            }
            return result;
        } except Exception as e {
            setError(String(e));
            setIsLoading(False);
            return {"success": False, "error": String(e)};
        }
    }

    # ========== Achievement Management ==========
    async def fetchAchievements() -> None {
        try {
            result = await getAchievements();
            if result.success {
                setUserAchievements(result.data.achievements or []);
            }
        } except Exception as e {
            console.error("[useAnalytics] Failed to fetch achievements:", e);
        }
    }

    async def checkForAchievements() -> dict {
        try {
            result = await checkAchievements();
            if result.success {
                # Refresh achievements after checking
                await fetchAchievements();
            }
            return result;
        } except Exception as e {
            console.error("[useAnalytics] Failed to check achievements:", e);
            return {"success": False, "error": String(e)};
        }
    }

    # ========== Proactive Insights ==========
    async def fetchProactiveInsights() -> None {
        try {
            result = await getProactiveInsights();
            if result.success {
                setProactiveInsights(result.data.insights or []);
            }
        } except Exception as e {
            console.error("[useAnalytics] Failed to fetch proactive insights:", e);
        }
    }

    # ========== Insight Feedback ==========
    async def markInsightAsViewed(insightId: str) -> dict {
        try {
            result = await markInsightViewed(insightId);
            # Update local insight state
            setInsights(insights.map(lambda insight: any -> any {
                if insight.id == insightId {
                    insight.viewed = True;
                }
                return insight;
            }));
            return result;
        } except Exception as e {
            console.error("[useAnalytics] Failed to mark insight viewed:", e);
            return {"success": False, "error": String(e)};
        }
    }

    async def markInsightAsActedUpon(insightId: str) -> dict {
        try {
            result = await markInsightActedUpon(insightId);
            # Update local insight state
            setInsights(insights.map(lambda insight: any -> any {
                if insight.id == insightId {
                    insight.acted_upon = True;
                }
                return insight;
            }));
            return result;
        } except Exception as e {
            console.error("[useAnalytics] Failed to mark insight acted upon:", e);
            return {"success": False, "error": String(e)};
        }
    }

    async def dismissInsightById(insightId: str, reason: str = "") -> dict {
        try {
            result = await dismissInsight(insightId, reason);
            # Remove from local insights
            setInsights(insights.filter(lambda insight: any -> bool {
                return insight.id != insightId;
            }));
            return result;
        } except Exception as e {
            console.error("[useAnalytics] Failed to dismiss insight:", e);
            return {"success": False, "error": String(e)};
        }
    }

    # ========== Existing Fetch Functions ==========
    async def fetchActivityReport(dateRange: dict = {}) -> None {
        setIsLoading(True);
        try {
            result = await getActivityReport(dateRange);
            if result.success {
                setActivityReport(result.data);
            } else {
                setError(result.error or "Failed to fetch activity report");
            }
        } except Exception as e {
            setError(String(e));
        }
        setIsLoading(False);
    }

    async def fetchTrendAnalysis(period: str) -> None {
        setIsLoading(True);
        try {
            result = await getTrendAnalysis(period);
            if result.success {
                setTrendData(result.data);
                setSelectedPeriod(period);
            } else {
                setError(result.error or "Failed to fetch trend analysis");
            }
        } except Exception as e {
            setError(String(e));
        }
        setIsLoading(False);
    }

    async def fetchBehavioralPatterns() -> None {
        setIsLoading(True);
        try {
            result = await getBehavioralPatterns();
            if result.success {
                setBehavioralPatterns(result.data);
            } else {
                setError(result.error or "Failed to fetch behavioral patterns");
            }
        } except Exception as e {
            setError(String(e));
        }
        setIsLoading(False);
    }

    async def fetchProductivityMetrics() -> None {
        setIsLoading(True);
        try {
            result = await getProductivityMetrics();
            if result.success {
                setProductivityMetrics(result.data);
            } else {
                setError(result.error or "Failed to fetch productivity metrics");
            }
        } except Exception as e {
            setError(String(e));
        }
        setIsLoading(False);
    }

    async def fetchInsights(category: str) -> None {
        setIsLoading(True);
        try {
            result = await getInsights(category);
            if result.success {
                setInsights(result.data.insights or []);
                setSelectedCategory(category);
            } else {
                setError(result.error or "Failed to fetch insights");
            }
        } except Exception as e {
            setError(String(e));
        }
        setIsLoading(False);
    }

    # ========== Refresh ==========
    async def refreshAnalytics() -> None {
        await fetchActivityReport({});
        await fetchTrendAnalysis(selectedPeriod);
        await fetchBehavioralPatterns();
        await fetchProductivityMetrics();
        await fetchInsights(selectedCategory);
        await fetchDiscoveredPatterns();
        await fetchTemporalInsights();
        await fetchGoals();
        await fetchAchievements();
        await fetchProactiveInsights();
    }

    # ========== Event Logging ==========
    async def logEvent(eventType: str, eventData: dict = {}, sessionId: str = "", taskContext: str = "", emotionalContext: str = "", durationMs: int = 0) -> None {
        try {
            await logActivityEvent(eventType, eventData, sessionId, taskContext, emotionalContext, durationMs);
        } except Exception as e {
            console.error("[useAnalytics] Failed to log event:", e);
        }
    }

    # ========== Export ==========
    async def exportData(format: str) -> None {
        setIsLoading(True);
        try {
            # Use the exportAnalyticsData from API
            result = await exportAnalyticsData(format);
            setIsLoading(False);

            if result.success and result.data {
                if format == "json" {
                    dataStr = JSON.stringify(result.data, None, 2);
                    dataBlob = Blob([dataStr], {"type": "application/json"});
                    url = URL.createObjectURL(dataBlob);
                    link = document.createElement("a");
                    link.href = url;
                    link.download = "algo-analytics.json";
                    document.body.appendChild(link);
                    link.click();
                    document.body.removeChild(link);
                    URL.revokeObjectURL(url);
                }
                return {"success": True};
            }
            return {"success": False};
        } except Exception as e {
            setError(String(e));
            setIsLoading(False);
            return {"success": False};
        }
    }

    # ========== Return Hook Interface ==========
    return {
        # State
        "activityReport": activityReport,
        "trendData": trendData,
        "behavioralPatterns": behavioralPatterns,
        "productivityMetrics": productivityMetrics,
        "insights": insights,
        "isLoading": isLoading,
        "error": error,
        "selectedPeriod": selectedPeriod,
        "selectedCategory": selectedCategory,

        # NEW: Enhanced state
        "discoveredPatterns": discoveredPatterns,
        "temporalInsights": temporalInsights,
        "comparativeInsights": comparativeInsights,
        "userGoals": userGoals,
        "userAchievements": userAchievements,
        "proactiveInsights": proactiveInsights,

        # Fetch Functions
        "fetchActivityReport": fetchActivityReport,
        "fetchTrendAnalysis": fetchTrendAnalysis,
        "fetchBehavioralPatterns": fetchBehavioralPatterns,
        "fetchProductivityMetrics": fetchProductivityMetrics,
        "fetchInsights": fetchInsights,
        "fetchAllAnalytics": fetchAllAnalytics,
        "refreshAnalytics": refreshAnalytics,

        # NEW: Enhanced fetch functions
        "fetchDiscoveredPatterns": fetchDiscoveredPatterns,
        "fetchTemporalInsights": fetchTemporalInsights,
        "fetchComparativeInsights": fetchComparativeInsights,
        "fetchGoals": fetchGoals,
        "fetchAchievements": fetchAchievements,
        "fetchProactiveInsights": fetchProactiveInsights,

        # Action Functions
        "exportData": exportData,
        "logEvent": logEvent,
        "setSelectedPeriod": setSelectedPeriod,
        "setSelectedCategory": setSelectedCategory,

        # NEW: Enhanced action functions
        "createNewGoal": createNewGoal,
        "updateGoal": updateGoal,
        "checkForAchievements": checkForAchievements,
        "markInsightAsViewed": markInsightAsViewed,
        "markInsightAsActedUpon": markInsightAsActedUpon,
        "dismissInsightById": dismissInsightById
    };
}
