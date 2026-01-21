"""This module defines all semantic objects, enums, and AI-powered functions used by Algo for natural language understanding and graph generation."""

import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4.1");

"""Represents the emotional state detected from user's message"""
obj EmotionalState {
    has state: str;
    has confidence: float;
    has reasoning: str;
}

"""Detect the user's emotional state from their message and conversation context"""
def detect_emotional_state(
    user_message: str,
    conversation_history: list[dict[str, str]]
) -> EmotionalState by llm();

sem detect_emotional_state = """
Detect emotional state from message:
- stressed: frustration, overwhelm
- excited: enthusiasm, accomplishments  
- indecisive: uncertainty, questions
- fatigued: tired, exhausted
- neutral: normal tone

state = "User's current emotional state: stressed, excited, indecisive, fatigued, or neutral";
confidence = "Confidence score between 0.0 and 1.0";
reasoning = "Brief explanation of why this state was detected";
""";

"""Generate a natural, conversational response matching user's emotional state"""
def generate_friendly_response(
    user_message: str,
    emotional_state: EmotionalState,
    action_taken: str,
    task_names: list[str]
) -> str by llm();

sem generate_friendly_response = """
Generate warm, natural response as Algo:

Match emotional_state tone (stressed→supportive, excited→enthusiastic, etc.)
Acknowledge action naturally ("Got it!" not "Task added")
Brief 1-3 sentences, use contractions, no tech jargon.
""";

"""Conversation intent classification"""
enum ConversationIntent {
    COMMIT_ACTION,
    CORRECT_PREVIOUS,
    CLARIFY_PREVIOUS,
    ASK_QUESTION,
    THINK_ALOUD
}

"""Represents what the user is referring to in conversation"""
obj ConversationContext {
    has intent: ConversationIntent;
    has referring_to_task: str;
    has correction_type: str;
    has needs_graph_rebuild: bool;
    has is_insertion: bool;
    has tasks_to_move: list[str];
}

"""Intent and commitment analysis result"""
obj IntentAnalysis {
    has should_create_tasks: bool;
    has conversation_context: ConversationContext;
    has confidence: float;
}

"""Analyze conversation intent and determine if user is committing, correcting, or clarifying"""
def analyze_conversation_intent(
    user_message: str,
    conversation_history: list[dict[str, str]],
    existing_nodes: list[str],
    last_task: str
) -> IntentAnalysis by llm();

sem analyze_conversation_intent = """
Analyze user's message and recent conversation history to classify their intent.
Populate IntentAnalysis with appropriate values based on semantic definitions.

should_create_tasks = "TRUE if user committed to action OR is correcting/reordering existing tasks. 
FALSE only for questions/thinking/uncertain. CRITICAL: Corrections, reorderings and insertions NEED graph updates, 
so should_create_tasks MUST be True";

conversation_context = "Context about what user is doing: correcting, clarifying, committing new";
Here is what you should know about the conversation context:
ConversationContext.intent = "COMMIT_ACTION: new task commitment | CORRECT_PREVIOUS: 'actually', 'before', 
'first' corrections | CLARIFY_PREVIOUS: 'no i meant', 'after X' clarifications | ASK_QUESTION: questions | 
THINK_ALOUD: wondering/maybe";
ConversationContext.referring_to_task = "Which existing task is user referring to? 
EXAMPLES:
- 'rename WatchNetflix to WatchMovie' → 'WatchNetflix' (task being renamed)
- 'do X before Y' → 'Y' (reference point)
- 'watch movie' when graph has 'WatchSomeNetflix' → 'WatchSomeNetflix' (semantic match)
Empty if none, or EXACT task name from existing_nodes";
ConversationContext.correction_type = "For CORRECT_PREVIOUS: 
- 'rename': User wants to RENAME/REPHRASE an existing task keeping same intent (e.g., 'rename X to Y', 'actually call it Z', 'change WatchNetflix to WatchTheHalfOfIt')
  CRITICAL: Use 'rename' when user is just changing HOW a task is named, not WHAT the task is
- 'insert_before': NEW task inserted before existing task (e.g., 'wash face before gym')
- 'insert_after': NEW task inserted after existing task  
- 'insert_first': NEW task at the beginning ('first' keyword)
- 'reorder': EXISTING task being repositioned to different point in sequence
- 'replace': Replace existing task with COMPLETELY DIFFERENT task (e.g., 'watch movie' becomes 'go for run') | For CLARIFY_PREVIOUS: 'attachment_point', 'sequence_order' | Empty otherwise";
ConversationContext.needs_graph_rebuild = "TRUE for CORRECT_PREVIOUS or CLARIFY_PREVIOUS with existing tasks, FALSE for COMMIT_ACTION on empty/simple graphs";
ConversationContext.is_insertion = "TRUE if user wants to insert a new task BETWEEN existing tasks 
ConversationContext.tasks_to_move = "List of existing task names that are being repositioned/reordered. Example: user says 'have coffee first' when HaveCoffee already exists → ['HaveCoffee']";

confidence = "Confidence 0.0-1.0 in the intent classification";

Check last 2-3 conversation turns for context.
""";

