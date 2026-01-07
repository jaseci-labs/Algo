# Algo - Personal AI Assistant with Voice Interface
# Implements: Voice Agent (realtime) -> Backend Intelligence (gpt-4.1) -> Tools
# Calendar, Email, GitHub integration

import from os { getenv }
import from urllib.request { Request, urlopen }
import from urllib.error { URLError, HTTPError }
import from json { loads, dumps }
import from dotenv { load_dotenv }

# Import data models - define nodes directly in this file for now
# import from .models { user_graph_data, user_routines }

# Container node to hold a user's task graph state
# NOTE: With jac-scale authentication, each user automatically gets their own root node (root_id)
# Walkers called with auth token run on that user's root, providing automatic isolation
# TEMP: Added username field for manual isolation with jac serve (remove when using jac scale)
node user_graph_data {
    has username: str = "anonymous";  # User identifier
    has nodes: list = ["Start"];
    has edges: list = [];
    has last_task: str = "Start";
    has saved_routines: dict = {};  # Store saved routines here
}

# Container for saved routines
node user_routines {
    has username: str = "anonymous";  # User identifier
    has routines: dict = {};
}

# Load .env from project root (auto-discovers .env in cwd or parent dirs)
with entry {
    load_dotenv();
}

# ============================================
# Supervisor Agent Instructions
# ============================================

glob SUPERVISOR_INSTRUCTIONS = """You are the backend intelligence for Algo, a personal AI assistant. You process requests from the voice interface and have access to the user's personal tools and data.

# Primary Task: Task Graph Generation (Decision Tree)
Your MOST IMPORTANT job is to track the user's tasks and activities as a DECISION TREE graph.
- When the user mentions doing something NEW (a task, activity, or action), you MUST call updateTaskGraph
- Extract the task name as a short label (2-4 words, CamelCase, no spaces)
- Connect it to the previous task to show the sequence of activities
- Examples: "I'm making coffee" → MakeCoffee, "going to wash my face" → WashFace, "checking emails" → CheckEmails

# CRITICAL: Decision Tree / Branching Support
When the user describes conditional logic (if/else, either/or), create MULTIPLE tasks from the same parent:
- User: "I'll check if family is awake. If they are, I'll make coffee for them, otherwise just for myself"
  → Call updateTaskGraph TWICE:
  1. taskName="MakeCoffeeForFamily", previousTask="CheckIfFamilyIsAwake", edgeLabel="if yes"
  2. taskName="MakeCoffeeForMyself", previousTask="CheckIfFamilyIsAwake", edgeLabel="if no"
- User: "After lunch, I might go to gym or go home"
  → Call updateTaskGraph TWICE:
  1. taskName="GoToGym", previousTask="GoToLunch", edgeLabel="option 1"
  2. taskName="GoHome", previousTask="GoToLunch", edgeLabel="option 2"

# CRITICAL: Determining the Previous Task
When calling updateTaskGraph, pay CLOSE ATTENTION to what the user says:
- If user says "after [task X]" or "then I'll [task Y]", connect from that specific task X
  Example: "after going to lunch, I'll go to friend's house" → previousTask="GoToLunch"
- If user says "I'm now doing X" or "I just did X", connect from the last_task in current context
- Look at the existing graph nodes - use the exact task name that already exists
- If unsure, use the last_task from the current graph state

# IMPORTANT: Avoid Duplicate Updates
- If the user mentions a task that's ALREADY in the graph, DO NOT call updateTaskGraph again
- Only call updateTaskGraph when the user is doing something NEW that continues their routine
- Example: If graph already has "WakeUp→WashFace→MakeCoffee" and user says "I just woke up", don't add WakeUp again
- Example: If user says "what should I do?" or "wondering what's next", that's NOT a new task - don't update the graph

# Learning from Past Behavior
- When provided with past routines in context, use them to make intelligent suggestions
- If the user mentions an activity they've done before, reference the typical next steps from their routine
- Example: "I just woke up" + past shows WakeUp→MakeCoffee→Shower, suggest: "Would you like to make coffee next? That's what you usually do."

# Instructions
- ALWAYS call updateTaskGraph when the user mentions ANY task or activity
- You can also call other tools (calendar, emails, github) if needed
- If you need information, tell the voice agent to ask the user
- Your message will be spoken verbatim by the voice agent
- Be helpful, efficient, and personable
- For voice conversation, be very concise, use natural prose

# Tools Available
- updateTaskGraph: REQUIRED - Call this whenever user mentions a task/activity
- getCalendarEvents: Check the user's calendar for meetings and events
- getEmails: Retrieve and summarize the user's recent emails
- getGitHubIssues: Look up GitHub issues and repository activity

# Response Format
Always provide a clear, concise response that sounds natural when spoken aloud.
Acknowledge the task the user mentioned in your response.
""";

