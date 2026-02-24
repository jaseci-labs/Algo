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

sem ConversationContext.intent = "COMMIT_ACTION: new task commitment | CORRECT_PREVIOUS: 'actually', 'before', 'first' corrections | CLARIFY_PREVIOUS: 'no i meant', 'after X' clarifications | ASK_QUESTION: questions | THINK_ALOUD: wondering/maybe";
sem ConversationContext.referring_to_task = "Which existing task is user referring to? Empty if none, or exact task name from existing_nodes";
sem ConversationContext.correction_type = "For CORRECT_PREVIOUS: 'rename', 'insert_before', 'insert_after', 'insert_first', 'reorder', 'replace' | For CLARIFY_PREVIOUS: 'attachment_point', 'sequence_order' | Empty otherwise";
sem ConversationContext.needs_graph_rebuild = "TRUE for CORRECT_PREVIOUS or CLARIFY_PREVIOUS with existing tasks, FALSE for COMMIT_ACTION on empty/simple graphs";
sem ConversationContext.is_insertion = "TRUE if user wants to insert task BETWEEN existing tasks (keywords: 'before X', 'after Y but before Z', 'between', 'insert')";
sem ConversationContext.tasks_to_move = "List of existing task names being repositioned. Example: user says 'have coffee first' when HaveCoffee exists → ['HaveCoffee']";

"""Intent and commitment analysis result"""
obj IntentAnalysis {
    has should_create_tasks: bool;
    has conversation_context: ConversationContext;
    has confidence: float;
}

sem IntentAnalysis.should_create_tasks = "TRUE if user committed to action OR is correcting/reordering existing tasks. FALSE only for questions/thinking/uncertain. CRITICAL: Corrections and reorderings NEED graph updates";
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
Analyze user's message and conversation history to classify their intent.

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
- Set should_create_tasks = True
- Set correction_type = 'reorder'
- Set needs_graph_rebuild = True
- Populate tasks_to_move with the task names being repositioned

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
    has renamed_to: str;  # For rename operations: the new task name ONLY
}

sem ExtractedTasks.raw_names = "Base task names in CamelCase extracted from message (e.g., CheckEmail, MakeCoffee)";
sem ExtractedTasks.unique_names = "NEW unique task names. If correction_type='insert_before' OR is_insertion=True, use existing task names WITHOUT numbers. Otherwise, append numbers for duplicates: if count>0 then raw_name+str(count+1) else raw_name";
sem ExtractedTasks.name_mappings = "List of {raw: str, unique: str, count: int} showing transformation for each task";
sem ExtractedTasks.duplicate_counts = "For each raw_name, how many times it appears in existing_nodes";
sem ExtractedTasks.renamed_to = "For rename operations: the new task name ONLY. Populated when correction_type='rename'. Empty string otherwise";

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
- Populate renamed_to with the new task name (after "to" or "instead")
- Leave raw_names and unique_names empty

REORDERING MODE (correction_type='reorder' OR tasks_to_move populated):
- Extract task names being reordered from user_message
- Use EXISTING names without adding numbers

CORRECTION/INSERTION MODE (is_insertion=True OR correction_type='insert_before' OR keywords 'before', 'after', 'between', 'instead'):
- If task exists in existing_nodes, use EXISTING name without adding numbers

NORMAL MODE:
- Append numbers for duplicates: if count>0 then raw_name+str(count+1) else raw_name

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
Determine where new tasks should connect in the graph.

INSERTION PATTERN (user says "BEFORE X"):
- Find the task BEFORE the referenced task in existing graph
- attachment_nodes = [task that currently connects TO the referenced task]

If needs_graph_rebuild = True: return empty attachment_nodes.
Default: attachment_nodes = [last_task]
User-specified: Parse user_message for "after X", "before Y", "from Z"
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
1. EXPLICIT: Keywords "either way", "regardless", "in both cases", "afterwards"
2. IMPLICIT: last_task contains "|" (e.g., "GoToGym|GoForRun") and user adds task without naming specific source
3. NO convergence: User names specific task or linear flow

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
Each TaskRelationship object MUST have separate fields. NEVER concatenate.

