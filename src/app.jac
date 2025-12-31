# Algo - Personal AI Assistant with Voice Interface
# Implements: Voice Agent (realtime) -> Backend Intelligence (gpt-4.1) -> Tools
# Calendar, Email, GitHub integration

import from os { getenv }
import from urllib.request { Request, urlopen }
import from urllib.error { URLError, HTTPError }
import from json { loads, dumps }
import from dotenv { load_dotenv }

# Load .env from project root (auto-discovers .env in cwd or parent dirs)
with entry {
    load_dotenv();
}
# ============================================
# Sample Data (Personal Assistant - Calendar, Emails, GitHub)
# ============================================

glob SAMPLE_CALENDAR_EVENTS = [
    {
        "id": "evt-001",
        "title": "Team Standup",
        "date": "2025-12-30",
        "time": "09:00 AM",
        "duration": "30 minutes",
        "location": "Zoom",
        "attendees": ["John", "Sarah", "Mike"]
    },
    {
        "id": "evt-002",
        "title": "Product Review Meeting",
        "date": "2025-12-30",
        "time": "02:00 PM",
        "duration": "1 hour",
        "location": "Conference Room A",
        "attendees": ["Product Team", "Engineering"]
    },
    {
        "id": "evt-003",
        "title": "1:1 with Manager",
        "date": "2025-12-31",
        "time": "10:00 AM",
        "duration": "30 minutes",
        "location": "Google Meet",
        "attendees": ["Alex (Manager)"]
    },
    {
        "id": "evt-004",
        "title": "New Year's Eve Party",
        "date": "2025-12-31",
        "time": "07:00 PM",
        "duration": "4 hours",
        "location": "Office Rooftop",
        "attendees": ["Entire Company"]
    }
];

glob SAMPLE_EMAILS = [
    {
        "id": "mail-001",
        "from": "alex.manager@company.com",
        "subject": "Q1 Planning - Action Items",
        "preview": "Hi, please review the attached Q1 roadmap and add your team's priorities by Friday...",
        "date": "2025-12-30",
        "unread": True,
        "important": True
    },
    {
        "id": "mail-002",
        "from": "github@notifications.github.com",
        "subject": "[jaseci/jac] PR #1234 merged",
        "preview": "Your pull request 'Add voice agent support' has been merged into main...",
        "date": "2025-12-30",
        "unread": True,
        "important": False
    },
    {
        "id": "mail-003",
        "from": "sarah@company.com",
        "subject": "Re: Design Review Feedback",
        "preview": "Thanks for the feedback! I've updated the mockups based on your suggestions...",
        "date": "2025-12-29",
        "unread": False,
        "important": False
    },
    {
        "id": "mail-004",
        "from": "newsletter@techweekly.com",
        "subject": "This Week in AI: Top Stories",
        "preview": "OpenAI announces new reasoning models, Google releases Gemini 2.0...",
        "date": "2025-12-29",
        "unread": False,
        "important": False
    }
];

glob SAMPLE_GITHUB_ISSUES = [
    {
        "id": "issue-101",
        "repo": "jaseci/jac",
        "number": 456,
        "title": "Voice agent connection timeout on slow networks",
        "state": "open",
        "author": "udithishanka",
        "assignee": "me",
        "labels": ["bug", "voice-agent"],
        "created": "2025-12-28",
        "comments": 3
    },
    {
        "id": "issue-102",
        "repo": "jaseci/jac",
        "number": 455,
        "title": "Add support for custom wake words",
        "state": "open",
        "author": "contributor42",
        "assignee": None,
        "labels": ["enhancement", "voice-agent"],
        "created": "2025-12-27",
        "comments": 7
    },
    {
        "id": "pr-201",
        "repo": "jaseci/jac",
        "number": 1234,
        "title": "Add voice agent support",
        "state": "merged",
        "type": "pr",
        "author": "me",
        "reviewers": ["alex", "sarah"],
        "created": "2025-12-25",
        "merged": "2025-12-30"
    }
];


# ============================================
# Supervisor Agent Instructions
# ============================================

