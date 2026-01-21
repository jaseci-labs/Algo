"""This module defines all semantic objects, enums, and AI-powered functions used by Algo for natural language understanding and graph generation."""

import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4.1");

"""Represents the emotional state detected from user's message"""
obj EmotionalState {
    has state: str;
    has confidence: float;
    has reasoning: str;
}

sem EmotionalState.state = "User's current emotional state: stressed, excited, indecisive, fatigued, or neutral";
sem EmotionalState.confidence = "Confidence score between 0.0 and 1.0";
sem EmotionalState.reasoning = "Brief explanation of why this state was detected";

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

Confidence 0.0-1.0.
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

sem ConversationContext.intent = "COMMIT_ACTION: new task commitment | CORRECT_PREVIOUS: 'actually', 'before', 'first' corrections | CLARIFY_PREVIOUS: 'no i meant', 'after X' clarifications | ASK_QUESTION: questions | THINK_ALOUD: wondering/maybe";
sem ConversationContext.referring_to_task = "Which existing task is user referring to? Empty if none, or task name from existing_nodes";
sem ConversationContext.correction_type = "For CORRECT_PREVIOUS: 'insert_before', 'reorder', 'replace' | For CLARIFY_PREVIOUS: 'attachment_point', 'sequence_order' | Empty otherwise";
sem ConversationContext.needs_graph_rebuild = "TRUE for CORRECT_PREVIOUS or CLARIFY_PREVIOUS with existing tasks, FALSE for COMMIT_ACTION on empty/simple graphs";
sem ConversationContext.is_insertion = "TRUE if user wants to insert task BETWEEN existing tasks (keywords: 'before X', 'after Y but before Z', 'between', 'insert'). Example: 'wash face before heading to gym' when both exist";
sem ConversationContext.tasks_to_move = "List of existing task names that are being repositioned/reordered. Example: user says 'have coffee first' when HaveCoffee already exists → ['HaveCoffee']";

"""Intent and commitment analysis result"""
obj IntentAnalysis {
    has should_create_tasks: bool;
    has conversation_context: ConversationContext;
    has confidence: float;
}

sem IntentAnalysis.should_create_tasks = "TRUE if user committed to action OR is correcting/reordering existing tasks. FALSE only for questions/thinking/uncertain. CRITICAL: Corrections and reorderings NEED graph updates, so should_create_tasks MUST be True";
sem IntentAnalysis.conversation_context = "Context about what user is doing: correcting, clarifying, committing new";
sem IntentAnalysis.confidence = "Confidence 0.0-1.0 in the intent classification";

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

CRITICAL: should_create_tasks MUST BE TRUE FOR:
1. New task commitments: "I'll make coffee then check news"
2. Corrections: "actually, have coffee before checking news"
3. Reorderings: "take coffee first", "go to gym after washing face"
4. Insertions: "wash face before heading to gym"

should_create_tasks SHOULD BE FALSE ONLY FOR:
- Pure questions: "what should I do next?"
- Thinking aloud: "maybe I should..."
- Uncertain statements: "I might go to the gym"

REORDERING DETECTION:
If user mentions existing task with reordering keywords ('first', 'before that', 'earlier', 'after', 'then'):
- Set should_create_tasks = True (CRITICAL!)
- Set correction_type = 'reorder'
- Set needs_graph_rebuild = True
- Populate tasks_to_move with the task names being repositioned
Example: "have coffee first" when HaveCoffee exists → tasks_to_move = ["HaveCoffee"], should_create_tasks = True