DEFAULT BEHAVIOR (needs_graph_rebuild=False):
Return ONLY the NEW relationships being added.

FULL REBUILD MODE (needs_graph_rebuild=True):
Return ALL relationships including existing from current_edges. For insertions, remove the edge being split and add new edges.

CRITICAL: USE ACTUAL TASK NAMES
from_task MUST be an actual task name from attachment_nodes.
to_task MUST be from extracted_tasks.unique_names.
NEVER use placeholders like "last_task".

CONNECTION RULES:
- Start: attachment_nodes[0] → first extracted task
- SEQUENTIAL: chain tasks (A→B→C)
- PARALLEL: all from same source with connection_type=PARALLEL
- sequence_order: 1, 2, 3... for ordering

EDGE LABELS:
- "then"/"afterwards": sequential
- "while"/"at same time": parallel
- "if X"/"otherwise": conditional
- "either way": ONLY for conditional convergence

PARALLEL CONVERGENCE:
Multiple attachment_nodes → first extracted task with "then" label.

CONDITIONAL CONVERGENCE:
Use "either way" only when user says it explicitly.
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
4. pattern_insight: Only for special patterns
   - PARALLEL: "These will happen at the same time"
   - Duplicates: "This is your [X]th time doing this"

Keep all bullets under 10 words. Be conversational.
""";

"""Task validation result"""
obj TaskValidationResult {
    has is_valid: bool;
    has reason: str;
    has missing_tasks: list[str];
    has incorrect_task: str;      # Existing task with wrong name that should be renamed
    has correct_task_name: str;    # What the task should be renamed to
}

sem TaskValidationResult.is_valid = "TRUE if ALL tasks mentioned in user message were correctly extracted";
sem TaskValidationResult.reason = "Brief explanation of what's wrong. Empty if valid";
sem TaskValidationResult.missing_tasks = "List of task names that were missed. Empty if valid or if rename needed";
sem TaskValidationResult.incorrect_task = "Existing task with wrong/incomplete name that should be renamed. Empty if valid or if missing tasks";
sem TaskValidationResult.correct_task_name = "The correct task name for rename. Empty if valid or if missing tasks";

"""Validate that extracted tasks match the user's message"""
def validate_task_extraction(
    user_message: str,
    extracted_tasks: list[str],
    existing_nodes: list[str]
) -> TaskValidationResult by llm();

sem validate_task_extraction = """
Validate if extracted tasks correctly capture ALL actions/activities mentioned.

CRITICAL CHECKS:
1. Conditional statements: "if X, then Y; otherwise Z" → BOTH tasks extracted
2. Multiple activities: "I'll do X and then Y" → BOTH tasks extracted
3. Parallel tasks: "while X, I'll also Y" → BOTH tasks extracted
4. TASK NAME CORRECTION: If extracted task is similar to existing but missing verb, signal RENAME

RENAME NEEDED:
- Compare extracted_tasks with existing_nodes
- If SEMANTICALLY SAME but better name: is_valid=false, incorrect_task=existing name, correct_task_name=better name, missing_tasks=[]

INVALID (missing tasks examples):
- "If assignments due I'll work, if not netflix" → Only "NetflixAndChill" is INVALID (missing "WorkOnAssignments")
- "make coffee and check emails" → Only "MakeCoffee" is INVALID (missing "CheckEmails")
""";

"""Graph structure validation result"""
obj GraphValidationResult {
    has is_valid: bool;
    has reason: str;
    has expected_structure: str;
}

sem GraphValidationResult.is_valid = "TRUE if the graph structure correctly represents user's intent for new tasks";
sem GraphValidationResult.reason = "Brief explanation of what's wrong. Empty if valid";
sem GraphValidationResult.expected_structure = "Description of what SHOULD exist. Empty if valid";

"""Validate that graph structure matches user's intent"""
def validate_graph_structure(
    user_message: str,
    graph_nodes: list[str],
    graph_edges: list[dict[str, str]]
) -> GraphValidationResult by llm();