"""Maps raw task name to unique task name with count"""
obj TaskNameMapping {
    has raw: str;
    has unique: str;
    has count: int;
}

"""Extracted task names from user message"""
obj ExtractedTasks {
    has raw_names: list[str];
    has unique_names: list[str];
    has name_mappings: list[TaskNameMapping];
    has duplicate_counts: list[int];
}

"""Extract raw task names from user message in CamelCase format"""
def extract_raw_task_names(
    user_message: str,
    conversation_context: ConversationContext,
    existing_nodes: list[str]
) -> ExtractedTasks by llm();

sem extract_raw_task_names = """
Extract task names and generate unique names.

Focus on the CORE ACTION only, in CamelCase format.

CRITICAL: Convert user's natural language to proper CamelCase:
- "checking whatsapp" → "CheckWhatsapp" or "CheckingWhatsapp"
- "make coffee" → "MakeCoffee"
- "grab some buns" → "GrabSomeBuns"
Remove articles (a, an, the) and convert spaces to CamelCase.

raw_names = "Base task names in CamelCase extracted from message (e.g., CheckEmail, MakeCoffee). 
MUST have conversational prefixes removed AND be converted from natural language to CamelCase";

unique_names = "NEW unique task names to create. 

CRITICAL FOR RENAME (correction_type='rename'):
- IGNORE existing_nodes completely
- Extract the NEW task name from user's message and convert to CamelCase
- Example: User says 'grab some buns', existing has 'GrabSomeBreakfast' → return 'GrabSomeBuns' NOT 'GrabSomeBreakfast'
- Example: User says 'checking whatsapp', existing has 'CheckMyPhone' → return 'CheckingWhatsapp' NOT 'CheckMyPhone'

CORRECTION/INSERTION LOGIC (for insert_before, insert_after): 
- If correction_type='insert_before' OR is_insertion=True OR user says 'before', 'after', 'instead'
- Then use existing task names WITHOUT numbers (reusing existing tasks)

NORMAL LOGIC (for new tasks):
- Append numbers for duplicates if task already exists
- Formula: if count>0 then raw_name+str(count+1) else raw_name";

name_mappings = "List of {raw: str, unique: str, count: int} showing transformation for each task";
Here is what you should know about name mappings:
TaskNameMapping.raw = "Base task name extracted from message";
TaskNameMapping.unique = "Unique task name with number appended if duplicate (or NEW name for rename)";
TaskNameMapping.count = "How many times this raw name appeared in existing_nodes";

duplicate_counts = "For each raw_name, how many times it appears in existing_nodes. Used to calculate unique_names";

Populate all fields including duplicate_counts.
""";

"""Determine where new tasks should attach in the graph"""
obj AttachmentPointAnalysis {
    has attachment_nodes: list[str];
    has is_convergent: bool;
    has reasoning: str;
    has user_specified: bool;
}

"""Determine where new tasks should attach in the graph"""
def determine_attachment_points(
    user_message: str,
    last_task: str,
    existing_nodes: list[str],
    conversation_context: ConversationContext
) -> AttachmentPointAnalysis by llm();

