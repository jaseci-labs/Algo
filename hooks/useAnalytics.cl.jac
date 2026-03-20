# useAnalytics Hook
# Enhanced analytics state management hook for behavioral insights, trends, patterns, and goals
# Uses local hook state variables for analytics reactivity
import from react { useRef }
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

def:pub useAnalytics() -> dict {
    # React state for analytics data
    has activityReport: dict | None = None;
    has trendData: dict | None = None;
    has behavioralPatterns: dict | None = None;
    has productivityMetrics: dict | None = None;
    has insights: list = [];
    has isLoading: bool = False;
    has error: str = "";
    has selectedPeriod: str = "week";
    has selectedCategory: str = "all";

    # NEW: Enhanced analytics state
    has discoveredPatterns: list = [];
    has temporalInsights: dict | None = None;
    has comparativeInsights: dict | None = None;
    has userGoals: list = [];
    has userAchievements: list = [];
    has proactiveInsights: list = [];

    # ========== Fetch All Analytics Data ==========
    async def fetchAllAnalytics() -> None {
        isLoading = True;
        error = "";

        # Log analytics view event
        try {
            await logActivityEvent("insights_requested", {}, "", "", "", 0);
        } except Exception as e { }

        # Fetch each independently and handle errors
        activityResult = {"success": False};
        try {
            activityResult = await getActivityReport({});
        } except Exception as e { }

        trendResult = {"success": False};
        try {
            trendResult = await getTrendAnalysis(selectedPeriod);
        } except Exception as e { }

        patternsResult = {"success": False};
        try {
            patternsResult = await getBehavioralPatterns();
        } except Exception as e { }

        productivityResult = {"success": False};
        try {
            productivityResult = await getProductivityMetrics();
        } except Exception as e { }

        insightsResult = {"success": False};
        try {
            insightsResult = await getInsights(selectedCategory);
        } except Exception as e { }

        # NEW: Fetch enhanced analytics
        discoveredResult = {"success": False};
        try {
            discoveredResult = await discoverPatterns(30);
        } except Exception as e { }

        temporalResult = {"success": False};
        try {
            temporalResult = await getTemporalInsights(30);
        } except Exception as e { }

        goalsResult = {"success": False};
        try {
            goalsResult = await getGoals();
        } except Exception as e { }

        achievementsResult = {"success": False};
        try {
            achievementsResult = await getAchievements();
        } except Exception as e { }

        proactiveResult = {"success": False};
        try {
            proactiveResult = await getProactiveInsights();
        } except Exception as e { }

        # Process successful results
        if activityResult.success {
            activityReport = activityResult.data;
        }
        if trendResult.success {
            trendData = trendResult.data;
        }
        if patternsResult.success {
            behavioralPatterns = patternsResult.data;
        }
        if productivityResult.success {
            productivityMetrics = productivityResult.data;
        }
        if insightsResult.success {
            if insightsResult.data.insights {
                insights = insightsResult.data.insights;
            } else {
                insights = insightsResult.data;
            }
        }
        if discoveredResult.success {
            discoveredPatterns = discoveredResult.data.patterns or [];
        }
        if temporalResult.success {
            temporalInsights = temporalResult.data;
        }
        if goalsResult.success {
            userGoals = goalsResult.data.goals or [];
        }
        if achievementsResult.success {
            userAchievements = achievementsResult.data.achievements or [];
        }
        if proactiveResult.success {
            proactiveInsights = proactiveResult.data.insights or [];
        }

        isLoading = False;
    }

    # ========== Pattern Discovery ==========
    async def fetchDiscoveredPatterns(timeWindowDays: int = 30) -> None {
        isLoading = True;
        try {
            result = await discoverPatterns(timeWindowDays);
            if result.success {
                discoveredPatterns = result.data.patterns or [];
            } else {
                error = result.error or "Failed to discover patterns";
            }
        } except Exception as e {
            error = String(e);
        }
        isLoading = False;
    }

    # ========== Temporal Insights ==========
    async def fetchTemporalInsights(lookbackDays: int = 30) -> None {
        isLoading = True;
        try {
            result = await getTemporalInsights(lookbackDays);
            if result.success {
                temporalInsights = result.data;
            } else {
                error = result.error or "Failed to get temporal insights";
            }
        } except Exception as e {
            error = String(e);
        }
        isLoading = False;
    }

    # ========== Comparative Insights ==========
    async def fetchComparativeInsights(periodType: str = "week") -> None {
        isLoading = True;
        try {
            result = await getComparativeInsights(periodType);
            if result.success {
                comparativeInsights = result.data;
            } else {
                error = result.error or "Failed to get comparative insights";
            }
        } except Exception as e {
            error = String(e);
        }
        isLoading = False;
    }

    # ========== Goal Management ==========
    async def fetchGoals() -> None {
        try {
            result = await getGoals();
            if result.success {
                userGoals = result.data.goals or [];
            }
        } except Exception as e { }
    }

    async def createNewGoal(goalType: str, targetValue: int) -> dict {
        isLoading = True;
        try {
            result = await createGoal(goalType, targetValue);
            isLoading = False;
            if result.success {
                # Refresh goals after creating
                await fetchGoals();
            }
            return result;
        } except Exception as e {
            error = String(e);
            isLoading = False;
            return {"success": False, "error": String(e)};
        }
    }

    async def updateGoal(goalType: str, progress: int) -> dict {
        isLoading = True;
        try {
            result = await updateGoalProgress(goalType, progress);
            isLoading = False;
            if result.success {
                # Refresh goals after updating
                await fetchGoals();
            }
            return result;
        } except Exception as e {
            error = String(e);
            isLoading = False;
            return {"success": False, "error": String(e)};
        }
    }

    # ========== Achievement Management ==========
    async def fetchAchievements() -> None {
        try {
            result = await getAchievements();
            if result.success {
                userAchievements = result.data.achievements or [];
            }
        } except Exception as e { }
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
                proactiveInsights = result.data.insights or [];
            }
        } except Exception as e { }
    }

    # ========== Insight Feedback ==========
    async def markInsightAsViewed(insightId: str) -> dict {
        try {
            result = await markInsightViewed(insightId);
            # Update local insight state
            insights = [
                (
                    lambda insight: any  -> any { 
                        if insight.id == insightId {
                            insight.viewed = True;
                        }return insight; 
                    }
                )(insight) for insight in insights
            ];
            return result;
        } except Exception as e {
            return {"success": False, "error": String(e)};
        }
    }

    async def markInsightAsActedUpon(insightId: str) -> dict {
        try {
            result = await markInsightActedUpon(insightId);
            # Update local insight state
            insights = [
                (
                    lambda insight: any  -> any { 
                        if insight.id == insightId {
                            insight.actedUpon = True;
                        }return insight; 
                    }
                )(insight) for insight in insights
            ];
            return result;
        } except Exception as e {
            return {"success": False, "error": String(e)};
        }
    }

    async def dismissInsightById(insightId: str, reason: str = "") -> dict {
        try {
            result = await dismissInsight(insightId, reason);
            # Remove from local insights
            insights = [insight for insight in insights if insight.id != insightId];
            return result;
        } except Exception as e {
            return {"success": False, "error": String(e)};
        }
    }

    # ========== Existing Fetch Functions ==========
    async def fetchActivityReport(dateRange: dict = {}) -> None {
        isLoading = True;
        try {
            result = await getActivityReport(dateRange);
            if result.success {
                activityReport = result.data;
            } else {
                error = result.error or "Failed to fetch activity report";
            }
        } except Exception as e {
            error = String(e);
        }
        isLoading = False;
    }

    async def fetchTrendAnalysis(period: str) -> None {
        isLoading = True;
        try {
            result = await getTrendAnalysis(period);
            if result.success {
                trendData = result.data;
                selectedPeriod = period;
            } else {
                error = result.error or "Failed to fetch trend analysis";
            }
        } except Exception as e {
            error = String(e);
        }
        isLoading = False;
    }

    async def fetchBehavioralPatterns() -> None {
        isLoading = True;
        try {
            result = await getBehavioralPatterns();
            if result.success {
                behavioralPatterns = result.data;
            } else {
                error = result.error or "Failed to fetch behavioral patterns";
            }
        } except Exception as e {
            error = String(e);
        }
        isLoading = False;
    }

    async def fetchProductivityMetrics() -> None {
        isLoading = True;
        try {
            result = await getProductivityMetrics();
            if result.success {
                productivityMetrics = result.data;
            } else {
                error = result.error or "Failed to fetch productivity metrics";
            }
        } except Exception as e {
            error = String(e);
        }
        isLoading = False;
    }

    async def fetchInsights(category: str) -> None {
        isLoading = True;
        try {
            result = await getInsights(category);
            if result.success {
                insights = result.data.insights or [];
                selectedCategory = category;
            } else {
                error = result.error or "Failed to fetch insights";
            }
        } except Exception as e {
            error = String(e);
        }
        isLoading = False;
    }

    # ========== Refresh ==========
    async def refreshAnalytics() -> None {
        await fetchAllAnalytics();
    }

    # ========== Event Logging ==========
    async def logEvent(
        eventType: str,
        eventData: dict = {},
        sessionId: str = "",
        taskContext: str = "",
        emotionalContext: str = "",
        durationMs: int = 0
    ) -> None {
        try {
            await logActivityEvent(
                eventType,
                eventData,
                sessionId,
                taskContext,
                emotionalContext,
                durationMs
            );
        } except Exception as e { }
    }

    # ========== Export ==========
    async def exportData(format: str) -> None {
        isLoading = True;
        try {
            # Use the exportAnalyticsData from API
            result = await exportAnalyticsData(format);
            isLoading = False;

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
            error = String(e);
            isLoading = False;
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
        # NEW: Enhanced action functions
        "createNewGoal": createNewGoal,
        "updateGoal": updateGoal,
        "checkForAchievements": checkForAchievements,
        "markInsightAsViewed": markInsightAsViewed,
        "markInsightAsActedUpon": markInsightAsActedUpon,
        "dismissInsightById": dismissInsightById
    };
}
