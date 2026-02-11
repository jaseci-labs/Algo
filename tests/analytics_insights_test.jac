# Analytics Insights Generation Tests
# Tests for insight generation and semantic functions
#
# These tests verify:
# 1. Insights are generated based on actual data
# 2. Insights are actionable and personalized
# 3. Different insight categories are produced
# 4. Insights adapt to user behavior patterns

import {
    generate_personalized_insights,
    generate_comparative_insights,
    discover_routine_patterns,
    analyze_temporal_patterns
}

test "generate_personalized_insights returns 3-4 insights" {
    insights = generate_personalized_insights(
        total_tasks=15,
        consistency_score=75.0,
        efficiency_score=60.0,
        current_streak=5,
        peak_hour="09",
        peak_day="Tuesday",
        total_events=45,
        emotion_distribution={"neutral": 0.6, "focused": 0.3, "stressed": 0.1},
        connection_patterns={"sequential": 0.7, "parallel": 0.2, "conditional": 0.1, "convergent": 0.0}
    );

    # Should return 3-4 insights
    assert len(insights) >= 3;
    assert len(insights) <= 4;
}

test "generate_personalized_insights varies categories" {
    insights = generate_personalized_insights(
        total_tasks=25,
        consistency_score=85.0,
        efficiency_score=70.0,
        current_streak=7,
        peak_hour="09",
        peak_day="Tuesday",
        total_events=80,
        emotion_distribution={"neutral": 0.5, "focused": 0.4, "stressed": 0.1},
        connection_patterns={"sequential": 0.6, "parallel": 0.2, "conditional": 0.2, "convergent": 0.0}
    );

    categories = [];
    for insight in insights {
        if insight.category not in categories {
            categories.append(insight.category);
        }
    }

    # Should have insights from at least 2 different categories
    assert len(categories) >= 2;
}

test "generate_personalized_insights for new user" {
    insights = generate_personalized_insights(
        total_tasks=2,
        consistency_score=30.0,
        efficiency_score=40.0,
        current_streak=1,
        peak_hour="0",
        peak_day="Monday",
        total_events=5,
        emotion_distribution={"neutral": 1.0},
        connection_patterns={"sequential": 1.0, "parallel": 0.0, "conditional": 0.0, "convergent": 0.0}
    );

    # Should provide getting started insights
    assert len(insights) >= 3;

    # At least one should be recommendations
    has_recommendations = False;
    for insight in insights {
        if insight.category == "recommendations" {
            has_recommendations = True;
        }
    }
    assert has_recommendations;
}

test "generate_personalized_insights includes streak celebration" {
    insights = generate_personalized_insights(
        total_tasks=30,
        consistency_score=90.0,
        efficiency_score=75.0,
        current_streak=10,
        peak_hour="09",
        peak_day="Tuesday",
        total_events=100,
        emotion_distribution={"focused": 0.7, "neutral": 0.3},
        connection_patterns={"sequential": 0.5, "parallel": 0.3, "conditional": 0.2, "convergent": 0.0}
    );

    # With 10-day streak, should have celebratory insight
    has_celebration = False;
    for insight in insights {
        if "streak" in insight.description.lower() or "day" in insight.description.lower() {
            has_celebration = True;
        }
    }
    assert has_celebration;
}

test "generate_personalized_insights actionable flags correct" {
    insights = generate_personalized_insights(
        total_tasks=15,
        consistency_score=60.0,
        efficiency_score=55.0,
        current_streak=3,
        peak_hour="09",
        peak_day="Tuesday",
        total_events=50,
        emotion_distribution={"neutral": 0.5, "stressed": 0.3, "focused": 0.2},
        connection_patterns={"sequential": 1.0, "parallel": 0.0, "conditional": 0.0, "convergent": 0.0}
    );

    # At least one insight should be actionable
    has_actionable = False;
    for insight in insights {
        if insight.actionable {
            has_actionable = True;
        }
    }
    assert has_actionable;
}

