#!/usr/bin/env python3
"""
Integration Tests for Algo

This test suite runs full-stack integration tests by:
1. Starting the Jac server
2. Making HTTP requests to the walker endpoints
3. Validating responses

Usage:
    python tests/integration/run_tests.py

Environment Variables:
    JAC_SERVER_URL - Base URL of the Jac server (default: http://localhost:8000)
    TEST_MODE - Set to 'ci' for CI mode (default: local)
"""

import os
import sys
import time
import json
import requests
from typing import Dict, Any, List, Optional
from datetime import datetime

# Configuration
BASE_URL = os.getenv("JAC_SERVER_URL", "http://localhost:8000")
TEST_MODE = os.getenv("TEST_MODE", "local")

# Test username - use a unique name per test run to avoid conflicts
TEST_USERNAME = f"test_user_{int(datetime.now().timestamp())}"

# Color codes for output
class Colors:
    GREEN = "\033[92m" if TEST_MODE == "local" else ""
    RED = "\033[91m" if TEST_MODE == "local" else ""
    YELLOW = "\033[93m" if TEST_MODE == "local" else ""
    BLUE = "\033[94m" if TEST_MODE == "local" else ""
    ENDC = "\033[0m" if TEST_MODE == "local" else ""


class IntegrationTestResult:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.errors: List[str] = []

    def add_pass(self, test_name: str):
        self.passed += 1
        print(f"{Colors.GREEN}✓ PASS{Colors.ENDC}: {test_name}")

    def add_fail(self, test_name: str, reason: str):
        self.failed += 1
        self.errors.append(f"{test_name}: {reason}")
        print(f"{Colors.RED}✗ FAIL{Colors.ENDC}: {test_name}")
        print(f"  {Colors.YELLOW}Reason:{Colors.ENDC} {reason}")

    def print_summary(self):
        total = self.passed + self.failed
        print("\n" + "=" * 60)
        print(f"Test Summary: {self.passed}/{total} passed")
        if self.failed > 0:
            print(f"{Colors.RED}Failed tests:{Colors.ENDC}")
            for error in self.errors:
                print(f"  - {error}")
        print("=" * 60)
        return self.failed == 0