sem determine_attachment_points = """
Analyze where new tasks should connect in the graph.

attachment_nodes = "List of node(s) to attach from. Usually [last_task] or multiple for convergence";
is_convergent = "TRUE if attaching from multiple nodes (convergent edge)";
reasoning = "Explanation of why these attachment points were chosen";
user_specified = "TRUE if user explicitly named a task (e.g., 'after X'), FALSE if using default last_task";

INSERTION PATTERN (user says "BEFORE X"):
Example: "wash face before heading to gym" when graph has CheckMessages->HeadToGym
- Find the task BEFORE the referenced task in existing graph
- attachment_nodes = [task that currently connects TO the referenced task]
- Example result: attachment_nodes = ["CheckMessages"] (the task before HeadToGym)
- This allows creating: CheckMessages->WashFace->HeadToGym

If conversation_context.needs_graph_rebuild = True:
   - Return empty attachment_nodes (will rebuild full graph)
   - reasoning explains the correction/clarification

Otherwise:
- Default: attachment_nodes = [last_task]
- User-specified: Parse user_message for "after X", "before Y", "from Z"

Always provide clear reasoning for transparency.
""";

"""Detection of convergence patterns in user intent"""
obj ConvergenceIntent {
    has should_converge: bool;
    has source_nodes: list[str];
    has convergence_type: str;
    has trigger_phrase: str;
}

"""Detect if user intends to converge parallel branches"""
def detect_convergence_intent(
    user_message: str,
    last_task: str,
    current_edges: list[dict[str, str]]
) -> ConvergenceIntent by llm();

sem detect_convergence_intent = """
Detect convergence patterns from user message.

should_converge = "TRUE if user intends parallel branches to merge";
source_nodes = "List of nodes to converge from (leaf nodes)";
convergence_type = "explicit (keywords like 'either way') | implicit (last_task has '|' and no specific task named) | none (no convergence)";
trigger_phrase = "The phrase that triggered convergence detection";

Extract source_nodes by splitting last_task by "|" if convergence detected.
""";

"""Represents a task connection type in the graph"""
enum ConnectionType {
    SEQUENTIAL,
    PARALLEL,
    CONDITIONAL,
    CONVERGENT
}

"""Task relationship with clear sequencing"""
obj TaskRelationship {
    has connection_type: ConnectionType;
    has from_task: str;
    has to_task: str;
    has edge_label: str;
    has sequence_order: int;
}

"""Build task relationships using pre-analyzed context"""
def build_task_relationships(
    user_message: str,
    extracted_tasks: ExtractedTasks,
    attachment_analysis: AttachmentPointAnalysis,
    convergence_intent: ConvergenceIntent,
    conversation_context: ConversationContext,
    current_edges: list[dict[str, str]]
) -> list[TaskRelationship] by llm();