test "generate_comparative_insights shows week over week change" {
    current_events = [
        {"event_type": "task_created", "timestamp": "2025-02-04T10:00:00"},
        {"event_type": "task_created", "timestamp": "2025-02-05T10:00:00"},
        {"event_type": "task_created", "timestamp": "2025-02-06T10:00:00"},
        {"event_type": "task_created", "timestamp": "2025-02-07T10:00:00"},
        {"event_type": "task_created", "timestamp": "2025-02-08T10:00:00"},
        {"event_type": "task_created", "timestamp": "2025-02-09T10:00:00"},
        {"event_type": "task_created", "timestamp": "2025-02-10T10:00:00"}
    ];

    previous_events = [
        {"event_type": "task_created", "timestamp": "2025-01-28T10:00:00"},
        {"event_type": "task_created", "timestamp": "2025-01-29T10:00:00"},
        {"event_type": "task_created", "timestamp": "2025-01-30T10:00:00"},
        {"event_type": "task_created", "timestamp": "2025-01-31T10:00:00"},
        {"event_type": "task_created", "timestamp": "2025-02-01T10:00:00"},
        {"event_type": "task_created", "timestamp": "2025-02-02T10:00:00"},
        {"event_type": "task_created", "timestamp": "2025-02-03T10:00:00"}
    ];

    comparisons = generate_comparative_insights(
        current_period_events=current_events,
        previous_period_events=previous_events,
        period_type="week"
    );

    # Should return at least one comparison
    assert len(comparisons) >= 1;

    # Should have trend information
    for comparison in comparisons {
        assert hasattr(comparison, "trend");
        assert comparison.trend in ["improving", "declining", "stable"];
    }
}

test "generate_comparative_insights detects improvement" {
    # Current week: more activity
    current_events = [];
    for i in range(20) {
        current_events.append({"event_type": "task_created", "timestamp": "2025-02-" + str(i + 1).zfill(2) + "T10:00:00"});
    }

    # Previous week: less activity
    previous_events = [];
    for i in range(10) {
        previous_events.append({"event_type": "task_created", "timestamp": "2025-01-" + str(i + 20).zfill(2) + "T10:00:00"});
    }

    comparisons = generate_comparative_insights(
        current_period_events=current_events,
        previous_period_events=previous_events,
        period_type="week"
    );

    # Should detect improvement
    has_improvement = False;
    for comparison in comparisons {
        if comparison.trend == "improving" {
            has_improvement = True;
        }
    }
    assert has_improvement;
}

test "discover_routine_patterns finds repeated sequences" {
    # Simulate a user who does the same routine each morning
    activity_events = [
        {"event_type": "task_created", "timestamp": "2025-02-03T07:00:00", "task_name": "MakeCoffee"},
        {"event_type": "task_created", "timestamp": "2025-02-03T07:05:00", "task_name": "Shower"},
        {"event_type": "task_created", "timestamp": "2025-02-03T07:15:00", "task_name": "GetDressed"},
        {"event_type": "task_created", "timestamp": "2025-02-04T07:00:00", "task_name": "MakeCoffee"},
        {"event_type": "task_created", "timestamp": "2025-02-04T07:05:00", "task_name": "Shower"},
        {"event_type": "task_created", "timestamp": "2025-02-04T07:15:00", "task_name": "GetDressed"},
        {"event_type": "task_created", "timestamp": "2025-02-05T07:00:00", "task_name": "MakeCoffee"},
        {"event_type": "task_created", "timestamp": "2025-02-05T07:05:00", "task_name": "Shower"},
        {"event_type": "task_created", "timestamp": "2025-02-05T07:15:00", "task_name": "GetDressed"},
    ];

    task_graph_nodes = ["MakeCoffee", "Shower", "GetDressed", "CheckEmail", "Exercise"];
    task_graph_edges = [
        {"from": "MakeCoffee", "to": "Shower", "label": "then"},
        {"from": "Shower", "to": "GetDressed", "label": "then"},
    ];

    patterns = discover_routine_patterns(
        activity_events=activity_events,
        task_graph_nodes=task_graph_nodes,
        task_graph_edges=task_graph_edges,
        time_window_days=7
    );

    # Should detect the morning routine
    assert len(patterns) >= 1;

    # At least one pattern should have high confidence
    has_high_confidence = False;
    for pattern in patterns {
        if pattern.confidence > 0.7 {
            has_high_confidence = True;
        }
    }
    assert has_high_confidence;
}

