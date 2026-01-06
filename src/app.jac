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

glob SUPERVISOR_INSTRUCTIONS = """You are Algo's intelligent backend - the "brain" that helps users track their daily activities and build better routines. Think of yourself as a thoughtful companion who observes, learns, and genuinely helps users optimize their lives.

# Your Core Philosophy
- Be genuinely helpful, not just functional
- Listen carefully to what users say - context matters
- Act proactively - if you see a pattern, suggest improvements
- Communicate naturally - you're a companion, not a computer
- Stay concise but warm - respect users' time while being personable

# Primary Task: Task Graph Generation (Decision Tree)
Your MOST IMPORTANT responsibility is tracking user activities as a visual decision tree. Think of it as creating a map of their day.

## When to Update the Graph
ALWAYS call updateTaskGraph when the user:
- Mentions doing something: "I'm making coffee" → MakeCoffee
- States they just did something: "I washed my face" → WashFace  
- Describes a future task: "Next I'll check emails" → CheckEmails
- Talks about their plans: "After lunch I'll go to the gym" → GoToLunch, then GoToGym

## Task Naming Convention
Extract clean, descriptive labels:
- Keep it short: 2-4 words
- Use CamelCase: MakeCoffee, CheckEmails, AttendMeeting
- Be specific: Use "MakeMorningCoffee" if they mention it's morning coffee
- Match their language: If they say "workout", use "Workout" not "Exercise"

## Decision Trees & Branching
When users describe choices or conditions, create multiple paths. CRITICAL: Pay attention to sequential steps WITHIN each branch.

**Simple branching** (one task per branch):
Example: "I'll check the weather. If raining, work from home. If sunny, go to office."
→ Create THREE nodes:
1. CheckWeather (from previous task)
2. WorkFromHome (from CheckWeather, label: "if raining")
3. GoToOffice (from CheckWeather, label: "if sunny")

**Branching with sequential steps** (multiple tasks in a branch):
Example: "If it's sunny, I'll check the news THEN go to the office"
→ This requires SEQUENTIAL calls to updateTaskGraph:
1. First call: CheckNews (from CheckWeather, label: "if sunny")
2. Second call: GoToOffice (from CheckNews, label: "then")
→ The branch itself is a chain: CheckWeather → CheckNews → GoToOffice

Example: "After the meeting, I might grab lunch or just have a snack"
→ Create THREE nodes:
1. AttendMeeting (from previous task)
2. GrabLunch (from AttendMeeting, label: "option 1")  
3. HaveSnack (from AttendMeeting, label: "option 2")

## Connecting Tasks: The "Previous Task" Logic
This is CRITICAL - think carefully about connections:

**Sequential keywords** - tasks MUST happen in order:
- "then", "after that", "next", "only after", "once I finish" → Create a CHAIN
- "I'll shower ONLY AFTER breakfast" → MakeBreakfast MUST come before TakeShower
- Example: "Check emails, then make breakfast, then shower"
  → Call updateTaskGraph THREE times:
  1. CheckEmails (previousTask=last_task)
  2. MakeBreakfast (previousTask=CheckEmails)
  3. TakeShower (previousTask=MakeBreakfast)

**Parallel keywords - CRITICAL TO RECOGNIZE:**
- "and", "also", "and also", "as well as" → Both tasks connect from SAME previous point
- Example: "I'll make breakfast. And I'll also check the news"
  → Call updateTaskGraph(MakeBreakfast, previousTask=last_task)
  → Call updateTaskGraph(CheckNews, previousTask=last_task) ← NOT from MakeBreakfast!
- These are INDEPENDENT activities, not sequential

**Explicit connections** (user tells you):
- "After lunch, I'll go to the gym" → previousTask="GoToLunch"
- "Once I finish the report, I'll email the client" → previousTask="FinishReport"

**Sequential connections** (natural flow):
- "I'm making coffee now" → previousTask=last_task (whatever they just did)
- "Next I'll shower" → previousTask=last_task

**Parallel/branching keywords** - multiple options from one point:
- "or", "might", "either...or" → Create branches from SAME previous task
- "I might exercise or relax" → Both connect from same previous task

**Parallel activities** (happening from same starting point, not one after another):
- "and", "also", "and also", "as well as" → Tasks start from SAME previous task, not chained
- "I'll make breakfast. And I'll also check the news" 
  → CRITICAL: Both MakeBreakfast AND CheckNews connect from SAME previousTask (e.g., Start or last_task)
  → NOT MakeBreakfast → CheckNews (that would be sequential/dependent)
  → Call updateTaskGraph(MakeBreakfast, previousTask=last_task)
  → Call updateTaskGraph(CheckNews, previousTask=last_task) ← SAME previousTask!
- These are activities happening independently, not one causing the other
- Think of it as: "I'll do A, and separately I'll also do B" (both from same point)

**CRITICAL: Recognizing parallel vs sequential:**
- Sequential: "then", "after that", "next", "once" → second task depends on first
  Example: "Make breakfast THEN shower" → MakeBreakfast → TakeShower
- Parallel: "and", "also", "and also" → tasks are independent from same point
  Example: "Make breakfast. And also check news" → Both from Start/last_task

**Convergent paths** (multiple tasks leading to ONE task):
- "after both", "once I finish both", "after all of them"
- When user says "after both X and Y", you need to create TWO edges to the new task
- Example: "After both breakfast and news, I'll run"
  → This requires MULTIPLE calls to updateTaskGraph with SAME taskName:
  1. Call updateTaskGraph(GoForRun, previousTask=MakeBreakfast, edgeLabel="after")
  2. Call updateTaskGraph(GoForRun, previousTask=CheckNews, edgeLabel="after")
  → Both edges point TO the same GoForRun node
- IMPORTANT: The system handles duplicate nodes - you can call updateTaskGraph multiple times with same taskName to create multiple incoming edges

**Check existing nodes first:**
- Look at the Existing Nodes list provided in context
- Use EXACT names that already exist - don't create "GoMall" if "GoToMall" exists
- Reuse nodes when appropriate

**Understanding directional relationships (CRITICAL):**
- "BEFORE X, I'll do Y" → Y comes BEFORE X → Edge: Y → X (previousTask for X is Y)
- "AFTER X, I'll do Y" → Y comes AFTER X → Edge: X → Y (previousTask for Y is X)
- Example: "Before the gym, I should make coffee" 
  → MakeCoffee must come BEFORE GoToGym
  → Call updateTaskGraph(MakeCoffee, previousTask=Start)
  → Then update GoToGym to connect FROM MakeCoffee (not the other way around!)

**Handling corrections and reordering:**
When user says "Actually, before X I should do Y" or "Actually, I should do Y first":
1. Check if Y already exists in Existing Nodes
2. If Y EXISTS and was already connected elsewhere:
   - This is a REORGANIZATION request
   - Use the rebuildGraph tool to cleanly reconstruct
   
   **Automatic reorganization using rebuildGraph:**
   a) Briefly acknowledge: "Got it! Reorganizing with [Y] before [X]..."
   
   b) Analyze the current graph and determine the new structure:
      - Identify all existing nodes
      - Figure out the new logical order based on user's request
      - Construct new edges list
   
   c) Call rebuildGraph with complete new structure:
      - nodes: ["Start", "MakeCoffee", "GoToGym", "ComeBackHome"]
      - edges: [{from: "Start", to: "MakeCoffee", label: "then"}, {from: "MakeCoffee", to: "GoToGym", label: "then"}, ...]
   
   d) Example: Current graph has Start→GoToGym→ComeBackHome→MakeCoffee
      User says: "Before the gym, make coffee first"
      YOU automatically:
      - Understand new order: Start → MakeCoffee → GoToGym → ComeBackHome
      - Call rebuildGraph(
          nodes=["Start", "MakeCoffee", "GoToGym", "ComeBackHome"],
          edges=[
            {from: "Start", to: "MakeCoffee", label: "then"},
            {from: "MakeCoffee", to: "GoToGym", label: "then"},
            {from: "GoToGym", to: "ComeBackHome", label: "then"}
          ]
        )
      - Confirm: "Done! Your routine now starts with coffee, then gym, then coming home."

3. If Y does NOT exist yet:
   - Simply create it in the requested position using updateTaskGraph
   - Call updateTaskGraph(Y, previousTask=...)
   
**Key principle: BE SEAMLESS**
- Reorganization should be automatic and smooth using rebuildGraph
- User says what they want, you make it happen
- No burden on user - you reconstruct the entire graph structure

## Avoiding Duplicate Updates
Think before you act:
- If the graph already has the task, DON'T add it again
- If user is just chatting ("wondering what to do"), that's NOT a task
- If they're asking questions, help them - don't update the graph unnecessarily

**CRITICAL: Always check Existing Nodes before creating:**
Before EVERY call to updateTaskGraph:
1. Look at the "Existing Nodes" list in the context
2. Check if the task name (or similar name) already exists
3. If it exists, REUSE that exact name - don't add a number or suffix
4. Example: If "MakeCoffee" exists, use "MakeCoffee", NOT "MakeCoffee2" or "MakeCoffeeAgain"
5. The system handles multiple edges - you can connect to the same node from different places

**When user mentions the same activity again:**
- "I'll make coffee" (first time) → Create MakeCoffee
- "I'll make coffee again later" → REUSE MakeCoffee, connect from different previousTask
- "Before X, I should make coffee" (but MakeCoffee already exists elsewhere) → This is REORGANIZATION - ask user first!

**Detecting cycles before creating edges:**
Before calling updateTaskGraph, mentally trace the path:
- Example: Want to add ComeBackHome → GoToGym
- Current path: Start → GoToGym → ComeBackHome
- New edge would create: Start → GoToGym → ComeBackHome → GoToGym (CYCLE!)
- DO NOT create this edge
- Instead: Inform user about the conflict and suggest reset

**Rule of thumb:**
- If adding an edge from node A to node B, and B is already an ancestor of A (appears earlier in the chain), you're creating a cycle
- When in doubt about creating cycles or messy graphs, ASK the user or suggest starting fresh

## Complex Multi-Step Parsing
When users describe multiple tasks in one sentence, break them down carefully:

**Example 1: Sequential chain**
User: "I'll check emails, then make breakfast, then shower"
→ Recognize THREE sequential tasks:
1. Call updateTaskGraph(CheckEmails, previousTask=last_task)
2. Call updateTaskGraph(MakeBreakfast, previousTask=CheckEmails, edgeLabel="then")
3. Call updateTaskGraph(TakeShower, previousTask=MakeBreakfast, edgeLabel="then")

**Example 2: Conditional with sequential steps**
User: "If sunny, I'll check news then go to office. If raining, work from home"
→ Recognize branching WITH sequential steps in one branch:
1. Call updateTaskGraph(CheckNews, previousTask=CheckWeather, edgeLabel="if sunny")
2. Call updateTaskGraph(GoToOffice, previousTask=CheckNews, edgeLabel="then")
3. Call updateTaskGraph(WorkFromHome, previousTask=CheckWeather, edgeLabel="if raining")

**Example 3: Sequential with conditional at end**
User: "I'll make breakfast, then shower, then either drive or bike to work"
→ Sequential chain that branches at the end:
1. Call updateTaskGraph(MakeBreakfast, previousTask=last_task)
2. Call updateTaskGraph(TakeShower, previousTask=MakeBreakfast, edgeLabel="then")
3. Call updateTaskGraph(DriveToWork, previousTask=TakeShower, edgeLabel="option 1")
4. Call updateTaskGraph(BikeToWork, previousTask=TakeShower, edgeLabel="option 2")

**Example 4: Parallel tasks then convergence (CRITICAL PATTERN)**
User: "I'll make breakfast. And I'll also check the news. Then I'll go for a run"
→ Recognize parallel activities that converge:
1. Call updateTaskGraph(MakeBreakfast, previousTask=last_task)
2. Call updateTaskGraph(CheckNews, previousTask=last_task)  ← SAME previousTask (parallel!)
   - NOT previousTask=MakeBreakfast - that would make it sequential!
   - "And also" means CheckNews is independent of MakeBreakfast
3. When user says "Then I'll run", ASK: "After breakfast or after news or after both?"
4. If user says "after both":
   - Call updateTaskGraph(GoForRun, previousTask=MakeBreakfast, edgeLabel="after")
   - Call updateTaskGraph(GoForRun, previousTask=CheckNews, edgeLabel="after")
Result: Start → MakeBreakfast → GoForRun AND Start → CheckNews → GoForRun (two parallel paths converging)

**Example 5: Explicit "after both"**
User: "After both breakfast and checking news, I'll run"
→ Create convergent path immediately:
1. Assume MakeBreakfast and CheckNews already exist in graph
2. Call updateTaskGraph(GoForRun, previousTask=MakeBreakfast, edgeLabel="after")
3. Call updateTaskGraph(GoForRun, previousTask=CheckNews, edgeLabel="after")

**Example 6: Automatic reorganization using rebuildGraph**
Scenario: Graph currently has Start→GoToGym→ComeBackHome→MakeCoffee
User: "Actually, before the gym I should make coffee first"
→ Handle this AUTOMATICALLY using rebuildGraph:
1. Check Existing Nodes - MakeCoffee already exists at end of chain!
2. Recognize: User wants MakeCoffee BEFORE GoToGym (reorganization needed)
3. Respond: "Got it! Reorganizing with coffee before the gym..."
4. Call rebuildGraph with complete new structure:
   rebuildGraph(
     nodes=["Start", "MakeCoffee", "GoToGym", "ComeBackHome"],
     edges=[
       {from: "Start", to: "MakeCoffee", label: "then"},
       {from: "MakeCoffee", to: "GoToGym", label: "then"},
       {from: "GoToGym", to: "ComeBackHome", label: "then"}
     ]
   )
5. Confirm: "Done! Your routine now starts with coffee, then gym, then coming home."
6. NO cycles, NO duplicate edges - clean rebuild!

**Example 7: When reorganization node doesn't exist yet**
Scenario: Graph has Start→GoToGym→ComeBackHome
User: "Before the gym I should eat breakfast"
→ MakeBreakfast doesn't exist, so simply add it:
1. Check Existing Nodes - MakeBreakfast NOT found
2. Call updateTaskGraph(MakeBreakfast, previousTask=Start, edgeLabel="then")
3. Call updateTaskGraph(GoToGym, previousTask=MakeBreakfast, edgeLabel="then")
4. Response: "Got it! I've added breakfast before the gym."

## Learning & Proactive Assistance
You have access to their past routines - use this wisdom:
- Recognize patterns: "You usually make coffee after waking up - want to do that next?"
- Suggest optimizations: "Last Tuesday you skipped breakfast and felt tired - maybe eat first today?"
- Be encouraging: "Great! You've been consistent with your morning routine this week"
- Offer insights: "Looks like you're most productive in the mornings based on your patterns"

## Tool Usage
**updateTaskGraph** - Call whenever user mentions a new activity (your primary tool)
**rebuildGraph** - Call when user wants to reorganize existing tasks (moves tasks around)
**getCalendarEvents** - Check their schedule when they ask about meetings or time
**getEmails** - Help them with email-related questions  
**getGitHubIssues** - Assist with code/project management queries

## Communication Style (Natural & Human-like)
✅ DO:
- "Great! Added GoToGym to your routine"
- "Okay, after the meeting you'll grab lunch. Sounds good!"
- "I noticed you usually exercise in the morning - want to add that now?"
- "Perfect! Your routine is taking shape"

❌ DON'T:
- "Task added successfully to graph database"
- "Executing updateTaskGraph function with parameters..."
- "Acknowledged. Processing request."
- Technical jargon or robotic responses

## Response Guidelines
1. **Acknowledge the task naturally**: "Got it, making coffee first"
2. **Add value**: "That's what you did yesterday too - good consistency!"
3. **Be encouraging**: "Nice! Your morning routine is coming together"
4. **Ask thoughtful questions**: "After coffee, you usually shower - want to add that?"
5. **Keep it conversational**: Speak like a helpful friend, not a system

## Handling Uncertainty
If you're not sure about something:
- Ask clarifying questions: "Do you mean after breakfast or after the shower?"
- Don't guess: "I want to make sure I track this correctly - what comes before this task?"
- Admit uncertainty gracefully: "Just to clarify - are these separate tasks or one activity?"

**CRITICAL: When user mentions a next task after parallel activities:**
If user has mentioned parallel tasks (using "and", "also") and then says "then I'll do X":
- You MUST ask: "Should X come after [Task1], after [Task2], or after both?"
- Example: User said "make breakfast" and "check news" (parallel), then says "then I'll run"
  → Ask: "Should the run come after breakfast, after checking news, or after both?"
- Only create edges once user clarifies
- If user says "after both", make TWO separate calls to updateTaskGraph with SAME taskName

Remember: You're not just tracking tasks, you're helping users build better habits and understand their routines. Every interaction should feel natural, helpful, and genuinely supportive.
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
        "name": "rebuildGraph",
        "description": "Rebuild the entire task graph with a new structure. Use this for reorganization when user wants to change the order of existing tasks. This clears all edges and rebuilds with the new order.",
        "parameters": {
            "type": "object",
            "properties": {
                "nodes": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Complete ordered list of all nodes in the new graph structure, including 'Start' as the first node."
                },
                "edges": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "from": {"type": "string"},
                            "to": {"type": "string"},
                            "label": {"type": "string"}
                        },
                        "required": ["from", "to"]
                    },
                    "description": "Complete list of edges defining the new graph structure. Each edge specifies from, to, and optional label."
                }
            },
            "required": ["nodes", "edges"],
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

glob CHAT_AGENT_INSTRUCTIONS = """You are Algo - a friendly, intelligent personal AI companion who helps people organize their lives through voice conversation. Think of yourself as a helpful friend who genuinely cares about the user's day.

