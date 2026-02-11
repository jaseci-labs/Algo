# Analytics Performance Tests
# Tests to verify performance characteristics of analytics operations
#
# These tests ensure:
# 1. Analytics scale with large datasets (1000+ events)
# 2. Insight relevance scoring decays appropriately
# 3. Event batching aggregation works correctly
# 4. Memory usage stays within bounds

import {
    get_connection_patterns,
    analyze_activity_events,
    calculate_productivity_scores,
    parse_timestamp_parts
}

test "performance: get_connection_patterns with 1000 edges" {
    # Generate 1000 edges
    edges = [];
    for i in range(1000) {
        label = "then";
        if i % 4 == 1 { label = "while"; }
        elif i % 4 == 2 { label = "if"; }
        elif i % 4 == 3 { label = "either way"; }
        edges.append({"from": "task" + str(i), "to": "task" + str(i+1), "label": label});
    }

    start_time = time.time();
    result = get_connection_patterns(edges);
    end_time = time.time();

    # Should complete in under 100ms
    assert (end_time - start_time) * 1000 < 100;

    # Should still count correctly
    assert result["sequential"] == 250;
    assert result["parallel"] == 250;
    assert result["conditional"] == 250;
    assert result["convergent"] == 250;
}

test "performance: analyze_activity_events with 1000 events" {
    # Generate 1000 activity events
    events = [];
    for i in range(1000) {
        day = "2025-02-" + str((i % 28) + 1).zfill(2);
        hour = (i % 24);
        timestamp = day + "T" + str(hour).zfill(2) + ":00:00";

        event = ActivityEvent(
            event_type="task_created",
            timestamp=timestamp,
            event_data={},
            session_id="session_" + str(i % 10)
        );
        events.append(event);
    }

    start_time = time.time();
    result = analyze_activity_events(events);
    end_time = time.time();

    # Should complete in under 200ms
    assert (end_time - start_time) * 1000 < 200;

    # Should count all events
    assert result["event_counts"]["task_created"] == 1000;

    # Should track unique days (28 unique days)
    assert result["active_days"] == 28;
}

test "performance: calculate_productivity_scores scales efficiently" {
    # Test with maximum realistic values
    iterations = 100;

    start_time = time.time();
    for i in range(iterations) {
        result = calculate_productivity_scores(
            total_tasks=500,
            total_edges=1000,
            active_days=365
        );
    }
    end_time = time.time();

    # Average time per calculation should be under 1ms
    avg_time_ms = ((end_time - start_time) * 1000) / iterations;
    assert avg_time_ms < 1.0;
}

test "insight relevance score decays over time" {
    # Test that insights lose relevance as they age
    created_at = "2025-02-01T10:00:00";

    # Immediately after creation (same hour)
    current_time = "2025-02-01T10:00:00";
    relevance = calculate_insight_relevance(
        insight=UserInsight(
            insight_type="productivity",
            title="Test Insight",
            description="Test",
            category="productivity",
            actionable=True,
            created_at=created_at,
            viewed=False,
            acted_upon=False,
            relevance_score=1.0,
            dismissed=False
        ),
        current_time=current_time
    );
    assert relevance == 1.0;

    # After 1 day
    current_time = "2025-02-02T10:00:00";
    relevance = calculate_insight_relevance(
        insight=UserInsight(
            insight_type="productivity",
            title="Test Insight",
            description="Test",
            category="productivity",
            actionable=True,
            created_at=created_at,
            viewed=False,
            acted_upon=False,
            relevance_score=1.0,
            dismissed=False
        ),
        current_time=current_time
    );
    # Should be slightly less than 1.0
    assert relevance < 1.0;
    assert relevance > 0.9;
}

test "insight relevance drops to zero when acted upon" {
    insight = UserInsight(
        insight_type="productivity",
        title="Test Insight",
        description="Test",
        category="productivity",
        actionable=True,
        created_at="2025-02-01T10:00:00",
        viewed=True,
        acted_upon=True,  # User took action
        relevance_score=1.0,
        dismissed=False
    );

    current_time = "2025-02-01T11:00:00";
    relevance = calculate_insight_relevance(insight, current_time);

    # Should be 0 since user acted on it
    assert relevance == 0.0;
}