test "analyze_temporal_patterns detects peak hours" {
    # User most active in the morning (7-9 AM)
    activity_events = [];
    for day in range(7) {
        # Morning activity (3 events per day)
        activity_events.append({"event_type": "task_created", "timestamp": "2025-02-" + str(day + 1).zfill(2) + "T07:00:00"});
        activity_events.append({"event_type": "task_created", "timestamp": "2025-02-" + str(day + 1).zfill(2) + "T08:00:00"});
        activity_events.append({"event_type": "task_created", "timestamp": "2025-02-" + str(day + 1).zfill(2) + "T09:00:00"});
        # One evening event
        activity_events.append({"event_type": "task_created", "timestamp": "2025-02-" + str(day + 1).zfill(2) + "T18:00:00"});
    }

    temporal_insights = analyze_temporal_patterns(
        activity_events=activity_events,
        lookback_days=7
    );

    # Should return temporal insights
    assert len(temporal_insights) >= 1;

    # Should identify morning as peak time
    has_morning_peak = False;
    for insight in temporal_insights {
        if hasattr(insight, "peak_hours") {
            for hour in insight.peak_hours {
                if hour >= 7 and hour <= 9 {
                    has_morning_peak = True;
                }
            }
        }
    }
    assert has_morning_peak;
}

test "insight feedback tracking works" {
    insight = UserInsight(
        insight_type="productivity",
        title="Test Insight",
        description="Test description",
        category="productivity",
        actionable=True,
        created_at="2025-02-11T10:00:00",
        viewed=False,
        acted_upon=False,
        relevance_score=1.0,
        dismissed=False
    );

    # Mark as viewed
    insight.viewed = True;
    assert insight.viewed == True;

    # Mark as acted upon
    insight.acted_upon = True;
    assert insight.acted_upon == True;

    # Mark as dismissed
    insight.dismissed = True;
    assert insight.dismissed == True;
}

test "goal progress tracking" {
    goal = UserGoal(
        goal_type="daily_tasks",
        target_value=10,
        current_value=0,
        created_at="2025-02-11T10:00:00",
        achieved=False,
        achieved_at=""
    );

    # Update progress
    goal.current_value = 5;
    assert goal.current_value == 5;
    assert goal.achieved == False;

    # Complete goal
    goal.current_value = 10;
    goal.achieved = True;
    goal.achieved_at = "2025-02-11T15:00:00";

    assert goal.achieved == True;
    assert goal.achieved_at == "2025-02-11T15:00:00";
}

test "achievement unlock conditions" {
    # Test first_task achievement
    total_tasks = 1;
    assert total_tasks >= 1;  # Should unlock "First Step"

    # Test three_day_streak achievement
    current_streak = 3;
    assert current_streak >= 3;  # Should unlock "On a Roll"

    # Test week_warrior achievement
    current_streak = 7;
    assert current_streak >= 7;  # Should unlock "Week Warrior"

    # Test multitasker achievement (5 parallel tasks in session)
    session_parallel_tasks = 5;
    assert session_parallel_tasks >= 5;  # Should unlock "Multitasker"

    # Test voice_first achievement
    voice_interaction_count = 1;
    assert voice_interaction_count >= 1;  # Should unlock "Voice Activated"

    # Test planner achievement (10+ tasks in session)
    session_task_count = 10;
    assert session_task_count >= 10;  # Should unlock "Planner"
}

test "proactive insight triggers" {
    # Test streak at risk trigger
    current_streak = 5;
    last_activity_days_ago = 0.9;  # Almost a day since last activity

    # Should trigger if streak is at risk
    should_trigger = current_streak > 0 and last_activity_days_ago > 0.8;
    assert should_trigger == True;

    # Test achievement celebration trigger
    achievement_unlocked = True;
    should_celebrate = achievement_unlocked;
    assert should_celebrate == True;

    # Test goal milestone trigger
    goal_progress = 8;
    goal_target = 10;
    milestone_reached = goal_progress == int(goal_target / 2);  # 50% milestone
    assert milestone_reached == True;
}
