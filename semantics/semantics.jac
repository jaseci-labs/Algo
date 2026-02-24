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
Extract CORE action task names. Strip conditional/temporal prefixes - they go in edge labels ONLY.

STRIP THESE PREFIXES from task names:
- "if X, I'll Y" → extract Y, put "if X" in edge label
- "otherwise I'll Y" → extract Y, put "otherwise" in edge label
- "when X, I'll Y" → extract Y, put "when X" in edge label
- "after X, I'll Y" → extract Y, put "after X" in edge label
- "then I'll Y" → extract Y, put "then" in edge label

Examples:
- "if it is raining I'll listen to the radio" → ListenToRadio
- "otherwise I'll do some gardening" → DoGardening
- "when I get home I'll check emails" → CheckEmails
- "after lunch I'll take a nap" → TakeANap
- "then I'll go to the gym" → GoToGym

Convert to CamelCase. Extract ALL actions mentioned.

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

# ========== Unified Semantic Functions for Latency Optimization ==========

"""Combined result from unified analysis"""
obj UnifiedAnalysisResult {
    has emotional_state: EmotionalState;
    has intent_analysis: IntentAnalysis;
    has extracted_tasks: ExtractedTasks;
    has attachment_analysis: AttachmentPointAnalysis;
}

"""Combined result from unified build and respond"""
obj UnifiedBuildResult {
    has relationships: list[TaskRelationship];
    has response: str;
    has thinking_summary: ThinkingSummary;
}

"""Unified analysis: emotion, intent, extraction, attachment in ONE LLM call"""
def unified_analyze_and_extract(
    user_message: str,
    conversation_history: list[dict[str, str]],
    existing_nodes: list[str],
    last_task: str
) -> UnifiedAnalysisResult by llm();

sem unified_analyze_and_extract = """
You are Algo's unified analyzer. Process the user's message comprehensively in ONE pass and return ALL 4 analysis results.

1. EMOTION DETECTION:
Classify the user's emotional state as: stressed | excited | indecisive | fatigued | neutral
- state = The detected emotion
- confidence = Score 0.0-1.0
- reasoning = Brief explanation

2. INTENT CLASSIFICATION:
- should_create_tasks = TRUE if user mentions ANY action/task (even casual: "check messages", "grab lunch"). Only FALSE for explicit questions ("what should I do?") or pure uncertainty ("maybe", "not sure")
- intent = COMMIT_ACTION (default for any action) | CORRECT_PREVIOUS (keywords: "actually", "before", "first") | CLARIFY_PREVIOUS ("no i meant", "after X") | ASK_QUESTION (explicit questions) | THINK_ALOUD ("maybe", "wondering")
- referring_to_task = EXACT task name from existing_nodes being referenced (e.g., "rename X to Y"→"X", "before Y"→"Y"). Empty if none.
- correction_type = rename (change task name) | insert_before | insert_after | insert_first | reorder | replace | empty
- needs_graph_rebuild = TRUE for corrections/clarifications with existing tasks, FALSE for simple additions
- is_insertion = TRUE if inserting task BETWEEN existing tasks
- tasks_to_move = List of existing task names being repositioned
- confidence = 0.0-1.0

3. TASK EXTRACTION (convert to CamelCase):
IMPORTANT - Strip these prefixes from task names (they go in edge labels ONLY):
- "if X, I'll Y" → extract Y only, put "if X" in edge label
- "otherwise I'll Y" → extract Y only, put "otherwise" in edge label
- "when X, I'll Y" → extract Y only, put "when X" in edge label
- "after X, I'll Y" → extract Y only, put "after X" in edge label
- "then I'll Y" → extract Y only, put "then" in edge label

Examples:
- "if it is raining I'll listen to the radio" → ListenToRadio
- "otherwise I'll do some gardening" → DoGardening
- "when I get home I'll check emails" → CheckEmails
- "after lunch I'll take a nap" → TakeANap
- "then I'll go to the gym" → GoToGym

SPECIAL MODES:
- RENAME MODE (correction_type='rename'): Populate renamed_to with NEW name only. raw_names=[], unique_names=[]
- REORDER MODE (correction_type='reorder' OR tasks_to_move populated): Use EXISTING names without numbers
- INSERTION MODE (is_insertion=True): Use existing names if they exist in existing_nodes
- NORMAL MODE: Append numbers for duplicates (MakeCoffee exists → MakeCoffee2)

4. ATTACHMENT POINTS:
- attachment_nodes = [last_task] default for additions. For "after X": [X]. For "before Y": find predecessor of Y in existing_nodes
- is_convergent = TRUE if multiple attachment points (parallel branches merging)
- reasoning = Brief explanation
- user_specified = TRUE if user explicitly named attachment task

Return ALL 4 results in proper JSON structure with no concatenation.
""";

