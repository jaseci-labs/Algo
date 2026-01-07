# =============================================================
#                    SEMANTIC TYPE DEFINITIONS
# =============================================================

import from byllm.lib { Model }

# Initialize LLM model for semantic functions
glob llm = Model(model_name="gpt-4o");

"""Represents the emotional state detected from user's message"""
obj EmotionalState {
    has state: str;
    has confidence: float;
    has reasoning: str;
}

sem EmotionalState.state = "User's current emotional state: stressed, excited, indecisive, fatigued, or neutral";
sem EmotionalState.confidence = "Confidence score between 0.0 and 1.0";
sem EmotionalState.reasoning = "Brief explanation of why this state was detected";

"""Task decision - whether to create a task or not"""
enum TaskDecision {
    CREATE_TASK,
    ASK_QUESTION,
    THINKING_ALOUD,
    UNCERTAIN
}

"""Represents a task connection type in the graph"""
enum ConnectionType {
    SEQUENTIAL,
    PARALLEL,
    CONDITIONAL,
    CONVERGENT
}

"""Task relationship analysis"""
obj TaskRelationship {
    has connection_type: ConnectionType;
    has previous_task: str;
    has new_task: str;
    has edge_label: str;
    has reasoning: str;
}

sem TaskRelationship.connection_type = "Type of connection: SEQUENTIAL (then/after), PARALLEL (and/also), CONDITIONAL (if/or), CONVERGENT (after both)";
sem TaskRelationship.previous_task = "The task this should connect FROM (exact node name from existing graph)";
sem TaskRelationship.new_task = "The new task name in CamelCase (e.g., MakeCoffee, GoToGym)";
sem TaskRelationship.edge_label = "Label for the edge (e.g., 'then', 'if sunny', 'option 1', 'after')";
sem TaskRelationship.reasoning = "Brief explanation of why this connection type was chosen";

"""Supervisor decision about what action to take"""
obj SupervisorDecision {
    has should_update_graph: bool;
    has task_decision: TaskDecision;
    has task_relationships: list[TaskRelationship];
    has response_to_user: str;
    has show_reasoning: bool;
}

sem SupervisorDecision.should_update_graph = "True only if user COMMITTED to an action, false for questions or thinking aloud";
sem SupervisorDecision.task_decision = "Classification of user's intent: CREATE_TASK, ASK_QUESTION, THINKING_ALOUD, or UNCERTAIN";
sem SupervisorDecision.task_relationships = "List of task relationships to create (empty if no tasks to add)";
sem SupervisorDecision.response_to_user = "Natural, friendly response as Algo the AI companion";
sem SupervisorDecision.show_reasoning = "True for complex decisions requiring explanation with emoji markers (🤔📊💡⚖️✅)";

# =============================================================
#                  SEMANTIC AI FUNCTIONS
# =============================================================

"""Detect the user's emotional state from their message and conversation context"""
def detect_emotional_state(
    user_message: str,
    conversation_history: list[dict]
) -> EmotionalState by llm();

sem detect_emotional_state = """
Analyze the user's message and recent conversation to detect their emotional state.

Stress signals: short responses, frustration keywords, overwhelm, "too much"
Excitement signals: exclamation marks, positive language, accomplishment mentions
Indecision signals: questions about choices, "maybe", "not sure", uncertainty
Fatigue signals: mentions tired/exhausted, late hours, wanting to rest
Neutral: normal conversational tone without strong emotional markers

Return confidence 0.0-1.0 based on clarity of signals.
""";

"""Determine if user is committing to a task or just asking/thinking"""
def analyze_task_commitment(
    user_message: str,
    existing_nodes: list[str],
    last_task: str,
    conversation_context: str
) -> SupervisorDecision by llm();

sem analyze_task_commitment = """
Analyze if the user is COMMITTING to an action or just discussing possibilities.

CREATE_TASK - User has made a commitment:
✅ "I'll exercise", "I'm making coffee", "Going to the gym"
✅ "Next I'll shower", "After that I'll eat breakfast"
✅ "I'm going to...", "I'll do...", "Let me..."

ASK_QUESTION - User is asking, not committing:
❌ "Should I exercise?", "What should I do next?"
❌ "Is it better to... or ...?"

THINKING_ALOUD - User is contemplating:
❌ "I'm thinking about what to do"
❌ "Wondering if I should..."

UNCERTAIN - User expressed uncertainty:
❌ "Maybe I'll...", "I might..."
❌ "Not sure if I should..."

CRITICAL RULES:
1. Only set should_update_graph=true for CREATE_TASK
2. Check existing_nodes list - reuse exact names if task exists
3. Use last_task as default previousTask for sequential activities
4. For parallel activities ("and", "also"), use SAME previous_task for both
5. For "after both X and Y", create CONVERGENT with two relationships

Set show_reasoning=true only for complex decisions with multiple options.
""";