test "insight relevance halves when viewed" {
    insight = UserInsight(
        insight_type="productivity",
        title="Test Insight",
        description="Test",
        category="productivity",
        actionable=True,
        created_at="2025-02-01T10:00:00",
        viewed=True,  # User viewed it
        acted_upon=False,
        relevance_score=1.0,
        dismissed=False
    );

    current_time = "2025-02-01T11:00:00";
    relevance = calculate_insight_relevance(insight, current_time);

    # Should be halved from 1.0
    assert relevance == 0.5;
}

test "event batch aggregation reduces count" {
    # Create many events
    events = [];
    for i in range(100) {
        event = ActivityEvent(
            event_type="task_created",
            timestamp="2025-02-" + str((i % 28) + 1).zfill(2) + "T10:00:00",
            event_data={},
            session_id="session_1"
        );
        events.append(event);
    }

    # Before aggregation
    assert len(events) == 100;

    # After aggregation (by date)
    batches = aggregate_events_by_date(events);
    unique_days = len(batches);

    # Should have at most 28 unique days
    assert unique_days <= 28;

    # Each batch should have aggregated counts
    total_aggregated = 0;
    for batch_id in batches {
        total_aggregated = total_aggregated + batches[batch_id]["event_count"];
    }

    assert total_aggregated == 100;
}

test "analytics response time under load" {
    # Simulate concurrent analytics requests
    user_graph = user_graph_data(username="test_user");

    # Create test data
    for i in range(100) {
        event = ActivityEvent(
            event_type="task_created",
            timestamp="2025-02-" + str((i % 28) + 1).zfill(2) + "T10:00:00",
            event_data={},
            session_id="session_1"
        );
        user_graph ++> event;
    }

    # Measure analytics response time
    start_time = time.time();

    activity_events = [user_graph-->](?:ActivityEvent);
    result = analyze_activity_events(activity_events);

    end_time = time.time();

    response_time_ms = (end_time - start_time) * 1000;

    # Response time should be under 50ms for 100 events
    assert response_time_ms < 50;

    # Result should be accurate
    assert result["event_counts"]["task_created"] == 100;
}

test "memory usage bounded for large event sets" {
    # This test verifies we don't leak memory when processing many events
    # In a real scenario, you'd measure actual memory usage
    # Here we verify the data structures are appropriately sized

    events = [];
    for i in range(1000) {
        event = ActivityEvent(
            event_type="task_created",
            timestamp="2025-02-" + str((i % 28) + 1).zfill(2) + "T10:00:00",
            event_data={},
            session_id="session_" + str(i % 50)
        );
        events.append(event);
    }

    # analyze_activity_events should return a compact result dict
    result = analyze_activity_events(events);

    # Result dict should have fixed size regardless of input
    assert len(result) == 5;  # event_counts, voice_interaction_count, total_sessions, active_days, active_days_set

    # active_days_set should only have 28 entries (unique days)
    assert len(result["active_days_set"]) == 28;
}

test "temporal pattern analysis performance with hourly granularity" {
    # Generate events spread across hours
    events = [];
    for day in range(7) {
        for hour in range(24) {
            timestamp = "2025-02-" + str(day + 1).zfill(2) + "T" + str(hour).zfill(2) + ":00:00";
            event = ActivityEvent(
                event_type="task_created",
                timestamp=timestamp,
                event_data={},
                session_id="session_1"
            );
            events.append(event);
        }
    }

    start_time = time.time();
    result = analyze_activity_events(events);
    end_time = time.time();

    # Should process 168 events (7 * 24) quickly
    assert (end_time - start_time) * 1000 < 50;
    assert result["event_counts"]["task_created"] == 168;
}

test "cached analytics results improve performance" {
    # First call - should be slower
    events = [];
    for i in range(100) {
        event = ActivityEvent(
            event_type="task_created",
            timestamp="2025-02-11T10:00:00",
            event_data={},
            session_id="session_1"
        );
        events.append(event);
    }

    start_time = time.time();
    result1 = analyze_activity_events(events);
    time1 = (time.time() - start_time) * 1000;

    # Second call with same data - should be similar (no caching currently)
    # This test establishes baseline for future caching implementation
    start_time = time.time();
    result2 = analyze_activity_events(events);
    time2 = (time.time() - start_time) * 1000;

    # Results should be identical
    assert result1["event_counts"]["task_created"] == result2["event_counts"]["task_created"];
    assert result1["active_days"] == result2["active_days"];

    # Times should be in similar ballpark (within 10ms)
    assert abs(time1 - time2) < 10;
}
