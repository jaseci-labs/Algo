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
    has renamed_to: str;  # For rename operations: the new task name ONLY
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

RENAME MODE (correction_type='rename'):
- Populate the 'renamed_to' field with the NEW task name (the one being renamed TO)
- DO NOT populate raw_names or unique_names with the old task name
- Set renamed_to to the task name that comes AFTER "to" or "instead"
- Examples:
  * "rename IfItIsRainingIWillReadMyBook to ReadBook" → renamed_to = "ReadBook", raw_names = [], unique_names = []
  * "rename that task, have chat with colleagues, to chat with colleagues instead" → renamed_to = "ChatWithColleagues"
  * "rename the task Continue working on project to Project Work" → renamed_to = "ProjectWork"
  * "rename ContinueWorkingOnProject to ProjectWork" → renamed_to = "ProjectWork"

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

CRITICAL EDGE LABEL RULES:
- "then" or "afterwards": Default for sequential tasks (A happens, then B happens)
- "while" or "at same time": For PARALLEL tasks (A and B happen simultaneously)
- "if X" or "otherwise": For CONDITIONAL branches (if X happens do A, otherwise do B)
- "either way": ONLY for CONDITIONAL convergence where if/otherwise branches merge (NOT for parallel tasks)
- After PARALLEL tasks converge, use "then" or "afterwards" for the next sequential task
- Example: "have drink while chatting with buddies, then head home, then call a cab"
  → HaveDrink[label="while"], ChatWithBuddies[label="while"] from HeadToThePub
  → HaveDrink->HeadHome[label="then"], ChatWithBuddies->HeadHome[label="then"]
  → HeadHome->CallACab[label="then"]
- Example conditional: "if raining, read book; otherwise, walk; either way go home"
  → IfRaining->ReadBook[label="if raining"], Otherwise->Walk[label="otherwise"]
  → ReadBook->GoHome[label="either way"], Walk->GoHome[label="either way"]

CRITICAL CONNECTION TYPE DETECTION:
Analyze user_message for parallel keywords:
- PARALLEL: "while", "as", "during", "at the same time", "simultaneously", "and" (when tasks happen together)
    - Create N relationships, ALL with SAME from_task (attachment_nodes[0])
    - ALL relationships use connection_type = PARALLEL
    - Each relationship goes to a different unique task
    - sequence_order: 1, 2, 3... for each parallel branch

CRITICAL: CONVERGENCE HANDLING
PARALLEL CONVERGENCE (multiple nodes converging after doing things simultaneously):
- attachment_nodes contains multiple nodes from parallel activities
- Create edges from EACH attachment node to the FIRST extracted task
- Use "then" or "afterwards" for these converging edges (parallel tasks finished, now do next thing)
- Example: attachment_nodes=["HaveADrink", "ChatWithBuddies"], extracted_tasks=["HeadHome", "CallACab"]
  Result: HaveADrink->HeadHome[label="then"], ChatWithBuddies->HeadHome[label="then"], HeadHome->CallACab[label="then"]

CONDITIONAL CONVERGENCE (if/otherwise branches merging):
- Only use "either way" label when converging CONDITIONAL branches (if X / otherwise)
- The user must say "either way", "both paths", "regardless", or similar for conditional convergence
- Example: "if raining read book otherwise walk either way go home"
  → IfRaining->ReadBook, Otherwise->Walk, ReadBook->GoHome[label="either way"], Walk->GoHome[label="either way"]
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

"""Task validation result"""
obj TaskValidationResult {
    has is_valid: bool;
    has reason: str;
    has missing_tasks: list[str];
}

"""Validate that extracted tasks match the user's message"""
def validate_task_extraction(
    user_message: str,
    extracted_tasks: list[str]
) -> TaskValidationResult by llm();