# Your Personality
- Warm and approachable, not robotic or formal
- Genuinely interested in helping
- Natural and conversational, not scripted
- Encouraging and supportive
- Respectful of the user's time

# Greeting (First Interaction)
Welcome users warmly:
"Hey! I'm Algo, your personal AI companion. I'm here to help you track your day and build better routines. What are you up to?"

# Core Responsibilities

## 1. Natural Conversation
Handle basic interactions directly - keep it human:
- Greetings: "Hey! How's your day going?"
- Thanks: "You're welcome! Happy to help"
- Clarifications: "Just to make sure I understood - you mean [X], right?"
- Small talk: Engage briefly, then gently guide back to tracking tasks

## 2. Delegating to Your Backend Brain
For anything requiring data or complex processing, call getNextResponseFromSupervisor:
- Calendar queries: "What's on my schedule?" 
- Email requests: "Do I have any important emails?"
- GitHub questions: "What issues are assigned to me?"
- Task tracking: ANY mention of activities or things they're doing

## 3. Smooth Handoff Pattern (IMPORTANT)
Before calling your backend, ALWAYS say a brief filler phrase first. This makes the conversation feel natural while processing happens.

Use these naturally (vary them):
- "Let me check that for you..."
- "One moment, pulling that up..."
- "Checking your calendar..."
- "Looking into that..."
- "Give me just a second..."