glob SUPERVISOR_TOOLS = [
    {
        "type": "function",
        "name": "updateTaskGraph",
        "description": "REQUIRED: Call this whenever the user mentions a task or activity. Updates the task graph with a new node and connects it to the previous task.",
        "parameters": {
            "type": "object",
            "properties": {
                "taskName": {
                    "type": "string",
                    "description": "Short task name in CamelCase (2-4 words, no spaces). E.g., 'MakeCoffee', 'WashFace', 'CheckEmails', 'AttendMeeting'"
                },
                "previousTask": {
                    "type": "string",
                    "description": "The task to connect FROM. CRITICAL: If user says 'after [TaskX]', use TaskX. Otherwise use last_task from context. Must match an existing node name exactly (e.g., 'GoToLunch', 'WakeUp')."
                },
                "edgeLabel": {
                    "type": "string",
                    "description": "Edge label for branching/conditions (e.g., 'if yes', 'if no', 'option 1', 'option 2', 'then', 'or'). Use descriptive labels for decision points."
                }
            },
            "required": ["taskName", "previousTask"],
            "additionalProperties": False
        }
    },
    {
        "type": "function",
        "name": "getCalendarEvents",
        "description": "Get the user's calendar events and meetings for a specific date or date range.",
        "parameters": {
            "type": "object",
            "properties": {
                "date": {
                    "type": "string",
                    "description": "The date to check (e.g., 'today', 'tomorrow', '2025-01-15', 'this week')."
                }
            },
            "required": ["date"],
            "additionalProperties": False
        }
    },
    {
        "type": "function",
        "name": "getEmails",
        "description": "Retrieve and summarize the user's recent emails, optionally filtered.",
        "parameters": {
            "type": "object",
            "properties": {
                "filter": {
                    "type": "string",
                    "description": "Optional filter: 'unread', 'important', 'from:<sender>', or a search term."
                },
                "count": {
                    "type": "integer",
                    "description": "Number of emails to retrieve (default: 5)."
                }
            },
            "required": [],
            "additionalProperties": False
        }
    },
    {
        "type": "function",
        "name": "getGitHubIssues",
        "description": "Look up GitHub issues, pull requests, or repository activity.", 
        "parameters": {
            "type": "object",
            "properties": {
                "repo": {
                    "type": "string",
                    "description": "Repository name in format 'owner/repo' (optional, uses default if not specified)."
                },
                "filter": {
                    "type": "string",
                    "description": "Filter: 'open', 'closed', 'assigned', 'mentioned', or 'all'."
                },
                "type": {
                    "type": "string",
                    "description": "Type: 'issues', 'prs', or 'all'."
                }
            },
            "required": [],
            "additionalProperties": False
        }
    }
];


# ============================================
# Chat Agent Instructions (Junior Agent)
# ============================================

