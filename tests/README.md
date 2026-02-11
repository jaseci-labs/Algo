# Analytics Tests

This directory contains tests for the Algo analytics and insights system.

## Test Files

### `analytics_utils_test.jac`
Tests for shared analytics utility functions:
- `get_connection_patterns()` - Edge type extraction
- `get_connection_patterns_percentages()` - Percentage conversion
- `calculate_productivity_scores()` - Score calculations
- `parse_timestamp_parts()` - Timestamp parsing

### `analytics_performance_test.jac`
Performance and scalability tests:
- Large dataset handling (1000+ events)
- Response time benchmarks
- Memory usage bounds
- Insight relevance decay
- Event batch aggregation

### `analytics_insights_test.jac`
Insight generation tests:
- Personalized insights generation
- Comparative insights (week-over-week)
- Routine pattern discovery
- Temporal pattern analysis
- Goal progress tracking
- Achievement unlock conditions

### `analytics_integration_test.jac`
End-to-end integration tests:
- Full analytics flow for new users
- Data persistence across sessions
- Streak tracking
- User isolation (no cross-user data leakage)
- Peak hour detection
- Connection pattern analysis
- Insight personalization over time

## Running Tests

```bash
# Run all tests
jac test tests/

# Run specific test file
jac test tests/analytics_utils_test.jac

# Run with verbose output
jac test tests/ --verbose
```

## Performance Benchmarks

The following performance expectations are tested:

| Operation | Dataset Size | Max Response Time |
|-----------|--------------|-------------------|
| `get_connection_patterns` | 1000 edges | 100ms |
| `analyze_activity_events` | 1000 events | 200ms |
| `calculate_productivity_scores` | 100 iterations | 1ms avg |
| Full analytics request | 100 events | 50ms |

## Test Coverage

- **Unit Tests**: Individual function behavior
- **Performance Tests**: Scalability and response times
- **Integration Tests**: End-to-end user flows
- **Edge Cases**: Empty data, invalid formats, boundary values

## Adding New Tests

When adding new analytics features, include:

1. **Unit test** for the core function
2. **Performance test** if it processes large datasets
3. **Integration test** for the full user flow
4. **Edge case tests** for boundary conditions

Example test structure:
```jac
test "descriptive test name" {
    # Setup
    input_data = ...;

    # Execute
    result = function_to_test(input_data);

    # Assert
    assert result["expected_key"] == expected_value;
}
```