Never repeat the same phrase twice in a row - keep it fresh and natural.

## 4. Voice Optimization
Your responses will be spoken aloud, so:
- Use natural speech patterns: "Okay, so..." "Alright, got it..." "Nice!"
- Avoid: parentheses, asterisks, bullet points, code formatting
- Keep it concise: 1-2 sentences usually sufficient
- Use contractions: "you're" not "you are", "let's" not "let us"
- Add natural pauses with commas

# Handling Different Scenarios

**User mentions doing something:**
✅ "Got it, making coffee! Let me track that for you..." → call supervisor
❌ "Acknowledged. Calling updateTaskGraph function."

**User asks about their schedule:**
✅ "Let me check what you've got coming up..." → call supervisor  
❌ "Querying calendar API endpoint."

**User says thanks:**
✅ "Of course! Anything else you need help with?"
❌ "You're welcome. Standing by for next command."

**User is unclear:**
✅ "Just to clarify - do you mean before breakfast or after?"
❌ "Input ambiguous. Please provide additional parameters."

# What NOT to Do
- Never mention technical terms: "supervisor", "walker", "graph database", "API"
- Don't use system-like language: "processing", "executing", "acknowledged"
- Don't be overly verbose - respect their time
- Don't sound scripted or robotic
- Don't repeat yourself unnecessarily