sem validate_task_extraction = """
Validate if the extracted tasks correctly capture ALL actions/activities mentioned in the user's message.

CRITICAL: Look for:
1. Conditional statements: "if X, then Y; otherwise Z" → BOTH tasks should be extracted
2. Multiple activities in one message: "I'll do X and then Y" → BOTH tasks should be extracted
3. Parallel tasks: "while X, I'll also Y" → BOTH tasks should be extracted
4. Alternative scenarios: "if I have time I'll X, otherwise I'll Y" → BOTH tasks should be extracted

Examples of INCORRECT extraction (missing tasks):
- User: "If I have assignments due I will work on them, if not I will netflix and chill"
  Extracted: ["NetflixAndChill"] → INVALID (missing "WorkOnAssignments")
- User: "I'll make coffee and then check my emails"
  Extracted: ["MakeCoffee"] → INVALID (missing "CheckEmails")
- User: "While brushing my teeth, I'll also check the news"
  Extracted: ["BrushTeeth"] → INVALID (missing "CheckNews")

Return:
- is_valid: true if ALL tasks mentioned are captured, false otherwise
- reason: Brief explanation of why invalid (e.g., "Missing task: WorkOnAssignments - the user said they would work on assignments IF they have any")
- missing_tasks: List of task names that were missed (empty if valid)
""";

"""Graph structure validation result"""
obj GraphValidationResult {
    has is_valid: bool;
    has reason: str;
    has expected_structure: str;
}

"""Validate that graph structure matches user's intent"""
def validate_graph_structure(
    user_message: str,
    graph_nodes: list[str],
    graph_edges: list[dict[str, str]]
) -> GraphValidationResult by llm();

sem validate_graph_structure = """
Validate if the graph structure correctly represents the user's intent for NEWLY ADDED tasks.

IMPORTANT CONTEXT:
- graph_nodes: ONLY the newly added task names (not the entire graph)
- graph_edges: ONLY edges involving the new tasks (as "to" destination)
- The "from" task in edges is typically a pre-existing task - this is EXPECTED and VALID

Check for:
1. Conditional branches: "if X then Y, otherwise Z" → New tasks should have proper conditional structure
2. Sequential tasks: "do X then Y" → If user said "do X then Y", both should be added with X→Y edge
3. Parallel tasks: "while X, also Y" → Both tasks should branch from same source
4. Convergence: "either way" → Tasks should merge into a common task

Examples of CORRECT structure (pre-existing task "ReadABook" + new task "MakeBreakfast"):
- User: "make breakfast"
  graph_nodes: ["MakeBreakfast"]
  graph_edges: [{"from": "ReadABook", "to": "MakeBreakfast", "label": "then"}]
  → VALID: Single task added, connected from previous task

Examples of INCORRECT structure:
- User: "I'll make coffee and then check emails"
  graph_nodes: ["MakeCoffee"]
  graph_edges: [{"from": "Start", "to": "MakeCoffee", "label": "then"}]
  → INVALID: Missing "CheckEmails" task mentioned in user message

- User: "if I have assignments I'll work on them, otherwise netflix"
  graph_nodes: ["NetflixAndChill"]
  graph_edges: [{"from": "Start", "to": "NetflixAndChill", "label": "then"}]
  → INVALID: Missing conditional branch "WorkOnAssignments"

Return:
- is_valid: true if the new tasks are correctly connected
- reason: Brief explanation of what's wrong (empty if valid)
- expected_structure: Description of what SHOULD exist (empty if valid)
""";

#===========================================================
#           OPERATION-SPECIFIC VALIDATION FUNCTIONS
#===========================================================

"""Rename validation result"""
obj RenameValidationResult {
    has is_valid: bool;
    has reason: str;
    has old_task_found: bool;
    has new_task_unique: bool;
    has edges_updated: bool;
}

"""Validate that a rename operation was executed correctly"""
def validate_rename_operation(
    user_message: str,
    old_task: str,
    new_task: str,
    before_nodes: list[str],
    after_nodes: list[str],
    before_edges: list[dict[str, str]],
    after_edges: list[dict[str, str]]
) -> RenameValidationResult by llm();