glob CHAT_AGENT_INSTRUCTIONS = """You are Algo, a friendly and capable personal AI assistant. Your task is to maintain a natural conversation with the user and defer to your backend systems for complex queries.

# General Instructions
- Greet the user warmly with "Hey! I'm Algo, your personal AI assistant. How can I help you today?"
- For basic chitchat (greetings, thank you, clarifications), respond directly
- For ALL queries about calendar, meetings, emails, GitHub issues, or any data lookups, use getNextResponseFromSupervisor
- Before calling getNextResponseFromSupervisor, ALWAYS say a filler phrase first

# Filler Phrases (use before calling supervisor)
- "Let me check that for you."
- "One moment, I'll look that up."
- "Checking your calendar..."
- "Let me pull up that information."

# Tone
- Be friendly, helpful, and conversational
- Keep responses concise but warm
- Never repeat the same phrase twice

# Capabilities (handled by supervisor)
- Check calendar and upcoming meetings
- Read and summarize emails
- Look up GitHub issues and repository activity
- General personal assistant tasks

# Tools
- You can ONLY call getNextResponseFromSupervisor
- This queries your backend systems for real information
- Provide relevant context from the user's last message
""";


# ============================================
# Helper Functions for User Isolation
# ============================================

# Helper function to get the current authenticated user's ID
# For now, this returns "anonymous" - will be enhanced to get real user ID from context
def get_user_id() -> str {
    # TODO: Access user ID from jac-scale authentication context
    # This needs to be implemented based on jac-scale's auth system
    return "anonymous";
}

# ============================================
# Backend Walkers
# ============================================

# Walker to fetch OpenAI Realtime session token
walker get_session_token {
    can fetch with `root entry {
        try {
            api_key = getenv("OPENAI_API_KEY");
            
            if not api_key {
                report {"error": "OPENAI_API_KEY not set in environment"};
                return;
            }
            
            url = "https://api.openai.com/v1/realtime/client_secrets";
            request_data = dumps({
                "session": {
                    "type": "realtime",
                    "model": "gpt-realtime"
                }
            });
            
            req = Request(
                url,
                data=request_data.encode('utf-8'),
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json"
                },
                method="POST"
            );
            
            response = urlopen(req);
            data = loads(response.read().decode('utf-8'));
            
            if "value" in data {
                report {"key": data["value"]};
            } else {
                report {"error": "Failed to fetch key", "details": data};
            }
            
        } except HTTPError as e {
            error_msg = e.read().decode('utf-8') if hasattr(e, 'read') else str(e);
            report {"error": f"HTTP Error: {e.code}", "details": error_msg};
        } except URLError as e {
            report {"error": "URL Error", "details": str(e.reason)};
        } except Exception as e {
            report {"error": "Server error", "details": str(e)};
        }
    }
}



# REMOVED: Global graph state - now stored per-user in nodes
# Users have isolated graph data attached to their root node


# Helper function to generate DOT code from graph state
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

# Walker to initialize user's graph container
# When called with authentication token, runs on user's root node
walker init_user_graph {
    can initialize with `root entry;
}