"""Unified build: relationships, response, thinking in ONE LLM call"""
def unified_build_and_respond(
    user_message: str,
    emotional_state: EmotionalState,
    intent_analysis: IntentAnalysis,
    extracted_tasks: ExtractedTasks,
    attachment_analysis: AttachmentPointAnalysis,
    conversation_context: ConversationContext,
    current_edges: list[dict[str, str]]
) -> UnifiedBuildResult by llm();

sem unified_build_and_respond = """
You are Algo's unified builder. Build task relationships AND generate response AND generate thinking summary in ONE pass.

1. BUILD TASK RELATIONSHIPS:
CRITICAL DEFAULT BEHAVIOR - INCREMENTAL ADDITION:
For normal COMMIT_ACTION with needs_graph_rebuild=False: Return ONLY NEW relationships being added (do NOT include existing edges)

FULL REBUILD MODE (needs_graph_rebuild=True):
Return ALL relationships to reconstruct complete graph INCLUDING ALL EXISTING EDGES from current_edges
- Start by INCLUDING all relationships from current_edges
- For INSERTION: remove the edge being split (e.g., inserting between A->C, remove A->C)
- Add new edges: A->NewTask, NewTask->C

CONNECTION TYPES:
- SEQUENTIAL: "then", "after", "next", "afterwards"
- PARALLEL: "while", "as", "at same time", "simultaneously", "and" (tasks happening together)
- CONDITIONAL: "if", "when", "else", "otherwise"
- CONVERGENT: "either way" (ONLY for conditional branches merging)

EDGE LABELS:
- "then" or "afterwards": Default for sequential
- "while" or "at same time": For parallel
- "if X" or "otherwise": For conditional
- "either way": ONLY for conditional convergence (not parallel)

PARALLEL TASKS RULE:
When user says "while X do Y and Z":
- Create N relationships, ALL with SAME from_task (attachment_nodes[0])
- ALL use connection_type = PARALLEL
- Each goes to a different task
- sequence_order: 1, 2, 3...

Example: "have drink while chatting with buddies, then head home"
→ HaveDrink[from=HeadToThePub, label="while"], ChatWithBuddies[from=HeadToThePub, label="while"]
→ HeadHome[from=HaveDrink, label="then"], HeadHome[from=ChatWithBuddies, label="then"]

CONDITIONAL EXAMPLE:
"if raining read book otherwise walk either way go home"
→ IfRaining→ReadBook[label="if raining"], Otherwise→Walk[label="otherwise"]
→ ReadBook→GoHome[label="either way"], Walk→GoHome[label="either way"]

Each TaskRelationship must have separate fields:
{
  "connection_type": "SEQUENTIAL",
  "from_task": "CheckMessages",
  "to_task": "MakeBreakfast",
  "edge_label": "then",
  "sequence_order": 1
}

2. GENERATE RESPONSE:
Match the emotional_state tone. Natural acknowledgment ("Got it!", "Alright!", "Sounds good!") - NOT "Task added". 1-3 sentences, use contractions, no jargon.

3. GENERATE THINKING SUMMARY:
- emotional_insight = "You seem {state} right now" (empty if confidence < 0.7)
- intent_insight = "You're [action]" for corrections, empty for simple COMMIT_ACTION
- task_insight = "Adding: [TaskName]" for single OR "Extracted: [Task1], [Task2]" for multiple. Add "(parallel)" if parallel pattern detected
- pattern_insight = Empty for simple sequential. For parallel: "These happen at the same time". For conditional: "These are conditional options"

Keep all bullets under 10 words. Conversational and natural.

Return ALL 3 results in proper JSON structure.
""";

