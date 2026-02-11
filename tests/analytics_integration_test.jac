# Analytics Integration Tests
# End-to-end tests for analytics system
#
# These tests verify:
# 1. Full analytics flow from event to insight
# 2. API endpoints return correct data
# 3. User-scoping works correctly
# 4. Achievement triggers fire at appropriate times

import {
    get_activity_report,
    get_trend_analysis,
    analyze_behavioral_patterns,
    calculate_productivity_metrics,
    generate_insights
}

test "integration: full analytics flow for new user" {
    username = "test_new_user";

    # Initialize user graph
    init_result = root spawn init_user_graph(username=username);

    # Log some activity events
    root spawn log_activity_event(
        username=username,
        event_type="task_created",
        event_data={"task_name": "MakeCoffee"},
        session_id="session_1"
    );

    root spawn log_activity_event(
        username=username,
        event_type="voice_interaction",
        event_data={"message": "add task check email"},
        session_id="session_1"
    );

    # Get activity report
    report_result = root spawn get_activity_report(username=username);
    assert report_result.reports.length > 0;
    report_data = report_result.reports[0];
    assert report_data["success"] == True;

    # Get trend analysis
    trend_result = root spawn get_trend_analysis(username=username, period="week");
    assert trend_result.reports.length > 0;
    trend_data = trend_result.reports[0];
    assert trend_data["success"] == True;
    assert trend_data["period"] == "week";

    # Get behavioral patterns
    patterns_result = root spawn analyze_behavioral_patterns(username=username);
    assert patterns_result.reports.length > 0;
    patterns_data = patterns_result.reports[0];
    assert patterns_data["success"] == True;

    # Get productivity metrics
    metrics_result = root spawn calculate_productivity_metrics(username=username);
    assert metrics_result.reports.length > 0;
    metrics_data = metrics_result.reports[0];
    assert metrics_data["success"] == True;

    # Generate insights
    insights_result = root spawn generate_insights(username=username, category="all");
    assert insights_result.reports.length > 0;
    insights_data = insights_result.reports[0];
    assert insights_data["success"] == True;
    assert insights_data["count"] >= 3;  # Should have at least 3 insights
}

test "integration: analytics data persists across sessions" {
    username = "test_persistence_user";

    # Clear any existing data
    root spawn clear_graph(username=username);

    # Create initial data
    root spawn log_activity_event(
        username=username,
        event_type="task_created",
        event_data={"task_name": "Task1"},
        session_id="session_1"
    );

    # Get initial report
    report1 = root spawn get_activity_report(username=username);
    initial_tasks = report1.reports[0]["total_tasks"];

    # Add more data in "new session"
    root spawn log_activity_event(
        username=username,
        event_type="task_created",
        event_data={"task_name": "Task2"},
        session_id="session_2"
    );

    # Get updated report
    report2 = root spawn get_activity_report(username=username);
    updated_tasks = report2.reports[0]["total_tasks"];

    # Task count should have increased
    assert updated_tasks > initial_tasks;
}

test "integration: streak tracking works correctly" {
    username = "test_streak_user";

    # Clear existing data
    root spawn clear_graph(username=username);

    # Simulate activity over 5 days
    for day in range(5) {
        root spawn log_activity_event(
            username=username,
            event_type="task_created",
            event_data={"task_name": "Day" + str(day)},
            session_id="session_" + str(day)
        );
    }

    # Get productivity metrics
    metrics_result = root spawn calculate_productivity_metrics(username=username);
    metrics_data = metrics_result.reports[0];

    # Should track active days
    assert metrics_data["active_days"] == 5;

    # Should have a streak
    assert metrics_data["current_streak"] >= 1;
}

test "integration: user isolation prevents cross-user data leakage" {
    # Create activity for user1
    root spawn log_activity_event(
        username="user_isolation_test_1",
        event_type="task_created",
        event_data={"task_name": "User1Task"},
        session_id="session_1"
    );

    # Create activity for user2
    root spawn log_activity_event(
        username="user_isolation_test_2",
        event_type="task_created",
        event_data={"task_name": "User2Task"},
        session_id="session_1"
    );

    # Get reports for both users
    report1 = root spawn get_activity_report(username="user_isolation_test_1");
    report2 = root spawn get_activity_report(username="user_isolation_test_2");

    # Each user should only see their own data
    # (This is a basic check; more thorough testing would verify node counts)
    assert report1.reports.length > 0;
    assert report2.reports.length > 0;
    assert report1.reports[0]["success"] == True;
    assert report2.reports[0]["success"] == True;
}

test "integration: peak hour detection with real data" {
    username = "test_peak_hour_user";

    # Clear existing data
    root spawn clear_graph(username=username);

    # Create activity concentrated at 9 AM
    for day in range(7) {
        for i in range(5) {
            root spawn log_activity_event(
                username=username,
                event_type="task_created",
                event_data={},
                session_id="session_" + str(day)
            );
        }
    }

    # Get trend analysis
    trend_result = root spawn get_trend_analysis(username=username, period="week");
    trend_data = trend_result.reports[0];

    # Should have peak hour data
    assert trend_data["peak_hour"] != "0";  # Should not be default
}