sem validate_graph_structure = """
Validate if graph structure correctly represents user's intent for NEWLY ADDED tasks.

IMPORTANT CONTEXT:
- graph_nodes: ONLY newly added task names
- graph_edges: ONLY edges involving new tasks (as "to" destination)
- "from" task is typically pre-existing (EXPECTED and VALID)

CHECK FOR:
1. Conditional: "if X then Y, otherwise Z" → proper conditional structure
2. Sequential: "do X then Y" → both added with X→Y edge
3. Parallel: "while X, also Y" → both branch from same source
4. Convergence: "either way" → tasks merge

INVALID EXAMPLES:
- "make coffee and check emails" → Only ["MakeCoffee"] added → INVALID (missing "CheckEmails")
- "if assignments work, otherwise netflix" → Only ["NetflixAndChill"] → INVALID (missing "WorkOnAssignments")
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

sem RenameValidationResult.is_valid = "TRUE if rename operation was executed correctly";
sem RenameValidationResult.reason = "Brief explanation of what's wrong. Empty if valid";
sem RenameValidationResult.old_task_found = "TRUE if old task existed in before_nodes";
sem RenameValidationResult.new_task_unique = "TRUE if new task doesn't conflict with existing tasks";
sem RenameValidationResult.edges_updated = "TRUE if all edges were correctly updated";

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
Validate rename operation executed correctly.

CRITICAL CHECKS:
1. Old task existed in before_nodes
2. New task is in after_nodes
3. New task ≠ old task (actual rename)
4. Old task NOT in after_nodes
5. All edges now reference new_task
6. No duplicate tasks

INVALID EXAMPLES:
- Old task not found in before_nodes
- New task same as old (no rename)
- Old task still exists (incomplete)
- Edges still reference old task
""";

"""Insert validation result"""
obj InsertValidationResult {
    has is_valid: bool;
    has reason: str;
    has insert_position_correct: bool;
    has referring_task_exists: bool;
    has no_orphans: bool;
}

sem InsertValidationResult.is_valid = "TRUE if insert operation positioned tasks correctly";
sem InsertValidationResult.reason = "Brief explanation of what's wrong. Empty if valid";
sem InsertValidationResult.insert_position_correct = "TRUE if position matches operation type (insert_before/insert_after/insert_first)";
sem InsertValidationResult.referring_task_exists = "TRUE if referring task was found in graph";
sem InsertValidationResult.no_orphans = "TRUE if no disconnected tasks exist";

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
Validate insert operation positioned tasks correctly.

OPERATION TYPES:
- insert_before: New tasks BEFORE referring_to_task
- insert_after: New tasks AFTER referring_to_task
- insert_first: New tasks at beginning (after Start)

CRITICAL CHECKS:
1. Referring task exists (or "Start" for insert_first)
2. New tasks were added
3. Position matches operation type (edge direction correct)
4. No orphaned tasks

VALID EXAMPLES:
- insert_before, referring="CheckMessages", new="WashFace" → Edge: WashFace→CheckMessages exists
- insert_after, referring="MakeCoffee", new="HaveBreakfast" → Edge: MakeCoffee→HaveBreakfast exists
""";

"""Reorder validation result"""
obj ReorderValidationResult {
    has is_valid: bool;
    has reason: str;
    has tasks_moved_exist: bool;
    has new_order_logical: bool;
    has no_circular_refs: bool;
}

sem ReorderValidationResult.is_valid = "TRUE if reorder operation moved tasks correctly";
sem ReorderValidationResult.reason = "Brief explanation of what's wrong. Empty if valid";
sem ReorderValidationResult.tasks_moved_exist = "TRUE if all tasks to move were found in graph";
sem ReorderValidationResult.new_order_logical = "TRUE if new order matches user intent";
sem ReorderValidationResult.no_circular_refs = "TRUE if no circular references detected";

"""Validate that a reorder operation moved tasks correctly"""
def validate_reorder_operation(
    user_message: str,
    tasks_to_move: list[str],
    before_edges: list[dict[str, str]],
    after_edges: list[dict[str, str]]
) -> ReorderValidationResult by llm();

sem validate_reorder_operation = """
Validate reorder operation moved tasks correctly.