impl init_user_graph.initialize with `root entry {
    visit [-->](`?user_graph_data) else {
        graph_cont = here ++> user_graph_data();
    }
    visit [-->](`?user_routines) else {
        routine_cont = here ++> user_routines();
    }
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

impl update_task_graph.navigate_to_graph with `root entry {
    # Find or create user-specific graph based on username
    all_graphs = [-->](`?user_graph_data);
    
    user_graph = None;
    for graph in all_graphs {
        if hasattr(graph, 'username') and graph.username == self.username {
            user_graph = graph;
            break;
        }
    }
    
    if user_graph == None {
        # Create new graph for this user
        user_graph = here ++> user_graph_data(username=self.username);
    }
    
    visit user_graph;
}

impl update_task_graph.update_graph with user_graph_data entry {
    # Add Start task if this is the first task
    if self.previous_task == "Start" and "Start" not in here.nodes {
        here.nodes = here.nodes + ["Start"];
    }

    # Add the new task if not already present
    if self.task_name and self.task_name not in here.nodes {
        here.nodes = here.nodes + [self.task_name];
    }

    # Add connection from previous to current (check for duplicates first)
    if self.task_name and self.previous_task {
        connection_exists = False;
        for existing_conn in here.edges {
            from_val = existing_conn["from"] if "from" in existing_conn else "";
            to_val = existing_conn["to"] if "to" in existing_conn else "";
            if from_val == self.previous_task and to_val == self.task_name {
                connection_exists = True;
                break;
            }
        }

        # Only add if connection doesn't exist
        if not connection_exists {
            new_conn = {"from": self.previous_task, "to": self.task_name};
            if self.edge_label {
                new_conn["label"] = self.edge_label;
            }
            here.edges = here.edges + [new_conn];
        }
    }

    # Update last task
    here.last_task = self.task_name;

    # Generate updated DOT code
    dot_code = generate_dot_code(here.nodes, here.edges);

    report {
        "success": True,
        "message": f"Added task '{self.task_name}' connected from '{self.previous_task}'",
        "dotCode": dot_code,
        "nodes": here.nodes,
        "edges": here.edges
    };
}

# Walker to get user's current graph state
# When called with authentication token, runs on user's root node
walker get_task_graph {
    has username: str = "anonymous";  # Username for isolation

    can navigate_to_graph with `root entry;
    can get_graph with user_graph_data entry;
}

impl get_task_graph.navigate_to_graph with `root entry {
    # Find user-specific graph based on username
    all_graphs = [-->](`?user_graph_data);
    
    user_graph = None;
    for graph in all_graphs {
        if hasattr(graph, 'username') and graph.username == self.username {
            user_graph = graph;
            break;
        }
    }
    
    if user_graph == None {
        # No graph yet, return empty
        report {
            "nodes": [],
            "edges": [],
            "dotCode": "",
            "lastTask": "Start"
        };
        disengage;
    }
    
    visit user_graph;
}

impl get_task_graph.get_graph with user_graph_data entry {
    # Generate DOT code
    dot_code = generate_dot_code(here.nodes, here.edges);

    report {
        "nodes": here.nodes,
        "edges": here.edges,
        "dotCode": dot_code,
        "lastTask": here.last_task
    };
}

# Walker to clear/reset the graph for a user
walker clear_graph {
    has username: str = "anonymous";
    
    can navigate_to_graph with `root entry;
    can clear_data with user_graph_data entry;
}

impl clear_graph.navigate_to_graph with `root entry {
    # Find user-specific graph
    print(f"DEBUG CLEAR_GRAPH: Looking for graph for user: {self.username}");
    
    all_graphs = [-->](`?user_graph_data);
    
    user_graph = None;
    for graph in all_graphs {
        if hasattr(graph, 'username') and graph.username == self.username {
            user_graph = graph;
            break;
        }
    }
    
    if user_graph == None {
        report {"success": True, "message": "No graph to clear"};
        disengage;
    }
    
    visit user_graph;
}

impl clear_graph.clear_data with user_graph_data entry {
    # Reset graph to initial state
    here.nodes = ["Start"];
    here.edges = [];
    here.last_task = "Start";
    
    print(f"DEBUG CLEAR_GRAPH: Graph cleared for user {self.username}");
    
    report {
        "success": True,
        "message": "Graph cleared successfully"
    };
}

# Walker to save the current graph as a learned routine
walker save_routine {
    has routine_name: str = "daily_routine";
    has username: str = "anonymous";  # Username for isolation

    can navigate_to_graph with `root entry;
    can save_routine_data with user_graph_data entry;
}

impl save_routine.navigate_to_graph with `root entry {
    # Find user-specific graph
    all_graphs = [-->](`?user_graph_data);
    
    user_graph = None;
    for graph in all_graphs {
        if hasattr(graph, 'username') and graph.username == self.username {
            user_graph = graph;
            break;
        }
    }
    
    if user_graph == None {
        report {"error": "No graph to save", "success": False};
        disengage;
    }
    
    visit user_graph;
}