# ========== Fast Response Functions ==========

"""Quick response result for immediate feedback"""
obj QuickResponseResult {
    has emotional_state: EmotionalState;
    has intent_analysis: IntentAnalysis;
    has extracted_tasks: ExtractedTasks;
    has attachment_analysis: AttachmentPointAnalysis;
    has response: str;
    has thinking: dict[str, str];
}

"""Fast analysis and response in ONE LLM call - for immediate user feedback"""
def quick_analyze_and_respond(
    user_message: str,
    conversation_history: list[dict[str, str]],
    existing_nodes: list[str],
    last_task: str
) -> QuickResponseResult by llm();

sem quick_analyze_and_respond = """
You are Algo. Analyze the user's message and respond IMMEDIATELY. Do everything in ONE pass.

1. EMOTION DETECTION:
Classify emotional state: stressed | excited | indecisive | fatigued | neutral
- state = detected emotion
- confidence = 0.0-1.0
- reasoning = brief explanation

2. INTENT CLASSIFICATION:
- should_create_tasks = TRUE if user mentions ANY action/task (even casual). Only FALSE for explicit questions
- intent = COMMIT_ACTION (default) | CORRECT_PREVIOUS | CLARIFY_PREVIOUS | ASK_QUESTION | THINK_ALOUD
- referring_to_task = EXACT task name from existing_nodes being referenced
- correction_type = rename | insert_before | insert_after | insert_first | reorder | replace | empty
- needs_graph_rebuild = TRUE for corrections, FALSE for simple additions
- confidence = 0.0-1.0

3. TASK EXTRACTION (convert to CamelCase):
Strip prefixes: "if X, I'll Y" → extract Y only, put "if X" in edge label
"otherwise I'll Y" → extract Y only, put "otherwise" in edge label

SPECIAL MODES:
- RENAME MODE: renamed_to = NEW name only, raw_names=[]
- REORDER MODE: use EXISTING names without numbers
- INSERTION MODE: use existing names if in existing_nodes
- NORMAL MODE: Append numbers for duplicates

4. ATTACHMENT POINTS:
- attachment_nodes = [last_task] default for additions
- is_convergent = TRUE if multiple attachment points
- reasoning = brief explanation

5. GENERATE RESPONSE:
Match emotional_state tone. Natural acknowledgment ("Got it!", "Alright!", "Sounds good!") - NOT "Task added". 1-3 sentences, use contractions, no jargon.

Return ALL 5 results in proper JSON structure.
""";

"""Task validation result"""
obj TaskValidationResult {
    has is_valid: bool;
    has reason: str;
    has missing_tasks: list[str];
    has incorrect_task: str;      # Existing task with wrong name that should be renamed
    has correct_task_name: str;    # What the task should be renamed to
}

"""Validate that extracted tasks match the user's message"""
def validate_task_extraction(
    user_message: str,
    extracted_tasks: list[str],
    existing_nodes: list[str]
) -> TaskValidationResult by llm();