glob SUPERVISOR_INSTRUCTIONS = """You are the backend intelligence for Algo, a personal AI assistant. You process requests from the voice interface and have access to the user's personal tools and data.

# Primary Task: Task Graph Generation
Your MOST IMPORTANT job is to track the user's tasks and activities as a directed graph.
- When the user mentions doing something (a task, activity, or action), you MUST call updateTaskGraph
- Extract the task name as a short label (2-4 words, CamelCase, no spaces)
- Connect it to the previous task to show the sequence of activities
- Examples: "I'm making coffee" → MakeCoffee, "going to wash my face" → WashFace, "checking emails" → CheckEmails

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
                    "description": "The previous task name to connect from. Use 'Start' for the first task. Must match a previously added task name."
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



# Global graph state for task tracking
glob TASK_GRAPH_NODES: list = [];
glob TASK_GRAPH_EDGES: list = [];

# Saved routines (persistent memory of past behavior)
glob SAVED_ROUTINES: dict = {};


# Helper function to generate DOT code from graph state
def generate_dot_code() -> str {
    if len(TASK_GRAPH_NODES) == 0 {
        return "";
    }
    
    lines = ["digraph TaskGraph {"];
    lines.append("  rankdir=TB;");
    lines.append("  node [shape=box, style=rounded, fontname=\"Arial\"];");
    lines.append("  edge [fontname=\"Arial\", fontsize=10];");
    lines.append("");
    
    # Add nodes with styling
    for node in TASK_GRAPH_NODES {
        if node == "Start" {
            lines.append("  " + node + " [shape=circle, style=filled, fillcolor=\"#22c55e\", fontcolor=white];");
        } else {
            lines.append("  " + node + " [style=\"rounded,filled\", fillcolor=\"#3b82f6\", fontcolor=white];");
        }
    }
    
    lines.append("");
    
    # Add edges
    for edge in TASK_GRAPH_EDGES {
        from_node = edge.get("from", "");
        to_node = edge.get("to", "");
        label = edge.get("label", "");
        if label {
            lines.append("  " + from_node + " -> " + to_node + " [label=\"" + label + "\"];");
        } else {
            lines.append("  " + from_node + " -> " + to_node + ";");
        }
    }
    
    lines.append("}");
    return "\n".join(lines);
}


# Helper function to execute a tool locally
def execute_local_tool(tool_name: str, tool_args: any) -> any {
    if tool_name == "updateTaskGraph" {
        # Add task to graph
        task_name = tool_args.get("taskName", "");
        previous_task = tool_args.get("previousTask", "Start");
        edge_label = tool_args.get("edgeLabel", "");
        
        # Add Start node if this is the first task
        if previous_task == "Start" and "Start" not in TASK_GRAPH_NODES {
            TASK_GRAPH_NODES.append("Start");
        }
        
        # Add the new task node if not already present
        if task_name and task_name not in TASK_GRAPH_NODES {
            TASK_GRAPH_NODES.append(task_name);
        }
        
        # Add edge from previous to current (check for duplicates first)
        if task_name and previous_task {
            # Check if this edge already exists
            edge_exists = False;
            for existing_edge in TASK_GRAPH_EDGES {
                if existing_edge.get("from") == previous_task and existing_edge.get("to") == task_name {
                    edge_exists = True;
                    break;
                }
            }
            
            # Only add if edge doesn't exist
            if not edge_exists {
                new_edge = {"from": previous_task, "to": task_name};
                if edge_label {
                    new_edge["label"] = edge_label;
                }
                TASK_GRAPH_EDGES.append(new_edge);
            }
        }
        
        # Generate updated DOT code
        dot_code = generate_dot_code();
        
        return {
            "success": True,
            "message": f"Added task '{task_name}' connected from '{previous_task}'",
            "dotCode": dot_code,
            "nodes": TASK_GRAPH_NODES,
            "edges": TASK_GRAPH_EDGES
        };
    } elif tool_name == "getCalendarEvents" {
        # Filter by date if provided
        date_filter = tool_args.get("date", "today");
        # For demo, return all events (in real app, would filter by date)
        return {"events": SAMPLE_CALENDAR_EVENTS, "query": date_filter};
    } elif tool_name == "getEmails" {
        # Filter emails based on parameters
        filter_type = tool_args.get("filter", "all");
        count = tool_args.get("count", 5);
        emails = SAMPLE_EMAILS[:count];
        if filter_type == "unread" {
            emails = [e for e in SAMPLE_EMAILS if e.get("unread")][:count];
        } elif filter_type == "important" {
            emails = [e for e in SAMPLE_EMAILS if e.get("important")][:count];
        }
        return {"emails": emails, "filter": filter_type};
    } elif tool_name == "getGitHubIssues" {
        # Filter GitHub issues
        filter_type = tool_args.get("filter", "all");
        issue_type = tool_args.get("type", "all");
        issues = SAMPLE_GITHUB_ISSUES;
        if filter_type == "open" {
            issues = [i for i in issues if i.get("state") == "open"];
        } elif filter_type == "assigned" {
            issues = [i for i in issues if i.get("assignee") == "me"];
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
        if item.get("type") == "message" {
            content_arr = item.get("content", []);
            for c in content_arr {
                if c.get("type") == "output_text" {
                    final_text = final_text + c.get("text", "");
                }
            }
        }
    }
    return final_text;
}

# Helper function to make OpenAI Responses API call
def make_responses_api_call(request_body: dict, api_key: any) -> any {
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
    return loads(response.read().decode('utf-8'));
}

# Walker to call the Supervisor Agent (gpt-4.1 via Responses API)
walker call_supervisor {
    has conversation_history: list;
    has context_from_user: str;
    
    can call with `root entry {
        try {
            api_key = getenv("OPENAI_API_KEY");
            
            if not api_key {
                report {"error": "OPENAI_API_KEY not set"};
                return;
            }
            
            # Load past routines for context
            past_routines_context = "";
            if len(SAVED_ROUTINES) > 0 {
                past_routines_context = f"""
                