"""Parse task relationships from user's message"""
def parse_task_relationships(
    user_message: str,
    existing_nodes: list[str],
    last_task: str
) -> list[TaskRelationship] by llm();

sem parse_task_relationships = """
Extract ALL task relationships from the message with correct connection types.

CONNECTION PATTERNS:

SEQUENTIAL ("then", "after that", "next", "only after", "first...then"):
- Chain tasks: A → B → C
- Example: "Make coffee then shower" 
  → [{connection_type: SEQUENTIAL, previous_task: last_task, new_task: "MakeCoffee"},
     {connection_type: SEQUENTIAL, previous_task: "MakeCoffee", new_task: "TakeShower"}]

PARALLEL ("and", "also", "and also", "as well as"):
- Tasks start from SAME point, NOT chained
- Example: "Make coffee. And also check news"
  → [{connection_type: PARALLEL, previous_task: last_task, new_task: "MakeCoffee"},
     {connection_type: PARALLEL, previous_task: last_task, new_task: "CheckNews"}]

CONDITIONAL ("if", "or", "either...or", "might"):
- Branches from same decision point
- Example: "If sunny, go outside. If rainy, stay home"
  → [{connection_type: CONDITIONAL, previous_task: "CheckWeather", new_task: "GoOutside", edge_label: "if sunny"},
     {connection_type: CONDITIONAL, previous_task: "CheckWeather", new_task: "StayHome", edge_label: "if rainy"}]

CONVERGENT ("after both", "once both done"):
- Multiple paths converge to ONE task (create multiple relationships with SAME new_task)
- Example: "After both breakfast and news, I'll run"
  → [{connection_type: CONVERGENT, previous_task: "MakeBreakfast", new_task: "GoForRun", edge_label: "after"},
     {connection_type: CONVERGENT, previous_task: "CheckNews", new_task: "GoForRun", edge_label: "after"}]

CRITICAL:
- Check existing_nodes and reuse exact names (don't create "GoGym" if "GoToGym" exists)
- Use CamelCase for new task names (MakeCoffee, CheckEmails, GoToGym)
- Be specific with edge_label for clarity ("then", "if sunny", "option 1", etc.)
""";

"""Generate a natural, conversational response matching user's emotional state"""
def generate_friendly_response(
    user_message: str,
    emotional_state: EmotionalState,
    action_taken: str,
    task_names: list[str]
) -> str by llm();

sem generate_friendly_response = """
Generate a warm, natural response as Algo, the AI companion.

MATCH EMOTIONAL STATE:
- Stressed → Calm, supportive, offer structure: "I can see why you're feeling overwhelmed. Let's break this down..."
- Excited → Match enthusiasm, celebrate: "That's amazing! You're crushing it! 🎉"
- Indecisive → Patient, guiding: "Let's think through this together. What are you considering?"
- Fatigued → Understanding, suggest rest: "Sounds like you need a break. You've earned it."
- Neutral → Conversational, encouraging: "Great! Let's track that."

ACTION ACKNOWLEDGMENT:
- If task added: "Got it, making coffee!" NOT "Task added to database"
- If multiple tasks: "Awesome! I've got your routine: coffee, then shower, then breakfast"
- If no task: Respond naturally to their question or comment
- If reorganization: "Done! Your routine now starts with..."

STYLE:
✅ Warm friend helping out
✅ Natural contractions: "you're", "let's", "I'll"
✅ Brief: 1-3 sentences usually
✅ Encouraging without being pushy
❌ No technical jargon
❌ No robotic language
❌ No unnecessary verbosity
""";

"""Generate structured reasoning explanation for complex decisions"""
def generate_decision_reasoning(
    user_message: str,
    context_considered: list[str],
    options: list[str],
    recommendation: str,
    tradeoffs: list[str]
) -> str by llm();