Default to COMMIT_ACTION when user mentions tasks/actions.
Check last 2-3 conversation turns for context.
""";

"""Maps raw task name to unique task name with count"""
obj TaskNameMapping {
    has raw: str;
    has unique: str;
    has count: int;
}

sem TaskNameMapping.raw = "Base task name extracted from message";
sem TaskNameMapping.unique = "Unique task name with number appended if duplicate";
sem TaskNameMapping.count = "How many times this raw name appeared in existing_nodes";

"""Extracted task names from user message"""
obj ExtractedTasks {
    has raw_names: list[str];
    has unique_names: list[str];
    has name_mappings: list[TaskNameMapping];
    has duplicate_counts: list[int];
}

sem ExtractedTasks.raw_names = "Base task names in CamelCase extracted from message (e.g., CheckEmail, MakeCoffee)";
sem ExtractedTasks.unique_names = "NEW unique task names to create. CORRECTION/INSERTION LOGIC: If correction_type='insert_before' OR is_insertion=True OR user says 'before', 'after', 'instead', 'actually', then use existing task names WITHOUT numbers (reusing existing tasks). Otherwise, append numbers for duplicates. Formula: if needs_reuse then use raw_name as-is, else if count>0 then raw_name+str(count+1) else raw_name";
sem ExtractedTasks.name_mappings = "List of {raw: str, unique: str, count: int} showing transformation for each task";
sem ExtractedTasks.duplicate_counts = "For each raw_name, how many times it appears in existing_nodes. Used to calculate unique_names";

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
- Formula: if count>0 then raw_name+str(count+1) else raw_name

Populate all fields including duplicate_counts.
""";

"""Determine where new tasks should attach in the graph"""
obj AttachmentPointAnalysis {
    has attachment_nodes: list[str];
    has is_convergent: bool;
    has reasoning: str;
    has user_specified: bool;
}

sem AttachmentPointAnalysis.attachment_nodes = "List of node(s) to attach from. Usually [last_task] or multiple for convergence";
sem AttachmentPointAnalysis.is_convergent = "TRUE if attaching from multiple nodes (convergent edge)";
sem AttachmentPointAnalysis.reasoning = "Explanation of why these attachment points were chosen";
sem AttachmentPointAnalysis.user_specified = "TRUE if user explicitly named a task (e.g., 'after X'), FALSE if using default last_task";

"""Determine where new tasks should attach in the graph"""
def determine_attachment_points(
    user_message: str,
    last_task: str,
    existing_nodes: list[str],
    conversation_context: ConversationContext
) -> AttachmentPointAnalysis by llm();

sem determine_attachment_points = """
Analyze where new tasks should connect in the graph.

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

sem ConvergenceIntent.should_converge = "TRUE if user intends parallel branches to merge";
sem ConvergenceIntent.source_nodes = "List of nodes to converge from (leaf nodes)";
sem ConvergenceIntent.convergence_type = "explicit (keywords like 'either way') | implicit (last_task has '|' and no specific task named) | none (no convergence)";
sem ConvergenceIntent.trigger_phrase = "The phrase that triggered convergence detection";

"""Detect if user intends to converge parallel branches"""
def detect_convergence_intent(
    user_message: str,
    last_task: str,
    current_edges: list[dict[str, str]]
) -> ConvergenceIntent by llm();

sem detect_convergence_intent = """
Detect convergence patterns from user message.

Types:
1. EXPLICIT convergence (should_converge=True):
   - Keywords: "either way", "regardless", "in both cases", "afterwards" (after branches)

2. IMPLICIT convergence (should_converge=True):
   - last_task contains "|" (e.g., "GoToGym|GoForRun")
   - User adds task WITHOUT naming specific source

3. NO convergence (should_converge=False):
   - User names specific task: "after GoToGym"
   - Linear flow: normal "then X" when last_task is single

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

sem TaskRelationship.connection_type = "SEQUENTIAL: then/after | PARALLEL: and/also/while/same time | CONDITIONAL: if/otherwise | CONVERGENT: merge point";
sem TaskRelationship.from_task = "Task name in CamelCase (previous task in sequence)";
sem TaskRelationship.to_task = "Next task name in CamelCase (e.g., MakeCoffee, BrushTeeth)";
sem TaskRelationship.edge_label = "Edge label: 'then', 'if raining', 'otherwise', etc.";
sem TaskRelationship.sequence_order = "Sequence number (1, 2, 3...) to preserve order when multiple relationships";

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

CRITICAL: RETURN PROPER JSON STRUCTURE
Each TaskRelationship object MUST have separate fields:
{
  "connection_type": "SEQUENTIAL",
  "from_task": "CheckMessages",
  "to_task": "WashFace",
  "edge_label": "then",
  "sequence_order": 1
}

NEVER concatenate fields like: from_task='WashFace to_task=HeadToGym label=then'