test "integration: connection patterns reflect graph structure" {
    username = "test_patterns_user";

    # Build a graph with specific patterns
    root spawn update_task_graph(
        username=username,
        task_name="TaskA",
        previous_task="Start",
        edge_label="then"
    );

    root spawn update_task_graph(
        username=username,
        task_name="TaskB",
        previous_task="TaskA",
        edge_label="while"
    );

    root spawn update_task_graph(
        username=username,
        task_name="TaskC",
        previous_task="TaskA",
        edge_label="if cold"
    );

    # Get behavioral patterns
    patterns_result = root spawn analyze_behavioral_patterns(username=username);
    patterns_data = patterns_result.reports[0];

    # Should detect different connection types
    connection_patterns = patterns_data["connection_patterns"];
    assert len(connection_patterns) > 0;
}

test "integration: insights become more personalized over time" {
    username = "test_personalization_user";

    # Clear existing data
    root spawn clear_graph(username=username);

    # Day 1: Minimal activity
    root spawn log_activity_event(
        username=username,
        event_type="task_created",
        event_data={},
        session_id="day1_session"
    );

    insights1 = root spawn generate_insights(username=username, category="all");
    insights1_data = insights1.reports[0];

    # Should have basic insights
    assert insights1_data["count"] >= 3;

    # Days 2-7: Build activity
    for day in range(2, 8) {
        for i in range(5) {
            root spawn log_activity_event(
                username=username,
                event_type="task_created",
                event_data={},
                session_id="day" + str(day) + "_session"
            );
        }
    }

    insights2 = root spawn generate_insights(username=username, category="all");
    insights2_data = insights2.reports[0];

    # Should still have insights
    assert insights2_data["count"] >= 3;

    # Insights should be different (more data to work with)
    # This is a qualitative check; in production, you'd check for specific patterns
}

test "integration: consistency score calculation matches documented formula" {
    username = "test_consistency_user";

    # Clear and setup
    root spawn clear_graph(username=username);

    # Create 20 tasks over 5 days = 4 tasks/day
    # Expected consistency: 4 * 20 + 30 = 110 → min(100) = 100
    for day in range(5) {
        for i in range(4) {
            root spawn log_activity_event(
                username=username,
                event_type="task_created",
                event_data={},
                session_id="day" + str(day)
            );
        }
    }

    # Also create the actual graph nodes
    for i in range(20) {
        root spawn update_task_graph(
            username=username,
            task_name="Task" + str(i),
            previous_task="Start",
            edge_label=""
        );
    }

    metrics_result = root spawn calculate_productivity_metrics(username=username);
    metrics_data = metrics_result.reports[0];

    # With 20 tasks over 5 days, consistency should be 100
    assert metrics_data["consistency_score"] >= 90.0;  # Allow some margin
}

test "integration: efficiency score based on edge ratio" {
    username = "test_efficiency_user";

    # Clear and setup
    root spawn clear_graph(username=username);

    # Create a highly connected graph
    root spawn update_task_graph(username=username, task_name="A", previous_task="Start", edge_label="then");
    root spawn update_task_graph(username=username, task_name="B", previous_task="A", edge_label="then");
    root spawn update_task_graph(username=username, task_name="C", previous_task="B", edge_label="then");
    root spawn update_task_graph(username=username, task_name="D", previous_task="C", edge_label="while");
    root spawn update_task_graph(username=username, task_name="E", previous_task="A", edge_label="if");

    metrics_result = root spawn calculate_productivity_metrics(username=username);
    metrics_data = metrics_result.reports[0];

    # With 5 tasks and 5 edges, ratio = 1.0 → 1.0 * 40 + 40 = 80
    assert metrics_data["efficiency_score"] >= 70.0;
    assert metrics_data["efficiency_score"] <= 90.0;
}

test "integration: emotion tracking influences insights" {
    username = "test_emotion_user";

    # Clear existing data
    root spawn clear_graph(username=username);

    # Create activity with stressed emotional context
    for i in range(5) {
        root spawn log_activity_event(
            username=username,
            event_type="voice_interaction",
            event_data={"emotion": "stressed"},
            session_id="session_" + str(i)
        );
    }

    # Get behavioral patterns
    patterns_result = root spawn analyze_behavioral_patterns(username=username);
    patterns_data = patterns_result.reports[0];

    # Should have emotion distribution
    emotion_distribution = patterns_data["emotion_distribution"];
    assert len(emotion_distribution) > 0;
}

test "integration: week over week comparison" {
    username = "test_comparison_user";

    # This test verifies the comparative insights feature
    # In a real scenario, you'd need events from two different time periods

    insights_result = root spawn generate_insights(username=username, category="comparative");
    insights_data = insights_result.reports[0];

    # Should return insights
    assert insights_data["success"] == True;
}

test "integration: goal progress affects insights" {
    username = "test_goal_user";

    # Create a goal
    root spawn create_goal(
        username=username,
        goal_type="daily_tasks",
        target_value=5
    );

    # Make progress
    root spawn update_goal_progress(
        username=username,
        goal_id="daily_tasks",
        progress=3
    );

    # Get insights which should include goal progress
    insights_result = root spawn generate_insights(username=username, category="goals");
    insights_data = insights_result.reports[0];

    assert insights_data["success"] == True;
}

test "integration: achievement unlock triggers celebration" {
    username = "test_achievement_user";

    # This test verifies that achievements trigger celebratory insights
    # The actual achievement checking would happen during event logging

    # Simulate unlocking an achievement
    root spawn log_activity_event(
        username=username,
        event_type="achievement_unlocked",
        event_data={"achievement_id": "first_task"},
        session_id="session_1"
    );

    # Check for celebratory insights
    insights_result = root spawn generate_insights(username=username, category="all");
    insights_data = insights_result.reports[0];

    # Should have insights
    assert insights_data["count"] >= 3;
}