sem validate_task_extraction = """
Validate if the extracted tasks correctly capture ALL actions/activities mentioned in the user's message.

CRITICAL: Look for:
1. Conditional statements: "if X, then Y; otherwise Z" → BOTH tasks should be extracted
2. Multiple activities in one message: "I'll do X and then Y" → BOTH tasks should be extracted
3. Parallel tasks: "while X, I'll also Y" → BOTH tasks should be extracted
4. Alternative scenarios: "if I have time I'll X, otherwise I'll Y" → BOTH tasks should be extracted
5. TASK NAME CORRECTION: If extracted task is similar to an existing task but missing a verb or has wrong wording, signal a RENAME

TASK NAME CORRECTION (rename needed):
- Compare extracted_tasks with existing_nodes
- If an extracted task is SEMANTICALLY THE SAME as an existing task but has a better/complete name:
  * Set is_valid = false
  * Set incorrect_task = the existing task with wrong/incomplete name
  * Set correct_task_name = the better extracted task name
  * Set reason = explanation of why rename is needed
  * Set missing_tasks = [] (empty - no new task needed, just rename)
- Examples of rename needed:
  * existing_nodes: ["TheGoodPlace"], extracted: ["WatchTheGoodPlace"]
    → incorrect_task="TheGoodPlace", correct_task_name="WatchTheGoodPlace", reason="TheGoodPlace should be renamed to WatchTheGoodPlace to include the verb 'Watch'"
  * existing_nodes: ["Gym"], extracted: ["HeadToGym"]
    → incorrect_task="Gym", correct_task_name="HeadToGym", reason="Gym should be renamed to HeadToGym to include the action verb"
  * existing_nodes: ["Messages"], extracted: ["CheckMessages"]
    → incorrect_task="Messages", correct_task_name="CheckMessages", reason="Messages should be renamed to CheckMessages to clarify the action"

Examples of INCORRECT extraction (missing tasks):
- User: "If I have assignments due I will work on them, if not I will netflix and chill"
  Extracted: ["NetflixAndChill"] → INVALID (missing "WorkOnAssignments")
- User: "I'll make coffee and then check my emails"
  Extracted: ["MakeCoffee"] → INVALID (missing "CheckEmails")
- User: "While brushing my teeth, I'll also check the news"
  Extracted: ["BrushTeeth"] → INVALID (missing "CheckNews")

Return:
- is_valid: true if ALL tasks mentioned are captured correctly, false otherwise
- reason: Brief explanation of what's wrong
- missing_tasks: List of task names that were missed (empty if rename needed or if valid)
- incorrect_task: Empty string if valid or if missing tasks; set to existing task name if rename needed
- correct_task_name: Empty string if valid or if missing tasks; set to the correct name if rename needed
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

#===========================================================
#               ANALYTICS INSIGHTS FUNCTIONS
#===========================================================

"""Personalized insight for analytics"""
obj PersonalizedInsight {
    has title: str;
    has description: str;
    has category: str;
    has actionable: bool;
}

"""Generate personalized insights based on user's activity patterns"""
def generate_personalized_insights(
    total_tasks: int,
    consistency_score: float,
    efficiency_score: float,
    current_streak: int,
    peak_hour: str,
    peak_day: str,
    total_events: int,
    emotion_distribution: dict,
    connection_patterns: dict
) -> list[PersonalizedInsight] by llm();