CRITICAL: USE ACTUAL TASK NAMES
- from_task MUST be an actual task name (e.g., "Start", "BrushTeeth", "WakeUp")
- to_task MUST be an actual task name from extracted_tasks.unique_names
- attachment_analysis.attachment_nodes contains the ACTUAL task names to attach from
- NEVER use placeholder text like "last_task" - use the actual task name from attachment_nodes

REORDERING TASKS (correction_type='reorder', tasks_to_move is populated):
When user wants to reposition an existing task:

Example scenario:
- User: "have coffee first, then check the news"
- Current graph: CheckNews -> BrushTeeth -> HaveCoffee -> WashFace
- tasks_to_move: ["HaveCoffee"]
- current_edges: [
    {from: "CheckNews", to: "BrushTeeth", label: "then"},
    {from: "BrushTeeth", to: "HaveCoffee", label: "then"},
    {from: "HaveCoffee", to: "WashFace", label: "then"}
  ]

STEP 1: Identify what to remove
- Find ALL edges involving HaveCoffee:
  - Incoming: BrushTeeth -> HaveCoffee (remove)
  - Outgoing: HaveCoffee -> WashFace (remove)

STEP 2: Fill the gap
- The task BEFORE HaveCoffee was BrushTeeth
- The task AFTER HaveCoffee was WashFace
- Create new edge: BrushTeeth -> WashFace

STEP 3: Create new position
- User wants: HaveCoffee -> CheckNews
- The task BEFORE CheckNews was nothing (Start implied)
- Create edges:
  - Start -> HaveCoffee (or from attachment point)
  - HaveCoffee -> CheckNews

RETURN ALL relationships to create the complete new graph:
1. {from_task: "Start", to_task: "HaveCoffee", edge_label: "then", sequence_order: 1}
2. {from_task: "HaveCoffee", to_task: "CheckNews", edge_label: "then", sequence_order: 2}
3. {from_task: "CheckNews", to_task: "BrushTeeth", edge_label: "then", sequence_order: 3}
4. {from_task: "BrushTeeth", to_task: "WashFace", edge_label: "then", sequence_order: 4}

The rebuild process will remove all old edges and create only these new ones.

INSERTION DETECTION (using current_edges):
If user says "wash face BEFORE heading to gym":
1. Check current_edges for edge ending at HeadToGym (e.g., CheckMessages->HeadToGym)
2. Find the from_task of that edge (CheckMessages)
3. Create relationships to INSERT WashFace:
   - CheckMessages -> WashFace (label: "then")
   - WashFace -> HeadToGym (label: "then")
4. needs_graph_rebuild should be True to remove the old CheckMessages->HeadToGym edge

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
  
- SEQUENTIAL: "then", "after", "next", "before", "first" (tasks happen one after another)
    - Create N relationships chained together
    - First: from attachment_nodes[0] to unique_names[0]
    - Second: from unique_names[0] to unique_names[1]
    - Continue chaining: each new task's from_task is the previous to_task

If needs_graph_rebuild=True: Reconstruct FULL graph with ALL existing nodes
If convergence_intent.should_converge: Create edges from ALL source_nodes to first unique task
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

sem ThinkingSummary.emotional_insight = "Short bullet about user's emotional state. Empty string if confidence < 0.7. Format: 'You seem [state] right now'";
sem ThinkingSummary.intent_insight = "Short bullet about what user is doing. Empty string for simple COMMIT_ACTION. Format: 'You're [correcting/clarifying/asking about] [context]'";
sem ThinkingSummary.task_insight = "Short bullet about tasks extracted. Use friendly names not CamelCase. Format: 'I'm extracting: [list of tasks]' or 'I'm adding: [task description]'";
sem ThinkingSummary.pattern_insight = "Short bullet about special patterns. Empty if none. Format: 'These will happen [at the same time/one after another/either way]' or 'This is task number [X]' for duplicates";

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

RULES:
1. emotional_insight: Be empathetic and natural

2. intent_insight: Format - "You're correcting [task]" or "You're clarifying where [task] goes"

3. task_insight: For duplicates, mention the count naturally

4. pattern_insight: Only for special patterns, otherwise empty string
   - PARALLEL: "These will happen at the same time"
   - Duplicates (check extracted_tasks.duplicate_counts): "This is your [X]th time doing this"

Keep all bullets under 10 words. Be conversational and natural.
""";