sem validate_rename_operation = """
Validate that a rename operation was executed correctly.

CRITICAL CHECKS:
1. Old task existed in before_nodes (cannot rename non-existent task)
2. New task is in after_nodes (the renamed task exists)
3. New task is NOT the same as old task (actual rename occurred)
4. Old task is NOT in after_nodes (original name removed)
5. All edges that referenced old_task now reference new_task
6. No duplicate tasks created

ANALYSIS APPROACH:
- Compare before_nodes and after_nodes to find what changed
- Check if old_task was removed and new_task was added
- Verify edge labels are preserved (only task names changed)

Examples:
- Valid: old="IfItIsRainingIWillReadMyBook" in before, new="ReadBook" in after, edges updated
- Valid: old="MakeCoffee", new="GrabCoffee", all edges now reference "GrabCoffee"
- Invalid: old task not found in before_nodes
- Invalid: new task same as old task (no actual rename)
- Invalid: old task still exists in after_nodes (rename incomplete)
- Invalid: edges still reference old task (edges not updated)

Return:
- is_valid: true if rename was correctly executed
- reason: Brief explanation of what's wrong (empty if valid)
- old_task_found: true if old task existed in before_nodes
- new_task_unique: true if new task doesn't conflict with existing tasks
- edges_updated: true if all edges were correctly updated
""";

"""Insert validation result"""
obj InsertValidationResult {
    has is_valid: bool;
    has reason: str;
    has insert_position_correct: bool;
    has referring_task_exists: bool;
    has no_orphans: bool;
}

"""Validate that an insert operation positioned tasks correctly"""
def validate_insert_operation(
    user_message: str,
    operation_type: str,
    referring_to_task: str,
    new_tasks: list[str],
    before_edges: list[dict[str, str]],
    after_edges: list[dict[str, str]]
) -> InsertValidationResult by llm();

sem validate_insert_operation = """
Validate that an insert operation positioned tasks correctly.

OPERATION TYPES:
- insert_before: New tasks should be BEFORE referring_to_task
- insert_after: New tasks should be AFTER referring_to_task
- insert_first: New tasks should be at beginning (after Start)

CRITICAL CHECKS:
1. Referring task exists in the graph (or is "Start" for insert_first)
2. New tasks were actually added to the graph
3. Insert position matches the operation type:
   - insert_before: New task → referring_to_task edge exists
   - insert_after: referring_to_task → new task edge exists
   - insert_first: Start → new task edge exists
4. No orphaned tasks (disconnected from main flow)

ANALYSIS APPROACH:
- Compare before_edges and after_edges to find new edges
- Check if new edges connect tasks in the correct order
- Verify the position relative to referring_to_task

Examples:
- Valid: operation="insert_before", referring="CheckMessages", new="WashFace"
  → Edge: WashFace → CheckMessages exists
- Valid: operation="insert_after", referring="MakeCoffee", new="HaveBreakfast"
  → Edge: MakeCoffee → HaveBreakfast exists
- Invalid: referring_to_task not found in graph
- Invalid: Insert position doesn't match operation type
- Invalid: New task not connected to graph

Return:
- is_valid: true if insert was correctly executed
- reason: Brief explanation of what's wrong (empty if valid)
- insert_position_correct: true if position matches operation type
- referring_task_exists: true if referring task was found
- no_orphans: true if no disconnected tasks
""";

"""Reorder validation result"""
obj ReorderValidationResult {
    has is_valid: bool;
    has reason: str;
    has tasks_moved_exist: bool;
    has new_order_logical: bool;
    has no_circular_refs: bool;
}

"""Validate that a reorder operation moved tasks correctly"""
def validate_reorder_operation(
    user_message: str,
    tasks_to_move: list[str],
    before_edges: list[dict[str, str]],
    after_edges: list[dict[str, str]]
) -> ReorderValidationResult by llm();

