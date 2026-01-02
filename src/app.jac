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

# Container for user insights and behavior patterns
node user_insights {
    has username: str = "anonymous";
    has total_interactions: int = 0;
    has common_sequences: list = [];  # List of common task sequences
    has time_patterns: dict = {};  # When user typically does things
    has preferences: dict = {};  # Learned preferences
    has last_questions_asked: list = [];  # Track what we've asked to avoid repetition
    has unanswered_questions: list = [];  # Questions user hasn't answered yet
}

# Load .env from project root (auto-discovers .env in cwd or parent dirs)
with entry {
    load_dotenv();
}

# ============================================
# Helper Functions
# ============================================

# Helper to check if edge exists
def edge_exists(edges: list, from_task: str, to_task: str) -> bool {
    for edge in edges {
        if edge.get("from", "") == from_task and edge.get("to", "") == to_task {
            return True;
        }
    }
    return False;
}

# ============================================
# Supervisor Agent Instructions
# ============================================

glob SUPERVISOR_INSTRUCTIONS = """You are the backend intelligence for Algo, a personal AI assistant. You are PROACTIVE, not just reactive. You actively learn about the user, ask clarifying questions, and suggest improvements.

# Core Philosophy: BE PROACTIVE
- Don't just wait for the user to tell you things - ASK questions to understand them better
- Analyze patterns in their behavior and routines
- Suggest activities and optimizations based on what you've learned
- Build a comprehensive understanding of their habits, goals, and preferences

# Primary Task: Task Graph Generation
Your MOST IMPORTANT job is to track the user's tasks and activities as a directed graph.
- When the user mentions doing something NEW (a task, activity, or action), you MUST call updateTaskGraph
- Extract the task name as a short label (2-4 words, CamelCase, no spaces)
- Connect it to the previous task to show the sequence of activities
- Examples: "I'm making coffee" → MakeCoffee, "going to wash my face" → WashFace, "checking emails" → CheckEmails

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

# Proactive Learning & Analysis
- After seeing 3-5 tasks, call analyzeRoutinePattern to identify patterns
- Use askClarifyingQuestion to learn MORE about tasks: duration, purpose, frequency, time of day
- Use suggestNextActivity when user seems idle or asks what to do
- Track insights about user preferences, habits, and behavior patterns
- Examples of proactive questions:
  * "How long does [task] usually take you?"
  * "Do you do [task] at the same time every day?"
  * "What's your goal with [task]?"
  * "I noticed you always do X before Y. Is there a reason?"

# Learning from Past Behavior
- When provided with past routines in context, use them to make intelligent suggestions
- If the user mentions an activity they've done before, reference the typical next steps from their routine
- Example: "I just woke up" + past shows WakeUp→MakeCoffee→Shower, suggest: "Would you like to make coffee next? That's what you usually do."
- Identify patterns like: "I notice you check emails right after waking up. Would you like me to summarize them for you?"

# Proactive Behavior Rules
1. Ask 1-2 clarifying questions per conversation (don't overwhelm)
2. Suggest activities when user seems uncertain or idle
3. Provide insights about their routines ("You've been consistent with morning workouts!")
4. Offer optimizations ("You could save 10 minutes by doing X before Y")
5. Track unanswered questions and revisit them later

# Instructions
- ALWAYS call updateTaskGraph when the user mentions ANY task or activity
- Use proactive tools (analyzeRoutinePattern, askClarifyingQuestion, suggestNextActivity) regularly
- You can also call other tools (calendar, emails, github) if needed
- If you need information, tell the voice agent to ask the user
- Your message will be spoken verbatim by the voice agent
- Be helpful, efficient, and personable but also curious and insightful
- For voice conversation, be very concise, use natural prose

# Tools Available
- updateTaskGraph: REQUIRED - Call this whenever user mentions a task/activity
- analyzeRoutinePattern: Analyze current routine for patterns and insights
- askClarifyingQuestion: Ask user for more details about their habits/preferences
- suggestNextActivity: Suggest what user should do next based on patterns
- getCalendarEvents: Check the user's calendar for meetings and events
- getEmails: Retrieve and summarize the user's recent emails
- getGitHubIssues: Look up GitHub issues and repository activity

# Response Format
Always provide a clear, concise response that sounds natural when spoken aloud.
Acknowledge the task the user mentioned in your response.
Be conversational and show genuine interest in understanding the user better.
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
                    "description": "Optional label for the edge (e.g., 'then', 'after', 'next'). Leave empty for no label."
                }
            },
            "required": ["taskName", "previousTask"],
            "additionalProperties": False
        }
    },
    {
        "type": "function",
        "name": "analyzeRoutinePattern",
        "description": "Analyze the current task graph to identify patterns, common sequences, and potential insights about user behavior.",
        "parameters": {
            "type": "object",
            "properties": {
                "focus": {
                    "type": "string",
                    "description": "What to focus analysis on: 'sequences' (common task chains), 'efficiency' (time optimization), 'habits' (behavioral patterns), or 'all'"
                }
            },
            "required": ["focus"],
            "additionalProperties": False
        }
    },
    {
        "type": "function",
        "name": "askClarifyingQuestion",
        "description": "Ask the user a specific question to learn more about their habits, preferences, or routines. Use this to build a deeper understanding.",
        "parameters": {
            "type": "object",
            "properties": {
                "question": {
                    "type": "string",
                    "description": "The specific question to ask the user. Should be natural and conversational."
                },
                "questionType": {
                    "type": "string",
                    "description": "Category: 'timing' (when they do things), 'duration' (how long tasks take), 'purpose' (why they do things), 'preference' (likes/dislikes), 'frequency' (how often)"
                },
                "relatedTask": {
                    "type": "string",
                    "description": "The task this question relates to (optional)"
                }
            },
            "required": ["question", "questionType"],
            "additionalProperties": False
        }
    },
    {
        "type": "function",
        "name": "suggestNextActivity",
        "description": "Suggest what the user should do next based on their patterns, current time, and routine analysis.",
        "parameters": {
            "type": "object",
            "properties": {
                "suggestion": {
                    "type": "string",
                    "description": "The activity to suggest (e.g., 'MakeCoffee', 'CheckEmails')"
                },
                "reasoning": {
                    "type": "string",
                    "description": "Why you're suggesting this (based on patterns, time, or past behavior)"
                }
            },
            "required": ["suggestion", "reasoning"],
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
    visit [-->](`?user_insights) else {
        insights_cont = here ++> user_insights();
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

# Walker to update user insights (track questions, patterns, preferences)
walker update_user_insights {
    has username: str = "anonymous";
    has insight_type: str = "interaction";  # interaction, question, pattern, preference
    has data: dict = {};
    
    can navigate_to_insights with `root entry;
    can update_insights with user_insights entry;
}

impl update_user_insights.navigate_to_insights with `root entry {
    # Find or create user-specific insights
    all_insights = [-->](`?user_insights);
    
    user_insight = None;
    for insight in all_insights {
        if hasattr(insight, 'username') and insight.username == self.username {
            user_insight = insight;
            break;
        }
    }
    
    if user_insight == None {
        # Create new insights node for this user
        user_insight = here ++> user_insights(username=self.username);
    }
    
    visit user_insight;
}

impl update_user_insights.update_insights with user_insights entry {
    # Increment interaction count
    here.total_interactions = here.total_interactions + 1;
    
    # Update based on insight type
    if self.insight_type == "question" {
        question_text = self.data.get("question", "");
        if question_text {
            # Track questions asked
            here.last_questions_asked = here.last_questions_asked + [question_text];
            # Keep only last 10 questions
            if len(here.last_questions_asked) > 10 {
                here.last_questions_asked = here.last_questions_asked[-10:];
            }
        }
    } elif self.insight_type == "pattern" {
        # Store identified patterns
        pattern = self.data.get("pattern", "");
        if pattern and pattern not in here.common_sequences {
            here.common_sequences = here.common_sequences + [pattern];
        }
    } elif self.insight_type == "preference" {
        # Store user preferences
        pref_key = self.data.get("key", "");
        pref_value = self.data.get("value", "");
        if pref_key {
            here.preferences[pref_key] = pref_value;
        }
    }
    
    report {
        "success": True,
        "total_interactions": here.total_interactions,
        "message": f"Insights updated ({self.insight_type})"
    };
}

# Walker to get user insights for proactive suggestions
walker get_user_insights {
    has username: str = "anonymous";
    
    can navigate_to_insights with `root entry;
    can retrieve_insights with user_insights entry;
}

impl get_user_insights.navigate_to_insights with `root entry {
    # Find user-specific insights
    all_insights = [-->](`?user_insights);
    
    user_insight = None;
    for insight in all_insights {
        if hasattr(insight, 'username') and insight.username == self.username {
            user_insight = insight;
            break;
        }
    }
    
    if user_insight == None {
        # No insights yet
        report {
            "total_interactions": 0,
            "common_sequences": [],
            "preferences": {},
            "last_questions_asked": []
        };
        disengage;
    }
    
    visit user_insight;
}

impl get_user_insights.retrieve_insights with user_insights entry {
    report {
        "total_interactions": here.total_interactions,
        "common_sequences": here.common_sequences,
        "preferences": here.preferences,
        "last_questions_asked": here.last_questions_asked,
        "time_patterns": here.time_patterns
    };
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

# Pattern analysis function
def analyze_task_patterns(nodes: list, edges: list) -> dict {
    sequences = [f"{e.get('from', '')} → {e.get('to', '')}" for e in edges if e.get('from') and e.get('to')];
    return {
        "sequences": sequences,
        "totalTasks": len(nodes),
        "insights": f"You've tracked {len(nodes)} tasks with {len(edges)} connections."
    };
}

# Execute local tools (calendar, emails, GitHub, proactive tools)
def execute_local_tool(tool_name: str, tool_args: object, current_nodes: list = [], current_edges: list = []) -> dict {
    if tool_name == "analyzeRoutinePattern" {
        analysis = analyze_task_patterns(current_nodes, current_edges);
        return {"analysis": analysis, "focus": tool_args.get("focus", "all"), 
                "message": f"Found {len(analysis['sequences'])} task sequences."};
    } elif tool_name == "askClarifyingQuestion" {
        return {"question": tool_args.get("question", ""), "questionType": tool_args.get("questionType", "general"),
                "relatedTask": tool_args.get("relatedTask", ""), "action": "ask_user", "message": tool_args.get("question", "")};
    } elif tool_name == "suggestNextActivity" {
        suggestion = tool_args.get("suggestion", "");
        reasoning = tool_args.get("reasoning", "");
        return {"suggestion": suggestion, "reasoning": reasoning, 
                "message": f"Based on your patterns, I suggest: {suggestion}. {reasoning}"};
    } elif tool_name == "getCalendarEvents" {
        return {"events": SAMPLE_CALENDAR_EVENTS, "query": tool_args.get("date", "today")};
    } elif tool_name == "getEmails" {
        filter_type = tool_args.get("filter", "all");
        count = tool_args.get("count", 5);
        emails = SAMPLE_EMAILS[:count];
        if filter_type != "all" {
            emails = [e for e in SAMPLE_EMAILS if e.get(filter_type, False)][:count];
        }
        return {"emails": emails, "filter": filter_type};
    } elif tool_name == "getGitHubIssues" {
        filter_type = tool_args.get("filter", "all");
        issues = SAMPLE_GITHUB_ISSUES;
        if filter_type != "all" {
            issues = [i for i in SAMPLE_GITHUB_ISSUES if i.get("state") == filter_type or i.get("assignee") == "me"];
        }
        return {"issues": issues, "filter": filter_type};
    }
    return {"result": True};
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

            # Load user's current graph state
            current_nodes = [];
            current_edges = [];
            last_task = "Start";
            all_graphs = [-->](`?user_graph_data);
            for graph in all_graphs {
                if hasattr(graph, 'username') and graph.username == self.username {
                    current_nodes = graph.nodes if hasattr(graph, 'nodes') else [];
                    current_edges = graph.edges if hasattr(graph, 'edges') else [];
                    last_task = graph.last_task if hasattr(graph, 'last_task') else "Start";
                    break;
                }
            }
            
            # Load user insights for proactive behavior
            user_insights_data = {"total_interactions": 0, "common_sequences": [], 
                                 "preferences": {}, "last_questions_asked": []};
            all_insights = [-->](`?user_insights);
            for insight in all_insights {
                if hasattr(insight, 'username') and insight.username == self.username {
                    user_insights_data = {
                        "total_interactions": insight.total_interactions if hasattr(insight, 'total_interactions') else 0,
                        "common_sequences": insight.common_sequences if hasattr(insight, 'common_sequences') else [],
                        "preferences": insight.preferences if hasattr(insight, 'preferences') else {},
                        "last_questions_asked": insight.last_questions_asked if hasattr(insight, 'last_questions_asked') else []
                    };
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
                        
                        ==== User Insights (For Proactive Behavior) ====
                        Total Interactions: {user_insights_data["total_interactions"]}
                        Identified Patterns: {dumps(user_insights_data["common_sequences"])}
                        Questions Asked Recently: {dumps(user_insights_data["last_questions_asked"])}
                        User Preferences: {dumps(user_insights_data["preferences"])}
                        
                        PROACTIVE GUIDANCE:
                        - If you've had 3+ interactions, start asking clarifying questions about their routine
                        - If patterns are emerging (repeated sequences), analyze and suggest optimizations
                        - Avoid asking questions you've already asked (check Questions Asked Recently)
                        - Suggest next activities when user seems idle or uncertain
                        - Be genuinely curious about their habits and goals

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
            iteration = 0;
            while iteration < 5 {
                # Extract function calls
                function_calls = [item for item in output_items if item.get("type") == "function_call"];
                if len(function_calls) == 0 {
                    break;
                }
                
                # Execute function calls
                for tool_call in function_calls {
                    f_name = tool_call.get("name", "");
                    f_args_str = tool_call.get("arguments", "{}");
                    f_args = loads(f_args_str);

                    tool_output = {};
                    if f_name == "updateTaskGraph" {
                        task_name = f_args.get("taskName", "");
                        previous_task = f_args.get("previousTask", "Start");
                        edge_label = f_args.get("edgeLabel", "");

                        # Get or create user's graph
                        all_graphs = [-->](`?user_graph_data);
                        user_graph = None;
                        for graph in all_graphs {
                            if hasattr(graph, 'username') and graph.username == self.username {
                                user_graph = graph;
                                break;
                            }
                        }
                        if user_graph is None {
                            user_graph = here ++> user_graph_data(username=self.username);
                        }
                        
                        # Update graph
                        if previous_task == "Start" and "Start" not in user_graph.nodes {
                            user_graph.nodes = user_graph.nodes + ["Start"];
                        }
                        if task_name and task_name not in user_graph.nodes {
                            user_graph.nodes = user_graph.nodes + [task_name];
                        }
                        if task_name and previous_task and not edge_exists(user_graph.edges, previous_task, task_name) {
                            new_edge = {"from": previous_task, "to": task_name};
                            if edge_label {
                                new_edge["label"] = edge_label;
                            }
                            user_graph.edges = user_graph.edges + [new_edge];
                        }
                        user_graph.last_task = task_name;
                        current_nodes = user_graph.nodes;
                        current_edges = user_graph.edges;
                        tool_output = {"success": True, "message": f"Updated graph with task: {task_name}"};
                        
                    } elif f_name == "askClarifyingQuestion" {
                        # Track question in user insights
                        all_insights = [-->](`?user_insights);
                        user_insight = None;
                        for insight in all_insights {
                            if hasattr(insight, 'username') and insight.username == self.username {
                                user_insight = insight;
                                break;
                            }
                        }
                        if user_insight is None {
                            user_insight = here ++> user_insights(username=self.username);
                        }
                        user_insight.total_interactions = user_insight.total_interactions + 1;
                        question_text = f_args.get("question", "");
                        if question_text {
                            user_insight.last_questions_asked = (user_insight.last_questions_asked + [question_text])[-10:];
                        }
                        tool_output = execute_local_tool(f_name, f_args, current_nodes, current_edges);
                        
                    } elif f_name == "analyzeRoutinePattern" {
                        tool_output = execute_local_tool(f_name, f_args, current_nodes, current_edges);
                        # Track identified patterns
                        if "analysis" in tool_output and "sequences" in tool_output["analysis"] {
                            all_insights = [-->](`?user_insights);
                            user_insight = None;
                            for insight in all_insights {
                                if hasattr(insight, 'username') and insight.username == self.username {
                                    user_insight = insight;
                                    break;
                                }
                            }
                            if user_insight is None {
                                user_insight = here ++> user_insights(username=self.username);
                            }
                            for seq in tool_output["analysis"]["sequences"] {
                                if seq not in user_insight.common_sequences {
                                    user_insight.common_sequences = user_insight.common_sequences + [seq];
                                }
                            }
                        }
                    } else {
                        tool_output = execute_local_tool(f_name, f_args, current_nodes, current_edges);
                    }

                    # Add function call and result to request body
                    call_id = tool_call["call_id"] if "call_id" in tool_call else "";
                    request_body["input"] = request_body["input"] + [
                        {"type": "function_call", "call_id": call_id, "name": f_name, "arguments": f_args_str},
                        {"type": "function_call_output", "call_id": call_id, "output": dumps(tool_output)}
                    ];
                }
                
                # Make follow-up request
                data = make_responses_api_call(request_body, api_key);
                output_items = data.get("output", []);
                iteration = iteration + 1;
            }
            
            # Extract and return final response
            final_response = extract_response_text(output_items);
            report {"response": final_response, "dotCode": "", "graphNodes": [], "graphEdges": []};
            
        } except HTTPError as e {
            error_msg = str(e);
            if hasattr(e, 'read') {
                error_msg = e.read().decode('utf-8');
            }
            report {"error": f"HTTP Error: {e.code}", "details": error_msg};
        } except URLError as e {
            report {"error": "URL Error", "details": str(e.reason)};
        } except Exception as e {
            report {"error": "Server error", "details": str(e)};
        }
    }
}