==== Past Learned Routines ====
{dumps(SAVED_ROUTINES, indent=2)}

Use this information to make intelligent suggestions based on the user's past behavior.
""";
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
                        Existing Nodes: {dumps(TASK_GRAPH_NODES)}
                        Existing Edges: {dumps(TASK_GRAPH_EDGES)}
                        {past_routines_context}
                        
                        IMPORTANT: When adding a new task, use the EXACT node name from the existing nodes as previousTask if the user mentions connecting to an existing task.
                        """
                    }
                ],
                "tools": SUPERVISOR_TOOLS,
                "parallel_tool_calls": False
            };
            
            # Make initial API call
            data = make_responses_api_call(request_body, api_key);
            output_items = data.get("output", []);
            
            # Process tool calls iteratively (up to 5 rounds)
            max_iterations = 5;
            iteration = 0;
            
            while iteration < max_iterations {
                # Check for function calls
                function_calls = [];
                for item in output_items {
                    if item.get("type") == "function_call" {
                        function_calls.append(item);
                    }
                }
                
                if len(function_calls) == 0 {
                    # No more function calls - extract final response
                    break;
                }
                
                # Execute function calls
                for tool_call in function_calls {
                    f_name = tool_call.get("name");
                    f_args_str = tool_call.get("arguments", "{}");
                    f_args = loads(f_args_str);
                    
                    # Execute the tool locally
                    tool_output = execute_local_tool(f_name, f_args);
                    
                    # Add function call and result to the request body
                    request_body["input"].append({
                        "type": "function_call",
                        "call_id": tool_call.get("call_id"),
                        "name": f_name,
                        "arguments": f_args_str
                    });
                    request_body["input"].append({
                        "type": "function_call_output",
                        "call_id": tool_call.get("call_id"),
                        "output": dumps(tool_output)
                    });
                }
                
                # Make follow-up request
                data = make_responses_api_call(request_body, api_key);
                output_items = data.get("output", []);
                iteration = iteration + 1;
            }
            
            # Extract final text
            final_response = extract_response_text(output_items);
            
            # Get current graph state
            current_dot_code = generate_dot_code();
            
            report {
                "response": final_response,
                "dotCode": current_dot_code,
                "graphNodes": TASK_GRAPH_NODES,
                "graphEdges": TASK_GRAPH_EDGES
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


# Walker to save the current graph as a learned routine
walker save_routine {
    has routine_name: str = "daily_routine";
    
    can save with `root entry {
        try {
            # Save current graph state
            SAVED_ROUTINES[self.routine_name] = {
                "nodes": TASK_GRAPH_NODES.copy(),
                "edges": TASK_GRAPH_EDGES.copy(),
                "saved_at": str(__import__('datetime').datetime.now())
            };
            
            report {
                "success": True,
                "message": f"Saved routine '{self.routine_name}' with {len(TASK_GRAPH_NODES)} tasks",
                "routine": SAVED_ROUTINES[self.routine_name]
            };
        } except Exception as e {
            report {"error": "Failed to save routine", "details": str(e)};
        }
    }
}


# Walker to load past routines for context
walker load_past_routines {
    can load with `root entry {
        try {
            if len(SAVED_ROUTINES) == 0 {
                report {"routines": {}, "message": "No past routines saved yet"};
                return;
            }
            
            # Return saved routines for context
            report {
                "routines": SAVED_ROUTINES,
                "count": len(SAVED_ROUTINES),
                "message": f"Loaded {len(SAVED_ROUTINES)} saved routine(s)"
            };
        } except Exception as e {
            report {"error": "Failed to load routines", "details": str(e)};
        }
    }
}


# Walker to reset the current session graph
walker reset_session {
    can reset with `root entry {
        try {
            # Clear current graph but keep saved routines
            TASK_GRAPH_NODES.clear();
            TASK_GRAPH_EDGES.clear();
            
            report {
                "success": True,
                "message": "Session reset. Ready for a new conversation."
            };
        } except Exception as e {
            report {"error": "Failed to reset session", "details": str(e)};
        }
    }
}


# ============================================
# Frontend - Client-side React Components
# ============================================