sem generate_personalized_insights = """
Generate 3-4 personalized, actionable insights based on the user's actual activity data.

INPUT ANALYSIS:
- total_tasks: How many tasks user has created (higher = more active)
- consistency_score: 0-100 (higher = more consistent daily activity)
- efficiency_score: 0-100 (higher = better task connections/routine complexity)
- current_streak: Consecutive days of activity
- peak_hour: Hour (0-23) when user is most active
- peak_day: Day of week when user is most active
- total_events: Total tracked events
- emotion_distribution: Distribution of emotional states (stressed, excited, focused, etc.)
- connection_patterns: How user connects tasks (sequential, parallel, conditional, convergent)

INSIGHT CATEGORIES:
1. PRODUCTIVITY: Patterns in task creation, peak productivity times, streaks
2. CONSISTENCY: Daily activity patterns, engagement trends
3. BEHAVIORAL: Emotional patterns, connection style preferences
4. RECOMMENDATIONS: Actionable suggestions based on data

GENERATION RULES:
- Each insight MUST be based on the actual numeric data provided
- Be specific: mention actual numbers (e.g., "12 tasks", "85% score", "5-day streak")
- Be encouraging but honest about areas for improvement
- Make recommendations actionable (specific things to try)
- Vary categories - don't give all productivity or all behavioral insights
- For new users (total_tasks < 5): Focus on getting started insights
- For active users (total_tasks >= 5): Focus on optimization insights

EXAMPLE INSIGHTS:
PRODUCTIVITY (when streak > 3):
- title: "On Fire!"
- description: "You're on a 5-day streak! Your consistency is impressive. Keep the momentum going."
- category: "productivity"
- actionable: false

PRODUCTIVITY (when peak_hour shows clear pattern):
- title: "Peak Productivity"
- description: "You're most active around 9 AM. Schedule your most important tasks then for maximum productivity."
- category: "productivity"
- actionable: true

CONSISTENCY (when consistency_score is high):
- title: "Rock Steady"
- description: "Your 85% consistency score shows real dedication. You're building great habits!"
- category: "consistency"
- actionable: false

BEHAVIORAL (when emotion_distribution shows stressed):
- title: "Take It Easy"
- description: "You seem stressed during your sessions. Consider breaking larger tasks into smaller, manageable steps."
- category: "behavioral"
- actionable: true

RECOMMENDATIONS (when connection_patterns are mostly sequential):
- title: "Try Parallel Tasks"
- description: "You mostly use sequential connections. Try using 'while' to create parallel workflows and save time."
- category: "recommendations"
- actionable: true

RECOMMENDATIONS (when total_events is low):
- title: "Build Your Routine"
- description: "Start by adding 3-5 tasks you do every day. Track them to see your patterns emerge."
- category: "recommendations"
- actionable: true

OUTPUT FORMAT:
Return a list of PersonalizedInsight objects with exactly these fields:
- title: Short, catchy headline (2-4 words)
- description: 1-2 sentences explaining the insight
- category: "productivity" | "consistency" | "behavioral" | "recommendations"
- actionable: true if user can take action, false if just observation
""";

# ========== Enhanced Analytics Semantic Functions ==========

"""Represents a discovered routine pattern"""
obj RoutinePattern {
    has pattern_name: str;
    has task_sequence: list[str];
    has frequency: int;
    has confidence: float;
    has time_context: str;
    has description: str;
}

"""Discover repeated task sequences that form routines"""
def discover_routine_patterns(
    activity_events: list[dict],
    task_graph_nodes: list[str],
    task_graph_edges: list[dict],
    time_window_days: int = 30
) -> list[RoutinePattern] by llm();

sem discover_routine_patterns = """
Analyze activity events and task graph to discover repeated task sequences that form routines.

INPUT:
- activity_events: List of events with timestamps and task names
- task_graph_nodes: All task names in the graph
- task_graph_edges: Connections between tasks with labels
- time_window_days: Lookback period for analysis

ANALYSIS:
1. Identify task sequences that repeat across multiple sessions/days
2. Look for common patterns like morning routines, work workflows, evening wind-downs
3. Consider time context (morning, afternoon, evening, night, weekend)
4. Calculate confidence based on frequency and consistency

OUTPUT:
Return list of RoutinePattern objects:
- pattern_name: Descriptive name (e.g., "Morning Routine", "Work Start")
- task_sequence: Ordered list of task names in the pattern
- frequency: How many times this pattern was detected
- confidence: 0.0-1.0 score of pattern reliability
- time_context: "morning", "afternoon", "evening", "night", "weekend", "any"
- description: Brief description of the pattern

Only return patterns with frequency >= 2 and confidence >= 0.5.
""";

