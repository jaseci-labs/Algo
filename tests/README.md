# Algo Integration Tests

Full-stack integration tests for the Algo application. These tests start the Jac server and make HTTP requests to verify all major functionality.

## Running Tests Locally

### Prerequisites

1. Install dependencies:
```bash
pip install -r tests/integration/requirements.txt
```

2. Set up environment:
```bash
export OPENAI_API_KEY="your-key-here"  # Optional - only needed for session token tests
```

### Run Tests

Start the Jac server in one terminal:
```bash
jac start main.jac
```

Run tests in another terminal:
```bash
python tests/integration/run_tests.py
```

For CI mode (no colored output):
```bash
TEST_MODE=ci python tests/integration/run_tests.py
```

## CI/CD Integration

Tests run automatically on:
- Every pull request to `main`
- Every push to `main`
- Manual trigger via `workflow_dispatch`

See [`.github/workflows/integration-test.yml`](../.github/workflows/integration-test.yml)

## Test Coverage

### Graph Operations
- `init_user_graph` - Initialize a new user graph
- `get_task_graph` - Fetch graph structure (supports empty and populated graphs)
- `update_task_graph` - Add tasks to graph with connections
- `rename_task` - Rename existing tasks
- `clear_graph` - Clear all tasks
- `reset_session` - Reset user session
- `rebuild_graph` - Rebuild graph with new structure

### Routine Management
- `save_routine` - Save current routine
- `load_past_routines` - Load saved routines

### Analytics
- `get_activity_report` - User activity summary
- `calculate_productivity_metrics` - Productivity scores
- `get_goals` - Fetch user goals
- `create_goal` - Create new goal
- `log_activity_event` - Track activity events

### Session
- `get_session_token` - OpenAI Realtime API token (skipped if `OPENAI_API_KEY` not set)


## Adding New Tests

1. Add a new test function in `tests/integration/run_tests.py`:
```python
def test_my_new_feature(results: IntegrationTestResult):
    response = call_walker("my_walker", {"param": "value"})
    if response.get("success"):
        results.add_pass("My New Feature")
    else:
        results.add_fail("My New Feature", response.get("error"))
```

2. Call the test in `run_all_tests()`:
```python
def run_all_tests():
    # ...
    test_my_new_feature(results)
```

## Test Isolation

Each test run uses a unique username (`test_user_{timestamp}`) to avoid conflicts between test runs.

## Response Format

The test script automatically extracts reports from the Jac API response format:
```json
{
  "ok": true,
  "data": {
    "reports": [...]
  }
}
```

Tests receive the `reports` array directly for easier assertions.