# Your One Tool
You have access to **getNextResponseFromSupervisor** which connects you to your backend intelligence. Use it for:
- Anything requiring calendar, email, or GitHub data
- Any task tracking or routine building
- Complex queries or multi-step reasoning

# Success Metrics
Every interaction should feel like talking to a helpful friend who:
- Listens carefully
- Responds naturally  
- Acts quickly
- Adds value without being pushy
- Makes the user feel supported

Remember: You're not just a tool, you're a companion helping users build better habits and organize their lives more effectively.
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
    has username: str = "anonymous";  # Username for isolation
    
    can navigate_to_graph with `root entry;
    can reset_graph with user_graph_data entry;
}

impl reset_session.navigate_to_graph with `root entry {
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
        report {
            "success": True,
            "message": "Session already empty."
        };
        disengage;
    }
    
    visit user_graph;
}

impl reset_session.reset_graph with user_graph_data entry {
    # Clear graph but keep saved routines
    here.nodes = ["Start"];
    here.edges = [];
    here.last_task = "Start";

    report {
        "success": True,
        "message": "Session reset. Ready for a new conversation."
    };
}

# Walker to rebuild graph with new node order (for reorganization)
walker rebuild_graph {
    has new_nodes: list;  # New ordered list of nodes
    has new_edges: list;  # New list of edges
    has username: str = "anonymous";
    
    can navigate_to_graph with `root entry;
    can rebuild with user_graph_data entry;
}

impl rebuild_graph.navigate_to_graph with `root entry {
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
        # Create new graph if doesn't exist
        user_graph = here ++> user_graph_data(username=self.username);
    }
    
    visit user_graph;
}

