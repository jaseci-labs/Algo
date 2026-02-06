# useAnalytics Hook
# Analytics state management hook for behavioral insights and trends
# Uses React useState for proper reactivity

import from react { useState, useEffect, useRef }
import from ..api.analytics {
    getActivityReport,
    getTrendAnalysis,
    getBehavioralPatterns,
    getProductivityMetrics,
    getInsights,
    exportAnalyticsData,
    logActivityEvent
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

    # Track if initial fetch has been done
    hasInitializedRef = useRef(False);

    # ========== Fetch All Analytics Data ==========
    async def fetchAllAnalytics() -> None {
        setIsLoading(True);
        setError("");

        console.log("[useAnalytics] Fetching all analytics data...");

        # Log analytics view event
        try {
            await logActivityEvent("insights_requested", {}, "");
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

        setIsLoading(False);
    }

    # ========== Fetch Individual Data ==========
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
    }

    # ========== Event Logging ==========
    async def logEvent(eventType: str, eventData: dict = {}) -> None {
        try {
            await logActivityEvent(eventType, eventData, "");
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

        # Fetch Functions
        "fetchActivityReport": fetchActivityReport,
        "fetchTrendAnalysis": fetchTrendAnalysis,
        "fetchBehavioralPatterns": fetchBehavioralPatterns,
        "fetchProductivityMetrics": fetchProductivityMetrics,
        "fetchInsights": fetchInsights,
        "fetchAllAnalytics": fetchAllAnalytics,
        "refreshAnalytics": refreshAnalytics,

        # Action Functions
        "exportData": exportData,
        "logEvent": logEvent,
        "setSelectedPeriod": setSelectedPeriod,
        "setSelectedCategory": setSelectedCategory
    };
}
