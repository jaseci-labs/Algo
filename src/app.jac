import from os { getenv }
import from urllib.request { Request, urlopen }
import from urllib.error { URLError, HTTPError }
import from json { loads, dumps }
import from dotenv { load_dotenv }
import from constants { SUPERVISOR_INSTRUCTIONS, SUPERVISOR_TOOLS, CHAT_AGENT_INSTRUCTIONS }

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

# Walker to call the Supervisor Agent (gpt-4.1 via Responses API)
# When called with authentication token, runs on user's root node

walker call_supervisor {
    has conversation_history: list;
    has context_from_user: str;
    has username: str = "anonymous";  # Username for isolation
    
    can call with `root entry;
}