sem build_task_relationships = """
Build TaskRelationship list using pre-analyzed inputs.

CRITICAL: DEFAULT BEHAVIOR - INCREMENTAL ADDITION
For normal COMMIT_ACTION with conversation_context.needs_graph_rebuild=False:
- Return ONLY the NEW relationships being added
- Do NOT include existing relationships from current_edges

FULL REBUILD MODE (conversation_context.needs_graph_rebuild=True):
When user is correcting/reordering existing tasks:
- Return ALL relationships to reconstruct the complete graph INCLUDING ALL EXISTING EDGES from current_edges
- CRITICAL: Start by INCLUDING all relationships from current_edges, then modify only the affected area
- For INSERTION corrections (insert_before, insert_after, insert_first):
  * Include ALL existing edges from current_edges
  * Remove only the edge being split (e.g., if inserting between A->C, remove A->C)
  * Add the new insertion edges (A->NewTask, NewTask->C)
  * CRITICAL: Reconnect downstream tasks - if inserting B between A and C, return: A->B, B->C
  * Example: Graph is Start->CheckMessages->MakeBreakfast->GoToGym, user says "wash face after breakfast"
    Return ALL edges: Start->CheckMessages, CheckMessages->MakeBreakfast, MakeBreakfast->WashFace, WashFace->GoToGym
- For REORDER corrections: rebuild with tasks in new positions

CRITICAL: RETURN PROPER JSON STRUCTURE
Each TaskRelationship object MUST have separate fields:
{
  "connection_type": "SEQUENTIAL",
  "from_task": "CheckMessages",
  "to_task": "WashFace",
  "edge_label": "then",
  "sequence_order": 1
}

connection_type = "SEQUENTIAL: then/after | PARALLEL: and/also/while/same time | CONDITIONAL: if/otherwise | 
CONVERGENT: merge point";
from_task = "Task name in CamelCase (previous task in sequence)";
to_task = "Next task name in CamelCase (e.g., MakeCoffee, BrushTeeth)";
edge_label = "Edge label: 'then', 'if raining', 'otherwise', etc.";
sequence_order = "Sequence number (1, 2, 3...) to preserve order when multiple relationships";

NEVER concatenate fields like: from_task='WashFace to_task=HeadToGym label=then'

CONNECTION RULES:
- Start point: Use attachment_nodes[0] as the from_task for the FIRST relationship
- For extracted_tasks.unique_names: ["BrushTeeth", "MakeCoffee", "GoToGym"]
- For attachment_nodes: ["Start"]
- Create: Start -> BrushTeeth, BrushTeeth -> MakeCoffee, MakeCoffee -> GoToGym

CRITICAL: CONVERGENCE HANDLING
If convergence_intent.should_converge=True OR attachment_nodes contains multiple nodes:
- Create a relationship from EACH node in attachment_nodes to the FIRST extracted task
- Then chain remaining tasks sequentially
- Example: attachment_nodes=["TaskA", "TaskB"], extracted_tasks=["NewTask", "NextTask"]
  Result: TaskA -> NewTask, TaskB -> NewTask, NewTask -> NextTask
- Use connection_type=CONVERGENT for the converging edges
- Edge label should be "either way" or similar convergence phrase depending on user message
""";

"""Generate 2 contextual suggestions for what the user might do next"""
def generate_next_suggestions(
    last_task: str,
    recent_tasks: list[str],
    conversation_context: ConversationContext,
    emotional_state: EmotionalState
) -> list[str] by llm();

sem generate_next_suggestions = """
Generate exactly 2 short, natural suggestions (3-5 words each) for what the user might do next.

Guidelines:
- Keep them conversational and first-person ("I'll make coffee" not "Make coffee")
- Base them on typical routine patterns and the current context
- Consider time of day and flow (morning → breakfast, lunch → afternoon tasks)
- Make them diverse (different types of activities)
- Keep them brief and actionable

Examples:
After "WakeUp" → ["I'll make coffee", "I'll take a shower"]
After "HaveLunch" → ["I'll get back to work", "I'll take a short break"]
After "FinishWork" → ["I'll head home", "I'll grab dinner"]
After "Dinner" → ["I'll watch TV", "I'll read a book"]

Return as a simple list of 2 strings, nothing else.
""";

"""Thinking insights to show user (transparency feature)"""
obj ThinkingSummary {
    has emotional_insight: str;
    has intent_insight: str;
    has task_insight: str;
    has pattern_insight: str;
}

"""Generate user-friendly thinking insights for transparency"""
def generate_thinking_summary(
    user_message: str,
    emotional_state: EmotionalState,
    intent_analysis: IntentAnalysis,
    extracted_tasks: ExtractedTasks,
    attachment_analysis: AttachmentPointAnalysis,
    convergence_intent: ConvergenceIntent
) -> ThinkingSummary by llm();

sem generate_thinking_summary = """
Generate short, friendly bullet points showing Algo's understanding.

emotional_insight = "Short bullet about user's emotional state. Empty string if confidence < 0.7. 
Format: 'You seem [state] right now'";
intent_insight = "Short bullet about what user is doing. Empty string for simple COMMIT_ACTION. 
Format: 'You're [correcting/clarifying/asking about] [context]'";
task_insight = "Short bullet about tasks extracted. Use friendly names not CamelCase. 
Format: 'I'm extracting: [list of tasks]' or 'I'm adding: [task description]'";
pattern_insight = "Short bullet about special patterns. Empty if none. 
Format: 'These will happen [at the same time/one after another/either way]' or 'This is task number [X]' for duplicates";

Keep all bullets under 10 words. Be conversational and natural.
""";
