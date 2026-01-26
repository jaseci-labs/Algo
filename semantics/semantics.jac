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
Detect emotional state: stressed | excited | indecisive | fatigued | neutral

state = "Current emotional state";
confidence = "Score 0.0-1.0";
reasoning = "Brief detection rationale";
""";

"""Generate a natural, conversational response matching user's emotional state"""
def generate_friendly_response(
    user_message: str,
    emotional_state: EmotionalState,
    action_taken: str,
    task_names: list[str]
) -> str by llm();

sem generate_friendly_response = """
Generate warm response matching emotional_state tone.
Natural acknowledgment ("Got it!" not "Task added"), 1-3 sentences, contractions, no jargon.
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
Classify user intent from message and conversation history.

should_create_tasks = "TRUE if user mentions ANY action/task (even casual ones like 'check messages', 'grab lunch', 'take a walk'). 
Only FALSE for explicit questions ('what should I do?', 'can you help?') or pure uncertainty ('maybe', 'not sure', 'wondering')";

ConversationContext.intent = "COMMIT_ACTION: ANY action mentioned (default unless clearly asking/uncertain) | CORRECT_PREVIOUS: 'actually', 'before', 'first' | CLARIFY_PREVIOUS: 'no i meant', 'after X' | ASK_QUESTION: explicit questions | THINK_ALOUD: 'maybe', 'wondering', 'not sure'";

ConversationContext.referring_to_task = "EXACT task name from existing_nodes user is referencing. Examples: 'rename X to Y'→'X', 'before Y'→'Y', 'watch movie' matching 'WatchSomeNetflix'→'WatchSomeNetflix'. Empty if none";

ConversationContext.correction_type = "CORRECT_PREVIOUS types:
- rename: Change task NAME only (same activity, different label) - 'actually call it X'
- insert_before/insert_after/insert_first: NEW task between/before existing
- reorder: Move EXISTING task to different position
- replace: Swap with COMPLETELY DIFFERENT task
CLARIFY_PREVIOUS: 'attachment_point' | 'sequence_order' | Empty otherwise";

ConversationContext.needs_graph_rebuild = "TRUE for corrections/clarifications with existing tasks, FALSE for simple additions";
ConversationContext.is_insertion = "TRUE if inserting task BETWEEN existing tasks";
ConversationContext.tasks_to_move = "List of existing task names being repositioned (e.g., ['HaveCoffee'])";

confidence = "Score 0.0-1.0";
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

CRITICAL: ALWAYS EXTRACT TASK NAMES even when they already exist in the graph!

REORDERING MODE (correction_type='reorder' OR tasks_to_move is populated):
- Extract the task names being reordered from user_message
- Use EXISTING names without adding numbers
- Example: User says "have coffee before checking news" when TakeCoffee and CheckNews exist
  → raw_names = ["TakeCoffee", "CheckNews"]
  → unique_names = ["TakeCoffee", "CheckNews"] (no numbers added)

CORRECTION/INSERTION MODE (conversation_context.is_insertion=True OR correction_type='insert_before' OR keywords like 'before', 'after', 'between', 'instead'):
- If task exists in existing_nodes, use the EXISTING name without adding numbers
- User is correcting/modifying existing flow, not creating new duplicate tasks
- Example: User says "wash face before heading to gym", and both WashFace and HeadToGym exist → use WashFace and HeadToGym (not WashFace2, HeadToGym2)

NORMAL MODE:
- Append numbers for duplicate task names when creating truly new occurrences
- Formula: if count>0 then raw_name+str(count+1) else raw_name (Example: "MakeCoffee" exists → new unique name "MakeCoffee2")

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
Determine where new tasks connect.

attachment_nodes = "Node(s) to attach from: [last_task] default, multiple for convergence, or task BEFORE referenced for 'before X' patterns";
is_convergent = "TRUE if multiple attachment nodes";
reasoning = "Brief explanation";
user_specified = "TRUE if user named specific task ('after X')";

If needs_graph_rebuild=True: return empty attachment_nodes.
For 'before X': find predecessor of X in current edges.
Default: [last_task] unless user specifies 'after X', 'before Y', 'from Z'.
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
Detect if parallel branches should merge.

should_converge = "TRUE if merging branches";
source_nodes = "Leaf nodes to converge from (split last_task by '|')";
convergence_type = "explicit ('either way') | implicit (last_task has '|') | none";
trigger_phrase = "Detection trigger phrase";
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
edge_label = "Edge label: 'then', 'if raining', 'otherwise', 'while', 'at the same time', etc.";
sequence_order = "Sequence number (1, 2, 3...) to preserve order when multiple relationships";

NEVER concatenate fields like: from_task='WashFace to_task=HeadToGym label=then'

CONNECTION RULES:
- Start point: Use attachment_nodes[0] as the from_task for the FIRST relationship
- For extracted_tasks.unique_names: ["BrushTeeth", "MakeCoffee", "GoToGym"]
- For attachment_nodes: ["Start"]
- Create: Start -> BrushTeeth, BrushTeeth -> MakeCoffee, MakeCoffee -> GoToGym

CRITICAL CONNECTION TYPE DETECTION:
Analyze user_message for parallel keywords:
- PARALLEL: "while", "as", "during", "at the same time", "simultaneously", "and" (when tasks happen together)
    - Create N relationships, ALL with SAME from_task (attachment_nodes[0])
    - ALL relationships use connection_type = PARALLEL
    - Each relationship goes to a different unique task
    - sequence_order: 1, 2, 3... for each parallel branch
    
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
task_insight = "Short bullet about tasks extracted. Show the ACTUAL extracted task names from extracted_tasks.unique_names. 
Format: 'Extracted: [TaskName1], [TaskName2]' for parallel tasks OR 'Adding: [TaskName]' for single task
Example: 'Extracted: TalkToFriend, WalkDog' OR 'Adding: MakeCoffee'
If multiple tasks with parallel pattern: 'Extracted: [Task1], [Task2] (parallel)'";
pattern_insight = "Short bullet about special patterns. Empty if none. 
Format: 'These will happen [at the same time/one after another/either way]' or 'This is task number [X]' for duplicates
For parallel tasks detected: 'These happen at the same time' or 'These happen while doing each other'";

Keep all bullets under 10 words. Be conversational and natural.
""";