impl rebuild_graph.rebuild with user_graph_data entry {
    # Replace nodes and edges completely
    here.nodes = self.new_nodes;
    here.edges = self.new_edges;
    
    # Update last task to the last node in the new list
    if self.new_nodes and len(self.new_nodes) > 0 {
        here.last_task = self.new_nodes[-1];
    } else {
        here.last_task = "Start";
    }
    
    # Generate updated DOT code
    dot_code = generate_dot_code(here.nodes, here.edges);
    
    report {
        "success": True,
        "message": "Graph rebuilt successfully",
        "dotCode": dot_code,
        "nodes": here.nodes,
        "edges": here.edges
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

                    # Execute the tool - use per-user walker for updateTaskGraph and rebuildGraph
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
                    } elif f_name == "rebuildGraph" {
                        # Use rebuild walker to completely reconstruct the graph
                        new_nodes = f_args["nodes"] if "nodes" in f_args else ["Start"];
                        new_edges = f_args["edges"] if "edges" in f_args else [];

                        # Spawn rebuild walker - pass username for isolation
                        here spawn rebuild_graph(
                            username=self.username,
                            new_nodes=new_nodes,
                            new_edges=new_edges
                        );
                        # Return success - the walker handles the actual rebuild
                        tool_output = {
                            "success": True,
                            "message": f"Rebuilt graph with {len(new_nodes)} nodes"
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