CRITICAL CHECKS:
1. All tasks in tasks_to_move exist
2. New position matches user's description
3. No circular references (A→B→...→A)
4. All affected tasks remain connected
5. Edges actually changed

VALID EXAMPLES:
- tasks=["HaveCoffee"], user: "have coffee before checking news" → HaveCoffee→CheckNews exists
- tasks=["WorkOut", "Study"], user: "work out then study" → correct sequential order

INVALID EXAMPLES:
- Task not found in graph
- No change in edges (reorder didn't happen)
- Circular reference created
""";

"""Edge label validation result"""
obj EdgeLabelValidationResult {
    has is_valid: bool;
    has reason: str;
    has missing_labels: list[str];
    has incorrect_labels: list[str];
}

sem EdgeLabelValidationResult.is_valid = "TRUE if edge labels match user's intent from their message";
sem EdgeLabelValidationResult.reason = "Brief explanation of what's wrong. Empty if valid";
sem EdgeLabelValidationResult.missing_labels = "List of descriptions for missing labels (e.g., ['condition on raining edge'])";
sem EdgeLabelValidationResult.incorrect_labels = "List of descriptions for incorrect labels";

"""Validate that edge labels match user's intent"""
def validate_edge_labels(
    user_message: str,
    new_edges: list[dict[str, str]]
) -> EdgeLabelValidationResult by llm();

sem validate_edge_labels = """
Validate edge labels match user's intent.

EDGE LABEL RULES:
- "then"/"afterwards": Sequential
- "while"/"at same time": PARALLEL
- "if X"/"otherwise": CONDITIONAL
- "either way": ONLY for conditional convergence (NOT parallel)

COMMON MISTAKES:
1. "either way" on parallel convergence → should be "then"
2. "either way" on sequential → should be "then"
3. Missing "if X" or "otherwise" labels
4. Parallel tasks missing "while" label

VALID: "if X do A; otherwise do B; either way do C" → A->C, B->C both "either way"
INVALID: Parallel tasks converge with "either way" → should use "then"
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

sem PersonalizedInsight.title = "Short, catchy headline (2-4 words)";
sem PersonalizedInsight.description = "1-2 sentences explaining the insight";
sem PersonalizedInsight.category = "productivity | consistency | behavioral | recommendations";
sem PersonalizedInsight.actionable = "TRUE if user can take action, FALSE if just observation";

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
Generate 3-4 personalized, actionable insights based on actual activity data.

CATEGORIES: productivity | consistency | behavioral | recommendations

RULES:
- Base insights on actual numeric data (mention specific numbers)
- Be specific: "12 tasks", "85% score", "5-day streak"
- Vary categories (not all same type)
- New users (<5 tasks): focus on getting started
- Active users (>=5 tasks): focus on optimization

EXAMPLE INSIGHTS:
- streak > 3: title="On Fire!", description="5-day streak!", category=productivity
- peak_hour pattern: title="Peak Productivity", description="Most active at 9 AM", actionable=true
- high consistency: title="Rock Steady", description="85% consistency shows dedication"
- stressed: title="Take It Easy", description="Break tasks into smaller steps"
- sequential only: title="Try Parallel Tasks", description="Use 'while' for parallel workflows"
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

sem RoutinePattern.pattern_name = "Descriptive name (e.g., 'Morning Routine', 'Work Start')";
sem RoutinePattern.task_sequence = "Ordered list of task names in the pattern";
sem RoutinePattern.frequency = "How many times this pattern was detected";
sem RoutinePattern.confidence = "0.0-1.0 score of pattern reliability";
sem RoutinePattern.time_context = "morning | afternoon | evening | night | weekend | any";
sem RoutinePattern.description = "Brief description of the pattern";

"""Discover repeated task sequences that form routines"""
def discover_routine_patterns(
    activity_events: list[dict],
    task_graph_nodes: list[str],
    task_graph_edges: list[dict],
    time_window_days: int = 30
) -> list[RoutinePattern] by llm();

sem discover_routine_patterns = """
Analyze events and graph to discover repeated task sequences forming routines.

ANALYSIS:
1. Identify sequences repeating across sessions/days
2. Look for patterns: morning routines, work workflows, evening wind-downs
3. Consider time context: morning/afternoon/evening/night/weekend
4. Calculate confidence from frequency and consistency

OUTPUT: RoutinePattern objects
- pattern_name: Descriptive (e.g., "Morning Routine")
- task_sequence: Ordered task names
- frequency: Times detected
- confidence: 0.0-1.0
- time_context: morning|afternoon|evening|night|weekend|any
- description: Brief description

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

sem TemporalInsight.insight_type = "peak_hours | peak_days | productivity_windows | temporal_pattern";
sem TemporalInsight.description = "Human-readable description of the pattern";
sem TemporalInsight.peak_hours = "List of hours (0-23) with highest activity";
sem TemporalInsight.peak_days = "List of day names with highest activity";
sem TemporalInsight.confidence = "0.0-1.0 score";
sem TemporalInsight.actionable_recommendation = "Suggestion based on pattern";

"""Analyze temporal patterns in user activity"""
def analyze_temporal_patterns(
    activity_events: list[dict],
    lookback_days: int = 30
) -> list[TemporalInsight] by llm();

sem analyze_temporal_patterns = """
Analyze timestamps to discover when user is most active.

ANALYSIS:
1. Extract hour (0-23) and day of week
2. Identify peak hours and peak days
3. Look for patterns: "weekend warrior", "morning person", "night owl"
4. Calculate confidence from consistency

OUTPUT: TemporalInsight objects
- insight_type: peak_hours|peak_days|productivity_windows|temporal_pattern
- description: Human-readable pattern description
- peak_hours: List of hours (0-23) with highest activity
- peak_days: List of day names with highest activity
- confidence: 0.0-1.0
- actionable_recommendation: Suggestion based on pattern

Be specific: "9-11 AM" not "morning".
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

sem ComparisonInsight.comparison_type = "week_over_week | month_over_month";
sem ComparisonInsight.current_period = "Dict with current stats (total_events, active_days, etc.)";
sem ComparisonInsight.previous_period = "Dict with previous stats";
sem ComparisonInsight.change_percentage = "Percentage change (positive = increase)";
sem ComparisonInsight.trend = "improving | declining | stable";
sem ComparisonInsight.narrative = "Human-readable explanation of the change";

"""Generate comparative insights between time periods"""
def generate_comparative_insights(
    current_period_events: list[dict],
    previous_period_events: list[dict],
    period_type: str = "week"
) -> list[ComparisonInsight] by llm();

sem generate_comparative_insights = """
Compare activity between time periods to identify trends.

ANALYSIS:
1. Count events in each period
2. Calculate percentage change
3. Determine trend: improving|declining|stable
4. Generate narrative

OUTPUT: ComparisonInsight objects
- comparison_type: week_over_week|month_over_month
- current_period: Dict with current stats
- previous_period: Dict with previous stats
- change_percentage: Positive = increase
- trend: improving|declining|stable
- narrative: Human-readable explanation

Small fluctuations (<10%) = stable.
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
Determine if proactive insight should be triggered.

TRIGGERS:
1. STREAK_AT_RISK: Not active today but has streak
2. ACHIEVEMENT_UNLOCKED: New achievement
3. GOAL_MILESTONE: Reached 50%, 75%, or 100% of goal
4. PATTERN_DETECTED: New routine pattern
5. ENCOURAGEMENT_NEEDED: Activity declined
6. RETURNING_USER: Back after absence

OUTPUT: dict with
- should_trigger: true/false
- insight_type: Type to trigger
- urgency: low|medium|high
- message: Specific message

Only trigger if valuable. Avoid spam.
""";