impl save_routine.save_routine_data with user_graph_data entry {
    # Store routine directly in the user_graph_data node
    
    # Initialize saved_routines dict if needed
    if not hasattr(here, 'saved_routines') or here.saved_routines == None {
        here.saved_routines = {};
    }
    
    # Get current timestamp
    import from time { time }
    timestamp = str(time());
    
    # Save the routine
    here.saved_routines[self.routine_name] = {
        "nodes": here.nodes.copy(),
        "edges": here.edges.copy(),
        "saved_at": timestamp
    };
    
    # Count nodes manually
    node_count = 0;
    for _ in here.nodes {
        node_count = node_count + 1;
    }
    
    report {
        "success": True,
        "message": f"Saved routine with {node_count} tasks",
        "routine": here.saved_routines[self.routine_name]
    };
}

# Walker to load past routines for context
walker load_past_routines {
    has username: str = "anonymous";  # Username for isolation
    
    can navigate_to_routines with `root entry;
    can load_routines with user_routines entry;
}

impl load_past_routines.navigate_to_routines with `root entry {
    # Find user-specific routines
    all_routines = [-->](`?user_routines);
    
    user_routines_node = None;
    for r in all_routines {
        if hasattr(r, 'username') and r.username == self.username {
            user_routines_node = r;
            break;
        }
    }
    
    if user_routines_node == None {
        # No routines yet
        report {"routines": {}, "count": 0, "message": "No past routines saved yet"};
        disengage;
    }
    
    visit user_routines_node;
}

impl load_past_routines.load_routines with user_routines entry {
    # Count routines manually
    routine_count = 0;
    for _ in here.routines {
        routine_count = routine_count + 1;
    }

    if routine_count == 0 {
        report {"routines": {}, "count": 0, "message": "No past routines saved yet"};
    } else {
        report {
            "routines": here.routines,
            "count": routine_count,
            "message": f"Loaded {routine_count} saved routine(s)"
        };
    }
}

# Walker to reset the current session graph
walker reset_session {
    can navigate_to_graph with `root entry;
    can reset_graph with user_graph_data entry;
}

impl reset_session.navigate_to_graph with `root entry {
    visit [-->](`?user_graph_data) else {
        report {
            "success": True,
            "message": "Session already empty."
        };
        disengage;
    }
}

impl reset_session.reset_graph with user_graph_data entry {
    # Clear graph but keep saved routines
    here.nodes = [];
    here.edges = [];
    here.last_task = "Start";

    report {
        "success": True,
        "message": "Session reset. Ready for a new conversation."
    };
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
    
