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

# ========== Enhanced Analytics API Endpoints ==========

# Discover routine patterns in user's activity
async def:pub discoverPatterns(timeWindowDays: int = 30) -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn discover_patterns(
            username=username,
            time_window_days=timeWindowDays
        );

        if response and response.reports and response.reports.length > 0 {
            return {
                "success": True,
                "data": response.reports[0]
            };
        }

        return {
            "success": False,
            "error": "Failed to discover patterns"
        };
    } except Exception as e {
        console.error("[API] discoverPatterns error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# Get temporal insights (peak hours, peak days)
async def:pub getTemporalInsights(lookbackDays: int = 30) -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn get_temporal_insights(
            username=username,
            lookback_days=lookbackDays
        );

        if response and response.reports and response.reports.length > 0 {
            return {
                "success": True,
                "data": response.reports[0]
            };
        }

        return {
            "success": False,
            "error": "Failed to get temporal insights"
        };
    } except Exception as e {
        console.error("[API] getTemporalInsights error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# Get comparative insights (week over week, month over month)
async def:pub getComparativeInsights(periodType: str = "week") -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn get_comparative_insights(
            username=username,
            period_type=periodType
        );

        if response and response.reports and response.reports.length > 0 {
            return {
                "success": True,
                "data": response.reports[0]
            };
        }

        return {
            "success": False,
            "error": "Failed to get comparative insights"
        };
    } except Exception as e {
        console.error("[API] getComparativeInsights error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# ========== Goal Management API Endpoints ==========

# Create a new goal
async def:pub createGoal(goalType: str, targetValue: int) -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn create_goal(
            username=username,
            goal_type=goalType,
            target_value=targetValue
        );

        if response and response.reports and response.reports.length > 0 {
            return {
                "success": True,
                "data": response.reports[0]
            };
        }

        return {
            "success": False,
            "error": "Failed to create goal"
        };
    } except Exception as e {
        console.error("[API] createGoal error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# Get user's goals
async def:pub getGoals() -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn get_goals(username=username);

        if response and response.reports and response.reports.length > 0 {
            return {
                "success": True,
                "data": response.reports[0]
            };
        }

        return {
            "success": False,
            "error": "Failed to get goals"
        };
    } except Exception as e {
        console.error("[API] getGoals error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# Update goal progress
async def:pub updateGoalProgress(goalType: str, progress: int) -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn update_goal_progress(
            username=username,
            goal_type=goalType,
            progress=progress
        );

        if response and response.reports and response.reports.length > 0 {
            return {
                "success": True,
                "data": response.reports[0]
            };
        }

        return {
            "success": False,
            "error": "Failed to update goal progress"
        };
    } except Exception as e {
        console.error("[API] updateGoalProgress error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# ========== Achievement API Endpoints ==========

# Check for and unlock achievements
async def:pub checkAchievements() -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn check_achievements(username=username);

        if response and response.reports and response.reports.length > 0 {
            return {
                "success": True,
                "data": response.reports[0]
            };
        }

        return {
            "success": False,
            "error": "Failed to check achievements"
        };
    } except Exception as e {
        console.error("[API] checkAchievements error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# Get user's achievements
async def:pub getAchievements() -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn get_achievements(username=username);

        if response and response.reports and response.reports.length > 0 {
            return {
                "success": True,
                "data": response.reports[0]
            };
        }

        return {
            "success": False,
            "error": "Failed to get achievements"
        };
    } except Exception as e {
        console.error("[API] getAchievements error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# ========== Proactive Insights API Endpoints ==========

# Get proactive insights (streak at risk, achievements, etc.)
async def:pub getProactiveInsights() -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn get_proactive_insights(username=username);

        if response and response.reports and response.reports.length > 0 {
            return {
                "success": True,
                "data": response.reports[0]
            };
        }

        return {
            "success": False,
            "error": "Failed to get proactive insights"
        };
    } except Exception as e {
        console.error("[API] getProactiveInsights error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# ========== Insight Feedback API Endpoints ==========

# Mark an insight as viewed
async def:pub markInsightViewed(insightId: str) -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn mark_insight_viewed(
            username=username,
            insight_id=insightId
        );

        if response and response.reports and response.reports.length > 0 {
            return {
                "success": True,
                "data": response.reports[0]
            };
        }

        return {
            "success": False,
            "error": "Failed to mark insight as viewed"
        };
    } except Exception as e {
        console.error("[API] markInsightViewed error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# Mark an insight as acted upon
async def:pub markInsightActedUpon(insightId: str) -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn mark_insight_acted_upon(
            username=username,
            insight_id=insightId
        );

        if response and response.reports and response.reports.length > 0 {
            return {
                "success": True,
                "data": response.reports[0]
            };
        }

        return {
            "success": False,
            "error": "Failed to mark insight as acted upon"
        };
    } except Exception as e {
        console.error("[API] markInsightActedUpon error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# Dismiss an insight
async def:pub dismissInsight(insightId: str, reason: str = "") -> any {
    try {
        username = getUsernameFromToken();

        response = root spawn dismiss_insight(
            username=username,
            insight_id=insightId,
            reason=reason
        );

        if response and response.reports and response.reports.length > 0 {
            return {
                "success": True,
                "data": response.reports[0]
            };
        }

        return {
            "success": False,
            "error": "Failed to dismiss insight"
        };
    } except Exception as e {
        console.error("[API] dismissInsight error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}