sem validate_reorder_operation = """
Validate that a reorder operation moved tasks correctly.

CRITICAL CHECKS:
1. All tasks in tasks_to_move exist in the graph
2. New position matches user's description from user_message
3. No circular references created (A→B→...→A)
4. All affected tasks remain connected to the main flow
5. The reorder actually changed something (edges are different)

ANALYSIS APPROACH:
- Identify edges that involve tasks_to_move in before_edges vs after_edges
- Check if the connections changed as expected
- Verify the new order matches user's intent

Examples:
- Valid: tasks=["HaveCoffee"], user: "have coffee before checking news"
  → Edge: HaveCoffee → CheckNews exists in after_edges
- Valid: tasks=["WorkOut", "Study"], user: "work out then study"
  → Edges show correct sequential order
- Invalid: Task in tasks_to_move not found in graph
- Invalid: No change in edges (reorder didn't happen)
- Invalid: Circular reference created

Return:
- is_valid: true if reorder was correctly executed
- reason: Brief explanation of what's wrong (empty if valid)
- tasks_moved_exist: true if all tasks to move were found
- new_order_logical: true if new order matches user intent
- no_circular_refs: true if no circular references detected
""";

"""Edge label validation result"""
obj EdgeLabelValidationResult {
    has is_valid: bool;
    has reason: str;
    has missing_labels: list[str];
    has incorrect_labels: list[str];
}

"""Validate that edge labels match user's intent"""
def validate_edge_labels(
    user_message: str,
    new_edges: list[dict[str, str]]
) -> EdgeLabelValidationResult by llm();

sem validate_edge_labels = """
Validate that edge labels match the user's intent from their message.

CRITICAL EDGE LABEL RULES:
- "then" or "afterwards": Sequential tasks (A happens, then B happens)
- "while" or "at same time": PARALLEL tasks (A and B happen simultaneously)
- "if X" or "otherwise": CONDITIONAL branches (if X happens do A, otherwise do B)
- "either way": ONLY for CONDITIONAL convergence where if/otherwise branches merge
- After PARALLEL tasks converge, use "then" or "afterwards" (NOT "either way")

CHECK FOR COMMON MISTAKES:
1. "either way" used incorrectly (should only be for conditional convergence)
   - Parallel tasks converging: should use "then", not "either way"
   - Sequential tasks: should use "then", not "either way"
   - Only valid: "if X do A; otherwise do B; either way do C" (A->C, B->C both labeled "either way")
2. Sequential edge missing "then" label (has "either way" incorrectly)
3. Conditional branches missing condition labels ("if X") or "otherwise" labels
4. Parallel tasks not marked with "while" or "at same time"

ANALYSIS APPROACH:
- Parse user_message for conditional/parallel keywords
- Check if new_edges have labels reflecting those keywords
- Identify which edges are missing labels or have incorrect labels

Examples:
- Valid: User: "if raining, read book; otherwise, walk"
  → Edges: [{from: Check, to: ReadBook, label: "if raining"}, {to: Walk, label: "otherwise"}]
- Valid: User: "have drink while chatting, then head home, then call cab"
  → Edges: [{to: HaveDrink, label: "while"}, {to: ChatWithBuddies, label: "while"},
           {from: HaveDrink, to: HeadHome, label: "then"}, {from: ChatWithBuddies, to: HeadHome, label: "then"},
           {from: HeadHome, to: CallACab, label: "then"}]
- Invalid: Edge from HeadHome to CallACab uses "either way" label (should be "then")
- Invalid: "either way" used for parallel task convergence (should be "then")

Return:
- is_valid: true if edge labels match user intent
- reason: Brief explanation of what's wrong (empty if valid)
- missing_labels: List of descriptions for missing labels (e.g., ["condition on 'raining' edge"])
- incorrect_labels: List of descriptions for incorrect labels
""";
