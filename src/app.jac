import from os { getenv }
import from urllib.request { Request, urlopen }
import from urllib.error { URLError, HTTPError }
import from json { loads, dumps }
import from dotenv { load_dotenv }
import from CONSTANTS { SUPERVISOR_INSTRUCTIONS, SUPERVISOR_TOOLS, CHAT_AGENT_INSTRUCTIONS }

node TaskState {
    has task_name: str;
    has created_at: str = "";
}

edge TaskFlow {
    has label: str = "";  # "then", "if yes", "option 1", etc.
}

node user_graph_data {
    has username: str = "anonymous";  # User identifier
    has last_task: str = "Start";
    has saved_routines: dict = {};  # Store saved routines here
    # Task nodes are now connected via OSP: user_graph_data ++> TaskState("Start") ++> TaskState("MakeCoffee")
}

# Container for saved routines
node user_routines {
    has username: str = "anonymous";  # User identifier
    has routines: dict = {};
}

with entry {
    load_dotenv();
}

walker get_session_token {
    can fetch with `root entry;
}

# Helper function to generate DOT code from node and edge lists
def generate_dot_code_from_lists(node_list: list, edge_list: list) -> str {
    # Check if graph is empty
    if len(node_list) == 0 {
        return "";
    }

    lines = ["digraph TaskGraph {"];
    lines.append("  rankdir=TB;");
    lines.append("  node [shape=box, style=rounded, fontname=\"Arial\"];");
    lines.append("  edge [fontname=\"Arial\", fontsize=10];");
    lines.append("");

    # Add nodes with styling
    for task_node in node_list {
        if task_node == "Start" {
            lines.append("  " + task_node + " [shape=circle, style=filled, fillcolor=\"#22c55e\", fontcolor=white];");
        } else {
            lines.append("  " + task_node + " [style=\"rounded,filled\", fillcolor=\"#3b82f6\", fontcolor=white];");
        }
    }

    lines.append("");

    # Add edges
    for conn in edge_list {
        from_task = conn.get("from", "");
        to_task = conn.get("to", "");
        conn_label = conn.get("label", "");
        if conn_label {
            lines.append("  " + from_task + " -> " + to_task + " [label=\"" + conn_label + "\"];");
        } else {
            lines.append("  " + from_task + " -> " + to_task + ";");
        }
    }

    lines.append("}");
    return "\n".join(lines);
}

# Legacy helper function - kept for backward compatibility during migration
# TODO: Remove once all walkers are updated to use OSP
def generate_dot_code(node_list: list, edge_list: list) -> str {
    list_size = 0;
    for _ in node_list {
        list_size = list_size + 1;
    }
    if list_size == 0 {
        return "";
    }

    lines = ["digraph TaskGraph {"];
    lines.append("  rankdir=TB;");
    lines.append("  node [shape=box, style=rounded, fontname=\"Arial\"];");
    lines.append("  edge [fontname=\"Arial\", fontsize=10];");
    lines.append("");

    # Add nodes with styling
    for task_node in node_list {
        if task_node == "Start" {
            lines.append("  " + task_node + " [shape=circle, style=filled, fillcolor=\"#22c55e\", fontcolor=white];");
        } else {
            lines.append("  " + task_node + " [style=\"rounded,filled\", fillcolor=\"#3b82f6\", fontcolor=white];");
        }
    }

    lines.append("");

    # Add edges
    for conn in edge_list {
        from_task = conn.get("from", "");
        to_task = conn.get("to", "");
        conn_label = conn.get("label", "");
        if conn_label {
            lines.append("  " + from_task + " -> " + to_task + " [label=\"" + conn_label + "\"];");
        } else {
            lines.append("  " + from_task + " -> " + to_task + ";");
        }
    }

    lines.append("}");
    return "\n".join(lines);
}


# ============================================
# Per-User Graph Walkers
# ============================================

# Helper walker to traverse the graph and collect node/edge information
walker traverse_graph {
    has nodes_list: list = [];
    has edges_list: list = [];
    has visited: dict = {};

    can traverse_node with TaskState entry;
}

# Walker to initialize user's graph container
# When called with authentication token, runs on user's root node
walker init_user_graph {
    can initialize with `root entry;
}

