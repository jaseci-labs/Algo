# Analytics API Layer
# Provides endpoints for fetching user analytics, trends, and insights

import from .api { getUsernameFromToken }

# Get the user's overall activity report
async def:pub getActivityReport(dateRange: dict = {}) -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn get_activity_report(
            username=username,
            date_range=dateRange
        );

        if response and response.reports and response.reports.length > 0 {
            result = {
                "success": True,
                "data": response.reports[0]
            };
            return result;
        }

        return {
            "success": False,
            "error": "Failed to get activity report"
        };
    } except Exception as e {
        console.error("[API] getActivityReport error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# Get trend analysis over a time period
async def:pub getTrendAnalysis(period: str = "week") -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn get_trend_analysis(
            username=username,
            period=period
        );

        if response and response.reports and response.reports.length > 0 {
            return {
                "success": True,
                "data": response.reports[0]
            };
        }

        return {
            "success": False,
            "error": "Failed to get trend analysis"
        };
    } except Exception as e {
        console.error("[API] getTrendAnalysis error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# Get behavioral patterns analysis
async def:pub getBehavioralPatterns() -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn analyze_behavioral_patterns(
            username=username
        );

        if response and response.reports and response.reports.length > 0 {
            return {
                "success": True,
                "data": response.reports[0]
            };
        }

        return {
            "success": False,
            "error": "Failed to get behavioral patterns"
        };
    } except Exception as e {
        console.error("[API] getBehavioralPatterns error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# Get productivity metrics for the user
async def:pub getProductivityMetrics() -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn calculate_productivity_metrics(
            username=username
        );

        if response and response.reports and response.reports.length > 0 {
            return {
                "success": True,
                "data": response.reports[0]
            };
        }

        return {
            "success": False,
            "error": "Failed to get productivity metrics"
        };
    } except Exception as e {
        console.error("[API] getProductivityMetrics error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# Get AI-powered insights and recommendations
async def:pub getInsights(category: str = "all") -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn generate_insights(
            username=username,
            category=category
        );

        if response and response.reports and response.reports.length > 0 {
            return {
                "success": True,
                "data": response.reports[0]
            };
        }

        return {
            "success": False,
            "error": "Failed to generate insights"
        };
    } except Exception as e {
        console.error("[API] getInsights error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# Log an activity event for analytics tracking
async def:pub logActivityEvent(eventType: str, eventData: dict = {}, sessionId: str = "") -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn log_activity_event(
            username=username,
            event_type=eventType,
            event_data=eventData,
            session_id=sessionId
        );

        if response and response.reports and response.reports.length > 0 {
            return {
                "success": True,
                "data": response.reports[0]
            };
        }

        return {
            "success": False,
            "error": "Failed to log activity event"
        };
    } except Exception as e {
        console.error("[API] logActivityEvent error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# Export analytics data in various formats
async def:pub exportAnalyticsData(format: str = "json") -> any {
    try {
        username = getUsernameFromToken();

        # Fetch all data to export
        response = root spawn get_activity_report(
            username=username,
            date_range={}
        );

        if response and response.reports and response.reports.length > 0 {
            data = response.reports[0];
            return {
                "success": True,
                "data": data
            };
        }

        return {
            "success": False,
            "error": "Failed to export analytics data"
        };
    } except Exception as e {
        console.error("[API] exportAnalyticsData error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}