def call_walker(walker_name: str, data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Call a Jac walker via HTTP POST.

    Args:
        walker_name: Name of the walker to call
        data: Parameters to pass to the walker

    Returns:
        JSON response from the walker - extracts reports from Jac response format
    """
    url = f"{BASE_URL}/walker/{walker_name}"
    headers = {"Content-Type": "application/json"}

    try:
        response = requests.post(url, json=data, headers=headers, timeout=30)
        response.raise_for_status()
        json_data = response.json()

        # Jac API returns: {"ok": true, "data": {"reports": [...]}}
        # Extract the reports array for backward compatibility with tests
        if json_data.get("ok") and "data" in json_data:
            data = json_data["data"]
            if "reports" in data:
                reports = data["reports"]
                # Return reports directly (as a list or dict)
                return reports if reports else {}

        # Return the response as-is if format is unexpected
        return json_data

    except requests.exceptions.RequestException as e:
        return {"error": str(e)}


def wait_for_server(timeout: int = 60) -> bool:
    """Wait for the Jac server to be ready."""
    print(f"{Colors.BLUE}Waiting for server at {BASE_URL}...{Colors.ENDC}")

    for i in range(timeout):
        try:
            response = requests.get(f"{BASE_URL}/", timeout=2)
            if response.status_code == 200:
                print(f"{Colors.GREEN}Server is ready!{Colors.ENDC}")
                return True
        except requests.exceptions.RequestException:
            pass
        time.sleep(1)

    print(f"{Colors.RED}Server did not start within {timeout} seconds{Colors.ENDC}")
    return False


def test_server_health(results: IntegrationTestResult) -> bool:
    """Test that the server is running."""
    try:
        response = requests.get(f"{BASE_URL}/", timeout=5)
        if response.status_code == 200:
            results.add_pass("Server Health Check")
            return True
        results.add_fail("Server Health Check", f"Status code: {response.status_code}")
        return False
    except Exception as e:
        results.add_fail("Server Health Check", str(e))
        return False


def test_init_user_graph(results: IntegrationTestResult):
    """Test initializing a user graph."""
    response = call_walker("init_user_graph", {})

    if "error" in response:
        results.add_fail("Init User Graph", response.get("error"))
        return

    # Should get a report with graph data
    if isinstance(response, list) and len(response) > 0:
        results.add_pass("Init User Graph")
    elif isinstance(response, dict) and ("report" in response or "success" in response):
        results.add_pass("Init User Graph")
    else:
        results.add_fail("Init User Graph", f"Unexpected response format: {response}")


def test_get_task_graph_empty(results: IntegrationTestResult):
    """Test getting an empty task graph (for a user who hasn't initialized yet)."""
    response = call_walker("get_task_graph", {"username": TEST_USERNAME})

    if "error" in response:
        results.add_fail("Get Empty Task Graph", response.get("error"))
        return

    # Fresh users will have empty nodes until they add tasks
    # The graph initializes with lastTask="Start" but no nodes yet
    if isinstance(response, list) and len(response) > 0:
        data = response[0]
        nodes = data.get("nodes", [])
        last_task = data.get("lastTask", "")
        # Accept either empty nodes (fresh user) or Start node (initialized)
        if len(nodes) == 0 or "Start" in nodes:
            results.add_pass("Get Empty Task Graph")
        else:
            results.add_fail("Get Empty Task Graph", f"Unexpected nodes: {nodes}")
    elif isinstance(response, dict):
        nodes = response.get("nodes", [])
        last_task = response.get("lastTask", "")
        if len(nodes) == 0 or "Start" in nodes:
            results.add_pass("Get Empty Task Graph")
        else:
            results.add_fail("Get Empty Task Graph", f"Unexpected nodes: {nodes}")
    else:
        results.add_fail("Get Empty Task Graph", f"Unexpected response: {response}")


def test_update_task_graph(results: IntegrationTestResult):
    """Test adding a task to the graph."""
    response = call_walker("update_task_graph", {
        "task_name": "MakeCoffee",
        "previous_task": "Start",
        "edge_label": "then",
        "username": TEST_USERNAME
    })

    if "error" in response:
        results.add_fail("Update Task Graph", response.get("error"))
        return

    if isinstance(response, list) and len(response) > 0:
        data = response[0]
        if data.get("success") or "nodes" in data:
            results.add_pass("Update Task Graph")
        else:
            results.add_fail("Update Task Graph", f"Expected success, got: {data}")
    elif isinstance(response, dict):
        if response.get("success") or "nodes" in response:
            results.add_pass("Update Task Graph")
        else:
            results.add_fail("Update Task Graph", f"Expected success, got: {response}")
    else:
        results.add_fail("Update Task Graph", f"Unexpected response: {response}")


def test_get_task_graph_with_tasks(results: IntegrationTestResult):
    """Test getting task graph after adding tasks."""
    response = call_walker("get_task_graph", {"username": TEST_USERNAME})

    if "error" in response:
        results.add_fail("Get Task Graph With Tasks", response.get("error"))
        return

    if isinstance(response, list) and len(response) > 0:
        data = response[0]
        nodes = data.get("nodes", [])
        if "MakeCoffee" in nodes:
            results.add_pass("Get Task Graph With Tasks")
        else:
            results.add_fail("Get Task Graph With Tasks", f"MakeCoffee not in nodes: {nodes}")
    elif isinstance(response, dict):
        nodes = response.get("nodes", [])
        if "MakeCoffee" in nodes:
            results.add_pass("Get Task Graph With Tasks")
        else:
            results.add_fail("Get Task Graph With Tasks", f"MakeCoffee not in nodes: {nodes}")
    else:
        results.add_fail("Get Task Graph With Tasks", f"Unexpected response: {response}")


def test_rename_task(results: IntegrationTestResult):
    """Test renaming a task."""
    response = call_walker("rename_task", {
        "old_name": "MakeCoffee",
        "new_name": "BrewCoffee",
        "username": TEST_USERNAME
    })

    if "error" in response:
        results.add_fail("Rename Task", response.get("error"))
        return

    if isinstance(response, list) and len(response) > 0:
        data = response[0]
        if data.get("success"):
            results.add_pass("Rename Task")
        else:
            results.add_fail("Rename Task", f"Expected success, got: {data}")
    elif isinstance(response, dict):
        if response.get("success"):
            results.add_pass("Rename Task")
        else:
            results.add_fail("Rename Task", f"Expected success, got: {response}")
    else:
        results.add_fail("Rename Task", f"Unexpected response: {response}")


def test_verify_rename(results: IntegrationTestResult):
    """Verify that the rename actually worked."""
    response = call_walker("get_task_graph", {"username": TEST_USERNAME})

    if "error" in response:
        results.add_fail("Verify Rename", response.get("error"))
        return

    if isinstance(response, list) and len(response) > 0:
        data = response[0]
        nodes = data.get("nodes", [])
        if "BrewCoffee" in nodes and "MakeCoffee" not in nodes:
            results.add_pass("Verify Rename")
        else:
            results.add_fail("Verify Rename", f"Expected BrewCoffee, not MakeCoffee. Nodes: {nodes}")
    else:
        results.add_fail("Verify Rename", f"Unexpected response: {response}")


def test_add_multiple_tasks(results: IntegrationTestResult):
    """Test adding multiple tasks to build a chain."""
    tasks = [
        ("WakeUp", "Start", "then"),
        ("BrushTeeth", "WakeUp", "then"),
        ("GetDressed", "BrushTeeth", "then"),
    ]

    for task_name, previous, label in tasks:
        response = call_walker("update_task_graph", {
            "task_name": task_name,
            "previous_task": previous,
            "edge_label": label,
            "username": TEST_USERNAME
        })

        if "error" in response:
            results.add_fail(f"Add Multiple Tasks ({task_name})", response.get("error"))
            return

    results.add_pass("Add Multiple Tasks")


def test_clear_graph(results: IntegrationTestResult):
    """Test clearing the graph."""
    response = call_walker("clear_graph", {"username": TEST_USERNAME})

    if "error" in response:
        results.add_fail("Clear Graph", response.get("error"))
        return

    if isinstance(response, list) and len(response) > 0:
        data = response[0]
        if data.get("success"):
            results.add_pass("Clear Graph")
        else:
            results.add_fail("Clear Graph", f"Expected success, got: {data}")
    elif isinstance(response, dict):
        if response.get("success"):
            results.add_pass("Clear Graph")
        else:
            results.add_fail("Clear Graph", f"Expected success, got: {response}")
    else:
        results.add_fail("Clear Graph", f"Unexpected response: {response}")


def test_verify_cleared(results: IntegrationTestResult):
    """Verify that the graph was cleared."""
    response = call_walker("get_task_graph", {"username": TEST_USERNAME})

    if "error" in response:
        results.add_fail("Verify Cleared Graph", response.get("error"))
        return

    if isinstance(response, list) and len(response) > 0:
        data = response[0]
        nodes = data.get("nodes", [])
        if len(nodes) == 1 and nodes[0] == "Start":
            results.add_pass("Verify Cleared Graph")
        else:
            results.add_fail("Verify Cleared Graph", f"Expected only Start node, got: {nodes}")
    else:
        results.add_fail("Verify Cleared Graph", f"Unexpected response: {response}")


def test_save_routine(results: IntegrationTestResult):
    """Test saving a routine."""
    # First add some tasks
    call_walker("update_task_graph", {
        "task_name": "MorningExercise",
        "previous_task": "Start",
        "edge_label": "then",
        "username": TEST_USERNAME
    })

    response = call_walker("save_routine", {
        "routine_name": "MorningRoutine",
        "username": TEST_USERNAME
    })

    if "error" in response:
        results.add_fail("Save Routine", response.get("error"))
        return

    if isinstance(response, list) and len(response) > 0:
        data = response[0]
        if data.get("success"):
            results.add_pass("Save Routine")
        else:
            results.add_fail("Save Routine", f"Expected success, got: {data}")
    elif isinstance(response, dict):
        if response.get("success"):
            results.add_pass("Save Routine")
        else:
            results.add_fail("Save Routine", f"Expected success, got: {response}")
    else:
        results.add_fail("Save Routine", f"Unexpected response: {response}")


def test_load_past_routines(results: IntegrationTestResult):
    """Test loading past routines."""
    response = call_walker("load_past_routines", {"username": TEST_USERNAME})

    if "error" in response:
        results.add_fail("Load Past Routines", response.get("error"))
        return

    if isinstance(response, list) and len(response) > 0:
        data = response[0]
        if "routines" in data or "count" in data:
            results.add_pass("Load Past Routines")
        else:
            results.add_fail("Load Past Routines", f"Expected routines data, got: {data}")
    elif isinstance(response, dict):
        if "routines" in response or "count" in response:
            results.add_pass("Load Past Routines")
        else:
            results.add_fail("Load Past Routines", f"Expected routines data, got: {response}")
    else:
        results.add_fail("Load Past Routines", f"Unexpected response: {response}")


def test_rebuild_graph(results: IntegrationTestResult):
    """Test rebuilding the graph with new structure."""
    new_nodes = ["Start", "TaskA", "TaskB", "TaskC"]
    new_edges = [
        {"from": "Start", "to": "TaskA", "label": "then"},
        {"from": "TaskA", "to": "TaskB", "label": "after"},
        {"from": "TaskB", "to": "TaskC", "label": "then"}
    ]

    response = call_walker("rebuild_graph", {
        "new_nodes": new_nodes,
        "new_edges": new_edges,
        "username": TEST_USERNAME
    })

    if "error" in response:
        results.add_fail("Rebuild Graph", response.get("error"))
        return

    if isinstance(response, list) and len(response) > 0:
        data = response[0]
        if data.get("success"):
            results.add_pass("Rebuild Graph")
        else:
            results.add_fail("Rebuild Graph", f"Expected success, got: {data}")
    elif isinstance(response, dict):
        if response.get("success"):
            results.add_pass("Rebuild Graph")
        else:
            results.add_fail("Rebuild Graph", f"Expected success, got: {response}")
    else:
        results.add_fail("Rebuild Graph", f"Unexpected response: {response}")


def test_reset_session(results: IntegrationTestResult):
    """Test resetting the session."""
    response = call_walker("reset_session", {"username": TEST_USERNAME})

    if "error" in response:
        results.add_fail("Reset Session", response.get("error"))
        return

    if isinstance(response, list) and len(response) > 0:
        data = response[0]
        if data.get("success"):
            results.add_pass("Reset Session")
        else:
            results.add_fail("Reset Session", f"Expected success, got: {data}")
    elif isinstance(response, dict):
        if response.get("success"):
            results.add_pass("Reset Session")
        else:
            results.add_fail("Reset Session", f"Expected success, got: {response}")
    else:
        results.add_fail("Reset Session", f"Unexpected response: {response}")


def test_session_token(results: IntegrationTestResult):
    """Test getting a session token (if OPENAI_API_KEY is set)."""
    # Skip if OPENAI_API_KEY is not set - this test requires it
    if not os.getenv("OPENAI_API_KEY"):
        print(f"{Colors.YELLOW}⊘ SKIP{Colors.ENDC}: Session Token (no OPENAI_API_KEY)")
        return

    response = call_walker("get_session_token", {})

    if "error" in response:
        results.add_fail("Get Session Token", response.get("error"))
        return

    if isinstance(response, list) and len(response) > 0:
        data = response[0]
        if "key" in data:
            results.add_pass("Get Session Token")
        else:
            results.add_fail("Get Session Token", f"Expected key in response, got: {data}")
    elif isinstance(response, dict):
        if "key" in response:
            results.add_pass("Get Session Token")
        else:
            results.add_fail("Get Session Token", f"Expected key in response, got: {response}")
    else:
        results.add_fail("Get Session Token", f"Unexpected response: {response}")


def test_analytics_endpoints(results: IntegrationTestResult):
    """Test analytics endpoints."""
    analytics_walkers = [
        ("get_activity_report", {"username": TEST_USERNAME}),
        ("calculate_productivity_metrics", {"username": TEST_USERNAME}),
        ("get_goals", {"username": TEST_USERNAME}),
    ]

    for walker_name, params in analytics_walkers:
        response = call_walker(walker_name, params)

        if "error" in response:
            results.add_fail(f"Analytics: {walker_name}", response.get("error"))
            continue

        if isinstance(response, list) or isinstance(response, dict):
            results.add_pass(f"Analytics: {walker_name}")
        else:
            results.add_fail(f"Analytics: {walker_name}", f"Unexpected response: {response}")


def test_create_goal(results: IntegrationTestResult):
    """Test creating a goal."""
    response = call_walker("create_goal", {
        "goal_type": "daily_tasks",
        "target_value": 5,
        "username": TEST_USERNAME
    })

    if "error" in response:
        results.add_fail("Create Goal", response.get("error"))
        return

    if isinstance(response, list) and len(response) > 0:
        data = response[0]
        if data.get("success") or data.get("goal_id"):
            results.add_pass("Create Goal")
        else:
            results.add_fail("Create Goal", f"Expected success or goal_id, got: {data}")
    elif isinstance(response, dict):
        if response.get("success") or response.get("goal_id"):
            results.add_pass("Create Goal")
        else:
            results.add_fail("Create Goal", f"Expected success or goal_id, got: {response}")
    else:
        results.add_fail("Create Goal", f"Unexpected response: {response}")


def test_log_activity_event(results: IntegrationTestResult):
    """Test logging an activity event."""
    response = call_walker("log_activity_event", {
        "username": TEST_USERNAME,
        "event_type": "task_created",
        "event_data": {"task_name": "TestTask"},
        "session_id": "test-session-123",
        "task_context": "TestTask",
        "emotional_context": "neutral",
        "duration_ms": 1000
    })

    if "error" in response:
        results.add_fail("Log Activity Event", response.get("error"))
        return

    if isinstance(response, list) and len(response) > 0:
        data = response[0]
        if data.get("success") or data.get("event_id"):
            results.add_pass("Log Activity Event")
        else:
            results.add_fail("Log Activity Event", f"Expected success or event_id, got: {data}")
    elif isinstance(response, dict):
        if response.get("success") or response.get("event_id"):
            results.add_pass("Log Activity Event")
        else:
            results.add_fail("Log Activity Event", f"Expected success or event_id, got: {response}")
    else:
        results.add_fail("Log Activity Event", f"Unexpected response: {response}")


def run_all_tests() -> bool:
    """Run all integration tests."""
    print(f"\n{Colors.BLUE}{'=' * 60}")
    print(f"Algo Integration Tests")
    print(f"Server: {BASE_URL}")
    print(f"Test User: {TEST_USERNAME}")
    print(f"{'=' * 60}{Colors.ENDC}\n")

    results = IntegrationTestResult()

    # Wait for server
    if not wait_for_server():
        results.add_fail("Server Startup", "Server not ready")
        return False

    # Server health check
    if not test_server_health(results):
        return False

    # Graph Operations Tests
    print(f"\n{Colors.BLUE}--- Graph Operations Tests ---{Colors.ENDC}")
    test_init_user_graph(results)
    test_get_task_graph_empty(results)
    test_update_task_graph(results)
    test_get_task_graph_with_tasks(results)
    test_rename_task(results)
    test_verify_rename(results)
    test_add_multiple_tasks(results)
    test_clear_graph(results)
    test_verify_cleared(results)

    # Routine Tests
    print(f"\n{Colors.BLUE}--- Routine Tests ---{Colors.ENDC}")
    test_save_routine(results)
    test_load_past_routines(results)

    # Graph Structure Tests
    print(f"\n{Colors.BLUE}--- Graph Structure Tests ---{Colors.ENDC}")
    test_rebuild_graph(results)
    test_reset_session(results)

    # Session Token Test
    print(f"\n{Colors.BLUE}--- Session Tests ---{Colors.ENDC}")
    test_session_token(results)

    # Analytics Tests
    print(f"\n{Colors.BLUE}--- Analytics Tests ---{Colors.ENDC}")
    test_analytics_endpoints(results)
    test_create_goal(results)
    test_log_activity_event(results)

    # Print summary
    return results.print_summary()


def main():
    """Main entry point."""
    try:
        success = run_all_tests()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Tests interrupted{Colors.ENDC}")
        sys.exit(130)
    except Exception as e:
        print(f"\n{Colors.RED}Unexpected error: {e}{Colors.ENDC}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
