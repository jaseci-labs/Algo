# Analytics Utility Functions Tests
# Tests for shared analytics utility functions in mainAppService.impl.jac
#
# Run with: jac test tests/analytics_utils_test.jac

test "get_connection_patterns counts sequential edges" {
    edges = [
        {"from": "A", "to": "B", "label": "then"},
        {"from": "B", "to": "C", "label": "after"},
        {"from": "C", "to": "D", "label": "next"}
    ];

    result = get_connection_patterns(edges);

    assert result["sequential"] == 3;
    assert result["parallel"] == 0;
    assert result["conditional"] == 0;
    assert result["convergent"] == 0;
}

test "get_connection_patterns counts parallel edges" {
    edges = [
        {"from": "A", "to": "B", "label": "while"},
        {"from": "A", "to": "C", "label": "as"},
        {"from": "A", "to": "D", "label": "same time"}
    ];

    result = get_connection_patterns(edges);

    assert result["parallel"] == 3;
    assert result["sequential"] == 0;
    assert result["conditional"] == 0;
    assert result["convergent"] == 0;
}

test "get_connection_patterns counts conditional edges" {
    edges = [
        {"from": "A", "to": "B", "label": "if raining"},
        {"from": "A", "to": "C", "label": "otherwise"},
        {"from": "A", "to": "D", "label": "when tired"}
    ];

    result = get_connection_patterns(edges);

    assert result["conditional"] == 3;
    assert result["sequential"] == 0;
    assert result["parallel"] == 0;
    assert result["convergent"] == 0;
}

test "get_connection_patterns counts convergent edges" {
    edges = [
        {"from": "A", "to": "B", "label": "either way"},
        {"from": "C", "to": "D", "label": "merge"},
        {"from": "E", "to": "F", "label": "converge"}
    ];

    result = get_connection_patterns(edges);

    assert result["convergent"] == 3;
    assert result["sequential"] == 0;
    assert result["parallel"] == 0;
    assert result["conditional"] == 0;
}

test "get_connection_patterns defaults unknown labels to sequential" {
    edges = [
        {"from": "A", "to": "B", "label": "weird"},
        {"from": "B", "to": "C", "label": "unknown"},
        {"from": "C", "to": "D", "label": ""}
    ];

    result = get_connection_patterns(edges);

    assert result["sequential"] == 3;
}

test "get_connection_patterns handles mixed edge types" {
    edges = [
        {"from": "A", "to": "B", "label": "then"},
        {"from": "A", "to": "C", "label": "while"},
        {"from": "B", "to": "D", "label": "if cold"},
        {"from": "C", "to": "D", "label": "either way"}
    ];

    result = get_connection_patterns(edges);

    assert result["sequential"] == 1;
    assert result["parallel"] == 1;
    assert result["conditional"] == 1;
    assert result["convergent"] == 1;
}

test "get_connection_patterns handles empty edge list" {
    edges = [];

    result = get_connection_patterns(edges);

    assert result["sequential"] == 0;
    assert result["parallel"] == 0;
    assert result["conditional"] == 0;
    assert result["convergent"] == 0;
}

test "get_connection_patterns_percentages calculates correctly" {
    patterns = {"sequential": 5, "parallel": 3, "conditional": 2, "convergent": 0};

    result = get_connection_patterns_percentages(patterns);

    assert result["sequential"] == 0.5;  # 5/10
    assert result["parallel"] == 0.3;    # 3/10
    assert result["conditional"] == 0.2; # 2/10
    assert result["convergent"] == 0.0;  # 0/10
}

test "get_connection_patterns_percentages handles single type" {
    patterns = {"sequential": 10, "parallel": 0, "conditional": 0, "convergent": 0};

    result = get_connection_patterns_percentages(patterns);

    assert result["sequential"] == 1.0;
    assert result["parallel"] == 0.0;
    assert result["conditional"] == 0.0;
    assert result["convergent"] == 0.0;
}

test "get_connection_patterns_percentages returns default for empty patterns" {
    patterns = {"sequential": 0, "parallel": 0, "conditional": 0, "convergent": 0};

    result = get_connection_patterns_percentages(patterns);

    assert result["sequential"] == 1.0;  # Default
    assert result["parallel"] == 0.0;
    assert result["conditional"] == 0.0;
    assert result["convergent"] == 0.0;
}

test "calculate_productivity_scores with normal activity" {
    result = calculate_productivity_scores(
        total_tasks=20,
        total_edges=15,
        active_days=5
    );

    # Consistency: 20 tasks / 5 days = 4 per day → 4 * 20 + 30 = 110 → min(100) = 100
    assert result["consistency_score"] == 100.0;

    # Efficiency: 15 edges / 20 tasks = 0.75 → 0.75 * 40 + 40 = 70
    assert result["efficiency_score"] == 70.0;

    # Streak: max(1, 5) = 5
    assert result["current_streak"] == 5;
}

test "calculate_productivity_scores with low activity" {
    result = calculate_productivity_scores(
        total_tasks=3,
        total_edges=2,
        active_days=3
    );

    # Consistency: 3 tasks / 3 days = 1 per day → 1 * 20 + 30 = 50
    assert result["consistency_score"] == 50.0;

    # Efficiency: 2 edges / 3 tasks = 0.667 → 0.667 * 40 + 40 = 66.68
    expected_efficiency = (2.0 / 3.0) * 40.0 + 40.0;
    assert result["efficiency_score"] == expected_efficiency;
}

test "calculate_productivity_scores with no tasks" {
    result = calculate_productivity_scores(
        total_tasks=0,
        total_edges=0,
        active_days=0
    );

    # Default scores when no activity
    assert result["consistency_score"] == 50.0;
    assert result["efficiency_score"] == 50.0;
    assert result["current_streak"] == 1;  # max(1, 0) = 1
}

test "calculate_productivity_scores caps at 100" {
    result = calculate_productivity_scores(
        total_tasks=100,
        total_edges=200,
        active_days=1
    );

    # Consistency: 100 tasks / 1 day = 100 → 100 * 20 + 30 = 2030 → min(100) = 100
    assert result["consistency_score"] == 100.0;

    # Efficiency: 200 edges / 100 tasks = 2 → 2 * 40 + 40 = 120 → min(100) = 100
    assert result["efficiency_score"] == 100.0;
}

test "parse_timestamp_parts extracts hour and day" {
    result = parse_timestamp_parts("2025-02-11T09:30:00");

    assert result["hour"] == "09";
    assert result["day"] == "Tuesday";
}

test "parse_timestamp_parts handles midnight" {
    result = parse_timestamp_parts("2025-02-11T00:00:00");

    assert result["hour"] == "00";
    assert result["day"] == "Tuesday";
}

test "parse_timestamp_parts handles single digit hour" {
    result = parse_timestamp_parts("2025-02-11T9:30:00");

    assert result["hour"] == "9";
}

test "parse_timestamp_parts defaults for invalid format" {
    result = parse_timestamp_parts("invalid");

    assert result["hour"] == "0";
    assert result["day"] == "Monday";
}

test "parse_timestamp_parts handles date only" {
    result = parse_timestamp_parts("2025-02-11");

    assert result["hour"] == "0";
    assert result["day"] == "Tuesday";
}