# Walker to update user's task graph
# When called with authentication token, automatically runs on user's root node
walker update_task_graph {
    has task_name: str;
    has previous_task: str = "Start";
    has edge_label: str = "";
    has username: str = "anonymous";  # Username for isolation

    can navigate_to_graph with `root entry;
    can update_graph with user_graph_data entry;
}

# Walker to get user's current graph state
# When called with authentication token, runs on user's root node
walker get_task_graph {
    has username: str = "anonymous";  # Username for isolation

    can navigate_to_graph with `root entry;
    can get_graph with user_graph_data entry;
}

# Walker to clear/reset the graph for a user
walker clear_graph {
    has username: str = "anonymous";
    
    can navigate_to_graph with `root entry;
    can clear_data with user_graph_data entry;
}

# Walker to save the current graph as a learned routine
walker save_routine {
    has routine_name: str = "daily_routine";
    has username: str = "anonymous";  # Username for isolation

    can navigate_to_graph with `root entry;
    can save_routine_data with user_graph_data entry;
}

# Walker to load past routines for context
walker load_past_routines {
    has username: str = "anonymous";  # Username for isolation
    
    can navigate_to_routines with `root entry;
    can load_routines with user_routines entry;
}

# Walker to reset the current session graph
walker reset_session {
    has username: str = "anonymous";  # Username for isolation
    
    can navigate_to_graph with `root entry;
    can reset_graph with user_graph_data entry;
}

# Walker to rebuild graph with new node order (for reorganization)
walker rebuild_graph {
    has new_nodes: list;  # New ordered list of nodes
    has new_edges: list;  # New list of edges
    has username: str = "anonymous";
    
    can navigate_to_graph with `root entry;
    can rebuild with user_graph_data entry;
}

# NOTE: This function is no longer used for updateTaskGraph
# Graph operations now use per-user walkers that are called directly
# from the supervisor walker (see call_supervisor walker below)
# This function only handles non-graph tools (calendar, emails, GitHub)
def execute_local_tool(tool_name: str, tool_args: object) -> dict {
    if tool_name == "getCalendarEvents" {
        # Filter by date if provided
        date_filter = tool_args["date"] if "date" in tool_args else "today";
        # For demo, return all events (in real app, would filter by date)
        return {"events": SAMPLE_CALENDAR_EVENTS, "query": date_filter};
    } elif tool_name == "getEmails" {
        # Filter emails based on parameters
        filter_type = tool_args["filter"] if "filter" in tool_args else "all";
        count = tool_args["count"] if "count" in tool_args else 5;
        emails = SAMPLE_EMAILS[:count];
        if filter_type == "unread" {
            emails = [e for e in SAMPLE_EMAILS if "unread" in e and e["unread"]][:count];
        } elif filter_type == "important" {
            emails = [e for e in SAMPLE_EMAILS if "important" in e and e["important"]][:count];
        }
        return {"emails": emails, "filter": filter_type};
    } elif tool_name == "getGitHubIssues" {
        # Filter GitHub issues
        filter_type = tool_args["filter"] if "filter" in tool_args else "all";
        issue_type = tool_args["type"] if "type" in tool_args else "all";
        issues = SAMPLE_GITHUB_ISSUES;
        if filter_type == "open" {
            issues = [i for i in issues if "state" in i and i["state"] == "open"];
        } elif filter_type == "assigned" {
            issues = [i for i in issues if "assignee" in i and i["assignee"] == "me"];
        }
        return {"issues": issues, "filter": filter_type};
    } else {
        return {"result": True};
    }
}

# Helper function to extract text from OpenAI Responses API response
def extract_response_text(output_items: list) -> str {
    final_text = "";
    for item in output_items {
        item_type = item["type"] if "type" in item else "";
        if item_type == "message" {
            content_arr = item["content"] if "content" in item else [];
            for c in content_arr {
                c_type = c["type"] if "type" in c else "";
                if c_type == "output_text" {
                    text_val = c["text"] if "text" in c else "";
                    final_text = final_text + text_val;
                }
            }
        }
    }
    return final_text;
}

# Helper function to make OpenAI Responses API call
def make_responses_api_call(request_body: dict, api_key: object) {
    url = "https://api.openai.com/v1/responses";
    req = Request(
        url,
        data=dumps(request_body).encode('utf-8'),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        },
        method="POST"
    );
    response = urlopen(req);
    result = loads(response.read().decode('utf-8'));
    return result;
}

# Walker to call the Supervisor Agent (gpt-4.1 via Responses API)
# When called with authentication token, runs on user's root node
walker call_supervisor {
    has conversation_history: list;
    has context_from_user: str;
    has username: str = "anonymous";  # Username for isolation
    
    can call with `root entry;
}