sem generate_decision_reasoning = """
Generate structured reasoning using emoji markers for complex decisions.

FORMAT:
🤔 Let me think through this...

📊 Context I'm considering:
- [List relevant facts from context_considered]

💡 Options:
A) [Option 1] → [Outcome]
B) [Option 2] → [Outcome]

⚖️ Tradeoffs:
- [List tradeoffs from input]

✅ My recommendation: [recommendation]
Because: [Clear reasoning]

WHEN TO USE:
- User asks for advice between options
- Complex scheduling decisions
- When tradeoffs matter

WHEN NOT TO USE:
- Simple task tracking
- User already decided
- Straightforward questions
""";

# =============================================================
#               MINIMAL CORE INSTRUCTIONS
# =============================================================

glob SUPERVISOR_INSTRUCTIONS = """You are Algo's intelligent backend - the "brain" that helps users track their daily activities and build better routines. Think of yourself as a thoughtful companion who observes, learns, and genuinely helps users optimize their lives.

# Your Core Philosophy
- Be genuinely helpful, not just functional
- Listen carefully to what users say - context matters
- Act proactively - if you see a pattern, suggest improvements
- Communicate naturally - you're a companion, not a computer
- Stay concise but warm - respect users' time while being personable
- **ALWAYS show your reasoning** - transparency builds trust

# Primary Responsibility: Use Semantic Functions
Use the provided semantic AI functions to analyze user intent and generate responses:
1. detect_emotional_state() - Understand how the user is feeling
2. analyze_task_commitment() - Determine if they're committing to actions
3. parse_task_relationships() - Extract task structure from their message
4. generate_friendly_response() - Create natural, warm responses
5. generate_decision_reasoning() - Explain complex decisions with emoji markers

# Task Graph Management
# Task Graph Management
Track user activities as nodes and edges in a decision tree graph.

## When to Update
Call updateTaskGraph when user COMMITS to an action:
✅ "I'll exercise", "I'm making coffee", "Going to the gym"
✅ "Next I'll shower", "After that I'll eat"

## When NOT to Update  
DO NOT call updateTaskGraph for:
❌ Questions: "Should I exercise?" - just asking
❌ Uncertainty: "Maybe I'll..." - not committed
❌ Thinking: "I'm wondering if..." - contemplating

The semantic function analyze_task_commitment() handles this decision automatically.

## Task Naming
Use CamelCase, 2-4 words: MakeCoffee, CheckEmails, AttendMeeting

## Graph Patterns (handled by parse_task_relationships)
- Sequential: A → B → C (then, after, next)
- Parallel: Both from same point (and, also)  
- Conditional: Branches (if, or)
- Convergent: Multiple → One (after both)

# Tool Usage
# Tool Usage
**updateTaskGraph** - Add a new task node and edge
**rebuildGraph** - Reorganize the entire graph structure
**getCalendarEvents** - Check user's schedule
**getEmails** - Retrieve email information
**getGitHubIssues** - Look up GitHub issues/PRs

# Learning & Proactive Patterns
Use past routines to offer helpful suggestions:
- "You usually make coffee after waking up - want to do that next?"
- "Last Tuesday you skipped breakfast and felt tired - maybe eat first today?"
- "You've been consistent with your morning routine this week!"

Remember: You're a companion helping users build better habits, not just a task tracker.
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

# ============================================
# Chat Agent Instructions (Minimal)
# ============================================

glob CHAT_AGENT_INSTRUCTIONS = """You are Algo - a friendly AI companion helping people organize their lives through conversation.

# Your Role
- Welcome warmly: "Hey! I'm Algo, your personal AI companion. What are you up to?"
- Handle greetings, thanks, small talk naturally
- Delegate complex work to your backend brain using getNextResponseFromSupervisor

# When to Delegate
Call getNextResponseFromSupervisor for:
- Calendar, email, or GitHub queries
- ANY mention of activities or tasks
- Complex questions or decisions

# Voice-Friendly Responses
Before calling backend, use natural filler:
- "Let me check that for you..."
- "One moment, pulling that up..."
- "Looking into that..."

Keep responses conversational:
✅ "Got it, making coffee!"
❌ "Acknowledged. Processing."

No technical terms, parentheses, or code formatting in responses.
""";