"""Represents temporal pattern insights"""
obj TemporalInsight {
    has insight_type: str;
    has description: str;
    has peak_hours: list[int];
    has peak_days: list[str];
    has confidence: float;
    has actionable_recommendation: str;
}

"""Analyze temporal patterns in user activity"""
def analyze_temporal_patterns(
    activity_events: list[dict],
    lookback_days: int = 30
) -> list[TemporalInsight] by llm();

sem analyze_temporal_patterns = """
Analyze activity timestamps to discover when user is most active and productive.

INPUT:
- activity_events: List of events with timestamps (format: YYYY-MM-DDTHH:MM:SS)
- lookback_days: How many days to analyze

ANALYSIS:
1. Extract hour (0-23) and day of week from timestamps
2. Identify peak hours (most activity) and peak days
3. Look for patterns like "weekend warrior", "morning person", "night owl"
4. Calculate confidence based on data consistency

OUTPUT:
Return list of TemporalInsight objects:
- insight_type: "peak_hours", "peak_days", "productivity_windows", "temporal_pattern"
- description: Human-readable description of the pattern
- peak_hours: List of hours (0-23) with highest activity
- peak_days: List of day names with highest activity
- confidence: 0.0-1.0 score
- actionable_recommendation: Suggestion based on pattern

Be specific with times. Instead of "morning", say "9-11 AM".
""";

"""Represents comparison insights between time periods"""
obj ComparisonInsight {
    has comparison_type: str;
    has current_period: dict;
    has previous_period: dict;
    has change_percentage: float;
    has trend: str;
    has narrative: str;
}

"""Generate comparative insights between time periods"""
def generate_comparative_insights(
    current_period_events: list[dict],
    previous_period_events: list[dict],
    period_type: str = "week"
) -> list[ComparisonInsight] by llm();

sem generate_comparative_insights = """
Compare activity between two time periods to identify trends.

INPUT:
- current_period_events: Events from current period (this week/month)
- previous_period_events: Events from previous period (last week/month)
- period_type: "week" or "month"

ANALYSIS:
1. Count events in each period
2. Calculate percentage change
3. Determine trend: "improving", "declining", "stable"
4. Generate narrative explaining the change

OUTPUT:
Return list of ComparisonInsight objects:
- comparison_type: "week_over_week" or "month_over_month"
- current_period: Dict with current stats (total_events, active_days, etc.)
- previous_period: Dict with previous stats
- change_percentage: Percentage change (positive = increase)
- trend: "improving", "declining", or "stable"
- narrative: Human-readable explanation of the change

Focus on meaningful changes. Small fluctuations (<10%) should be marked "stable".
""";

"""Check if proactive insight should be triggered"""
def should_trigger_proactive_insight(
    recent_events: list[dict],
    user_goals: list[dict],
    current_streak: int,
    last_insight_time: str,
    user_context: dict
) -> dict by llm();

sem should_trigger_proactive_insight = """
Determine if a proactive insight should be triggered based on user state.

INPUT:
- recent_events: Recent activity events
- user_goals: Current user goals with progress
- current_streak: Current activity streak
- last_insight_time: When last insight was delivered
- user_context: Additional context (time since last activity, session count, etc.)

TRIGGERS:
1. STREAK_AT_RISK: User hasn't been active today but has active streak
2. ACHIEVEMENT_UNLOCKED: User earned a new achievement
3. GOAL_MILESTONE: User reached 50%, 75%, or 100% of goal
4. PATTERN_DETECTED: New routine pattern discovered
5. ENCOURAGEMENT_NEEDED: User activity declined significantly
6. RETURNING_USER: User back after absence

OUTPUT:
Return dict with:
- should_trigger: true or false
- insight_type: Type of insight to trigger
- urgency: "low", "medium", or "high"
- message: Specific message for the insight

Only trigger if truly valuable. Avoid spam.
""";
