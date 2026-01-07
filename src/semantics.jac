# =============================================================
#                    SEMANTIC TYPE DEFINITIONS
# =============================================================
"""
This module defines all semantic objects, enums, and AI-powered functions
used by Algo for natural language understanding and graph generation.
"""

import from byllm.lib { Model }

# Initialize LLM model for semantic functions
glob llm = Model(model_name="gpt-4.1");

# =============================================================
#                      SEMANTIC OBJECTS
# =============================================================

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
sem SupervisorDecision.show_reasoning = "ALWAYS FALSE - reasoning is internal only, never shown to users";

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
- CRITICAL: If branch has sequential steps, create the chain within that branch
- Example: "If sunny, go outside. If rainy, stay home"
  → [{connection_type: CONDITIONAL, previous_task: "CheckWeather", new_task: "GoOutside", edge_label: "if sunny"},
     {connection_type: CONDITIONAL, previous_task: "CheckWeather", new_task: "StayHome", edge_label: "if rainy"}]
- Example with sequences: "If early meetings, quick shower THEN attend. Else, make coffee THEN shower"
  → [{connection_type: CONDITIONAL, previous_task: "CheckEmail", new_task: "QuickShower", edge_label: "if early meetings"},
     {connection_type: SEQUENTIAL, previous_task: "QuickShower", new_task: "AttendMeetings", edge_label: "then"},
     {connection_type: CONDITIONAL, previous_task: "CheckEmail", new_task: "MakeCoffee", edge_label: "else"},
     {connection_type: SEQUENTIAL, previous_task: "MakeCoffee", new_task: "TakeShower", edge_label: "then"}]

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