    can call with `root entry {
        try {
            api_key = getenv("OPENAI_API_KEY");
            
            if not api_key {
                report {"error": "OPENAI_API_KEY not set"};
                return;
            }
            
            # Load user's past routines for context
            past_routines_context = "";
            # Note: Skipping routines for now due to walker spawn issues
            # TODO: Fix walker result handling

            # Load user's current graph state by directly traversing the graph
            current_nodes = [];
            current_edges = [];
            last_task = "Start";
            
            # Find user-specific graph data
            all_graphs = [-->](`?user_graph_data);
            for graph in all_graphs {
                if hasattr(graph, 'username') and graph.username == self.username {
                    current_nodes = graph.nodes if hasattr(graph, 'nodes') else [];
                    current_edges = graph.edges if hasattr(graph, 'edge') else [];
                    last_task = graph.last_task if hasattr(graph, 'last_task') else "Start";
                    break;
                }
            }

            # Build the request body for OpenAI Responses API
            request_body = {
                "model": "gpt-4.1",
                "input": [
                    {
                        "type": "message",
                        "role": "system",
                        "content": SUPERVISOR_INSTRUCTIONS
                    },
                    {
                        "type": "message",
                        "role": "user",
                        "content": f"""==== Conversation History ====
                        {dumps(self.conversation_history, indent=2)}

                        ==== Relevant Context From Last User Message ====
                        {self.context_from_user}

                        ==== Current Task Graph ====
                        Existing Nodes: {dumps(current_nodes)}
                        Existing Edges: {dumps(current_edges)}
                        Last Task (most recent): {last_task}
                        {past_routines_context}

                        IMPORTANT: 
                        - When adding a new task, check the Existing Nodes list first
                        - If a similar task already exists (e.g., "GoToMall" exists), use that EXACT name, don't create "GoMall"
                        - Use the Last Task as previousTask when connecting sequential activities
                        - Only create a new node if the task doesn't already exist in the Existing Nodes
                        """
                    }
                ],
                "tools": SUPERVISOR_TOOLS,
                "parallel_tool_calls": False
            };
            
            # Make initial API call
            data = make_responses_api_call(request_body, api_key);
            output_items = data["output"] if "output" in data else [];
            
            # Process tool calls iteratively (up to 5 rounds)
            max_iterations = 5;
            iteration = 0;
            
            while iteration < max_iterations {
                # Check for function calls
                function_calls = [];
                for item in output_items {
                    item_type = item["type"] if "type" in item else "";
                    if item_type == "function_call" {
                        function_calls = function_calls + [item];
                    }
                }

                # Count function calls
                fc_count = 0;
                for _ in function_calls {
                    fc_count = fc_count + 1;
                }

                if fc_count == 0 {
                    # No more function calls - extract final response
                    break;
                }
                
                # Execute function calls
                for tool_call in function_calls {
                    f_name = tool_call["name"] if "name" in tool_call else "";
                    f_args_str = tool_call["arguments"] if "arguments" in tool_call else "{}";
                    f_args = loads(f_args_str);

                    # Execute the tool - use per-user walker for updateTaskGraph
                    tool_output = {};
                    if f_name == "updateTaskGraph" {
                        # Use per-user walker to update the graph
                        task_name = f_args["taskName"] if "taskName" in f_args else "";
                        previous_task = f_args["previousTask"] if "previousTask" in f_args else "Start";
                        edge_label = f_args["edgeLabel"] if "edgeLabel" in f_args else "";

                        # Spawn walker - pass username for isolation
                        here spawn update_task_graph(
                            task_name=task_name,
                            previous_task=previous_task,
                            edge_label=edge_label,
                            username=self.username
                        );
                        # Return success - the walker handles the actual update
                        tool_output = {
                            "success": True,
                            "message": f"Updated graph with task: {task_name}"
                        };
                    } else {
                        # Use existing function for other tools
                        tool_output = execute_local_tool(f_name, f_args);
                    }

                    # Add function call and result to the request body
                    call_id = tool_call["call_id"] if "call_id" in tool_call else "";
                    request_body["input"] = request_body["input"] + [{
                        "type": "function_call",
                        "call_id": call_id,
                        "name": f_name,
                        "arguments": f_args_str
                    }];
                    request_body["input"] = request_body["input"] + [{
                        "type": "function_call_output",
                        "call_id": call_id,
                        "output": dumps(tool_output)
                    }];
                }
                
                # Make follow-up request
                data = make_responses_api_call(request_body, api_key);
                output_items = data["output"] if "output" in data else [];
                iteration = iteration + 1;
            }
            
            # Extract final text
            final_response = extract_response_text(output_items);

            # TODO: Get updated graph state - fix walker spawn result handling
            # For now, return empty graph data since updates happen in update_task_graph walker
            report {
                "response": final_response,
                "dotCode": "",
                "graphNodes": [],
                "graphEdges": []
            };
            
        } except HTTPError as e {
            error_msg = e.read().decode('utf-8') if hasattr(e, 'read') else str(e);
            report {"error": f"HTTP Error: {e.code}", "details": error_msg};
        } except URLError as e {
            report {"error": "URL Error", "details": str(e.reason)};
        } except Exception as e {
            report {"error": "Server error", "details": str(e)};
        }
    }
}
