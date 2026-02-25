"""Semantic objects and AI-powered functions for Algo's natural language understanding."""

import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4.1");

#===========================================================
#                     ENUMS
#===========================================================

"""Emotional state values"""
enum Emotion {
    STRESSED, EXCITED, INDECISIVE, FATIGUED, NEUTRAL
}

sem Emotion = "User's emotional state: STRESSED (frustration/overwhelm), EXCITED (enthusiastic), INDECISIVE (uncertain), FATIGUED (tired/exhausted), NEUTRAL (calm/normal)";

"""Conversation intent classification"""
enum ConversationIntent {
    COMMIT_ACTION,
    CORRECT_PREVIOUS,
    CLARIFY_PREVIOUS,
    ASK_QUESTION,
    THINK_ALOUD
}

sem ConversationIntent = "User's intent: COMMIT_ACTION (task mentioned), CORRECT_PREVIOUS ('actually', 'before', 'instead'), CLARIFY_PREVIOUS ('no I meant'), ASK_QUESTION (questions), THINK_ALOUD ('maybe', 'wondering')";

"""Correction type for graph modifications"""
enum CorrectionType {
    NONE, RENAME, INSERT_BEFORE, INSERT_AFTER, INSERT_FIRST,
    REORDER, REPLACE, ATTACHMENT_POINT, SEQUENCE_ORDER
}

sem CorrectionType = "NONE (no correction - default for new task additions), RENAME (change task name), INSERT_BEFORE (add before existing task), INSERT_AFTER (add after existing task), INSERT_FIRST (add at beginning), REORDER (change task order), REPLACE (swap tasks), ATTACHMENT_POINT (specify where to connect), SEQUENCE_ORDER (specify execution order)";

"""Task connection type"""
enum ConnectionType {
    SEQUENTIAL,
    PARALLEL,
    CONDITIONAL,
    CONVERGENT
}

sem ConnectionType = "SEQUENTIAL ('then', 'after'), PARALLEL ('while', 'at same time'), CONDITIONAL ('if', 'otherwise'), CONVERGENT ('either way')";

#===========================================================
#                     CORE OBJECTS
#===========================================================

"""Emotional state detected from user message"""
obj EmotionalState {
    has emotion: Emotion;
    has confidence: float;
    has reasoning: str;
}

sem EmotionalState.confidence = "0.0-1.0";
sem EmotionalState.reasoning = "Brief explanation";

"""Context about what user is referring to"""
obj ConversationContext {
    has intent: ConversationIntent;
    has referring_to_task: str;
    has correction_type: CorrectionType;
    has tasks_to_move: list[str];
}

sem ConversationContext.referring_to_task = "Exact task name from existing_nodes, empty if none";
sem ConversationContext.correction_type = "RENAME (change task name), INSERT_BEFORE/INSERT_AFTER/INSERT_FIRST (add tasks), REORDER (change order), REPLACE (swap), ATTACHMENT_POINT (specify connection), SEQUENCE_ORDER (specify order). Use RENAME as default for simple corrections.";
sem ConversationContext.tasks_to_move = "Existing task names being repositioned";

"""Intent analysis result"""
obj IntentAnalysis {
    has should_create_tasks: bool;
    has context: ConversationContext;
    has confidence: float;
}

sem IntentAnalysis.confidence = "Confidence 0.0-1.0 in intent classification";

"""Extracted task names from user message"""
obj ExtractedTasks {
    has names: list[str];
    has renamed_from: str;
    has renamed_to: str;
}

sem ExtractedTasks.names = "Final task names in CamelCase";
sem ExtractedTasks.renamed_from = "Old task name for rename operations";
sem ExtractedTasks.renamed_to = "New task name for rename operations";

"""Where new tasks should attach in the graph"""
obj AttachmentPointAnalysis {
    has attachment_nodes: list[str];
    has reasoning: str;
}

"""Convergence pattern detection"""
obj ConvergenceIntent {
    has should_converge: bool;
    has source_nodes: list[str];
    has trigger_phrase: str;
}

"""Task relationship with sequencing"""
obj TaskRelationship {
    has connection_type: ConnectionType;
    has from_task: str;
    has to_task: str;
    has edge_label: str;
    has sequence_order: int;
}

sem TaskRelationship.from_task = "Source task name in CamelCase";
sem TaskRelationship.to_task = "Target task name in CamelCase";
sem TaskRelationship.edge_label = "Edge label: 'then', 'if raining', etc.";

"""Thinking insights for transparency"""
obj ThinkingSummary {
    has emotional_insight: str;
    has intent_insight: str;
    has task_insight: str;
    has pattern_insight: str;
}

#===========================================================
#                     CORE FUNCTIONS
#===========================================================

"""Detect user's emotional state"""
def detect_emotional_state(
    user_message: str,
    conversation_history: list[dict[str, str]]
) -> EmotionalState by llm();

sem detect_emotional_state = """
Analyze message for emotional indicators.
Return dominant emotion with confidence score.

Keywords: STRESSED (frustration, overwhelmed), EXCITED (enthusiastic),
INDECISIVE (uncertain, questions), FATIGUED (tired, exhausted), NEUTRAL (normal).
""";

"""Generate conversational response matching emotional state"""
def generate_friendly_response(
    user_message: str,
    emotional_state: EmotionalState,
    action_taken: str,
    task_names: list[str]
) -> str by llm();

sem generate_friendly_response = """
Generate warm response matching emotion tone.
Natural acknowledgment ("Got it!" not "Task added"), 1-3 sentences, contractions, no jargon.
""";

"""Analyze conversation intent and determine user's goal"""
def analyze_conversation_intent(
    user_message: str,
    conversation_history: list[dict[str, str]],
    existing_nodes: list[str],
    last_task: str
) -> IntentAnalysis by llm();

sem analyze_conversation_intent = """
Classify intent from keywords:

COMMIT_ACTION: task mentioned (default) - User wants to ADD new tasks
CORRECT_PREVIOUS: "actually", "before", "first", "instead of", "no wait"
CLARIFY_PREVIOUS: "no I meant", "after X"
ASK_QUESTION: "what should I do", "can you help"
THINK_ALOUD: "maybe", "not sure", "wondering"

IMPORTANT for correction_type field:
- COMMIT_ACTION (adding new tasks): Set correction_type=NONE (default)
- RENAME: Only when user explicitly says "change X to Y", "rename X", or "actually" + similar task name
- INSERT_BEFORE/INSERT_AFTER/INSERT_FIRST: When user says "before/after X" or "first"
- REORDER: When repositioning existing tasks
- ATTACHMENT_POINT: When specifying where new tasks connect
- SEQUENCE_ORDER: When clarifying execution order

Return should_create_tasks=true for all intents except pure uncertainty.
""";

"""Extract task names from user message"""
def extract_raw_task_names(
    user_message: str,
    context: ConversationContext,
    existing_nodes: list[str]
) -> ExtractedTasks by llm();

sem extract_raw_task_names = """
Extract task names, convert to CamelCase.

Rename mode (correction_type=RENAME):
- Set renamed_to, names=[]

Reorder/insert mode (correction_type=REORDER/INSERT_* or tasks_to_move populated):
- Use existing task names without numbers

Normal mode:
- Append numbers for duplicates (TaskName, TaskName2, TaskName3)

Strip conditional prefixes ("if X, I'll Y" → Y).
""";

"""Determine where new tasks attach in the graph"""
def determine_attachment_points(
    user_message: str,
    last_task: str,
    existing_nodes: list[str],
    context: ConversationContext
) -> AttachmentPointAnalysis by llm();

sem determine_attachment_points = """
Find attachment points for new tasks.

User says "after X" → attachment_nodes=[X]
User says "before Y" → attachment_nodes=[predecessor of Y in current graph]
Default → attachment_nodes=[last_task]

If context is a correction/clarification → return empty attachment_nodes.
""";

"""Detect if user intends to converge parallel branches"""
def detect_convergence_intent(
    user_message: str,
    last_task: str,
    current_edges: list[dict[str, str]]
) -> ConvergenceIntent by llm();

sem detect_convergence_intent = """
Detect convergence from message.

EXPLICIT: "either way", "regardless", "in both cases", "afterwards"
IMPLICIT: last_task contains "|" and user adds task without naming source
NO: User names specific task or linear flow

Extract source_nodes by splitting last_task by "|" if convergence detected.
""";

"""Build task relationships from analyzed context"""
def build_task_relationships(
    user_message: str,
    extracted_tasks: ExtractedTasks,
    attachment: AttachmentPointAnalysis,
    convergence: ConvergenceIntent,
    context: ConversationContext,
    current_edges: list[dict[str, str]]
) -> list[TaskRelationship] by llm();

sem build_task_relationships = """
Create task relationships mapping user intent to graph structure.

If needs_graph_rebuild=true: return ALL relationships including existing
If needs_graph_rebuild=false: return only NEW relationships

Map connection types:
- SEQUENTIAL: "then", "after"
- PARALLEL: "while", "at same time"
- CONDITIONAL: "if X", "otherwise"
- CONVERGENT: "either way"

Sequential: chain tasks (A→B→C)
Parallel: branch from same source with type=PARALLEL
Conditional: create conditional branches
Convergent: merge branches with "either way"

Use actual task names from attachment.attachment_nodes and extracted_tasks.names.
""";

"""Generate contextual suggestions for next actions"""
def generate_next_suggestions(
    last_task: str,
    recent_tasks: list[str],
    context: ConversationContext,
    emotional_state: EmotionalState
) -> list[str] by llm();

sem generate_next_suggestions = """
Generate 2 short suggestions (3-5 words) for what user might do next.

Format: "I'll [action]"
Base on typical routine patterns and time of day.
Return as simple list of strings.
""";

"""Generate thinking insights for transparency"""
def generate_thinking_summary(
    user_message: str,
    emotional_state: EmotionalState,
    intent: IntentAnalysis,
    extracted: ExtractedTasks,
    attachment: AttachmentPointAnalysis,
    convergence: ConvergenceIntent
) -> ThinkingSummary by llm();

sem generate_thinking_summary = """
Generate short friendly bullets showing understanding.

emotional_insight: Be empathetic, empty if confidence < 0.7
intent_insight: "You're [correcting/clarifying/asking about] [context]"
task_insight: For duplicates: "This is your [X]th time doing this"
pattern_insight: Parallel → "at same time", Sequential → "one after another"

Keep under 10 words each.
""";

#===========================================================
#                  VALIDATION OBJECTS
#===========================================================

"""Task validation result"""
obj TaskValidationResult {
    has is_valid: bool;
    has reason: str;
    has missing_tasks: list[str];
    has incorrect_task: str;
    has correct_task_name: str;
}

sem TaskValidationResult.is_valid = "TRUE if ALL tasks mentioned were extracted";
sem TaskValidationResult.reason = "Explanation of what's wrong";
sem TaskValidationResult.missing_tasks = "Task names that were missed";
sem TaskValidationResult.incorrect_task = "Existing task with wrong name";
sem TaskValidationResult.correct_task_name = "Correct name for rename";

"""Graph structure validation result"""
obj GraphValidationResult {
    has is_valid: bool;
    has reason: str;
    has expected_structure: str;
}

"""Rename validation result"""
obj RenameValidationResult {
    has is_valid: bool;
    has reason: str;
    has old_task_found: bool;
    has new_task_unique: bool;
    has edges_updated: bool;
}

sem RenameValidationResult.is_valid = "TRUE if rename operation was executed correctly";
sem RenameValidationResult.reason = "Brief explanation of what's wrong";
sem RenameValidationResult.old_task_found = "TRUE if old task existed in before_nodes";
sem RenameValidationResult.new_task_unique = "TRUE if new task doesn't conflict with existing tasks";
sem RenameValidationResult.edges_updated = "TRUE if all edges were correctly updated";

"""Insert validation result"""
obj InsertValidationResult {
    has is_valid: bool;
    has reason: str;
    has insert_position_correct: bool;
    has referring_task_exists: bool;
    has no_orphans: bool;
}

sem InsertValidationResult.is_valid = "TRUE if insert operation positioned tasks correctly";
sem InsertValidationResult.reason = "Brief explanation of what's wrong";
sem InsertValidationResult.insert_position_correct = "TRUE if position matches operation type";
sem InsertValidationResult.referring_task_exists = "TRUE if referring task was found in graph";
sem InsertValidationResult.no_orphans = "TRUE if no disconnected tasks exist";

"""Reorder validation result"""
obj ReorderValidationResult {
    has is_valid: bool;
    has reason: str;
    has tasks_moved_exist: bool;
    has new_order_logical: bool;
    has no_circular_refs: bool;
}

sem ReorderValidationResult.is_valid = "TRUE if reorder operation moved tasks correctly";
sem ReorderValidationResult.reason = "Brief explanation of what's wrong";
sem ReorderValidationResult.tasks_moved_exist = "TRUE if all tasks to move were found in graph";
sem ReorderValidationResult.new_order_logical = "TRUE if new order matches user intent";
sem ReorderValidationResult.no_circular_refs = "TRUE if no circular references detected";

"""Edge label validation result"""
obj EdgeLabelValidationResult {
    has is_valid: bool;
    has reason: str;
    has missing_labels: list[str];
    has incorrect_labels: list[str];
}

sem EdgeLabelValidationResult.is_valid = "TRUE if edge labels match user's intent";
sem EdgeLabelValidationResult.reason = "Brief explanation of what's wrong";
sem EdgeLabelValidationResult.missing_labels = "Descriptions for missing labels";
sem EdgeLabelValidationResult.incorrect_labels = "Descriptions for incorrect labels";

"""Validate task extraction"""
def validate_task_extraction(
    user_message: str,
    extracted_tasks: list[str],
    existing_nodes: list[str]
) -> TaskValidationResult by llm();

sem validate_task_extraction = """
Validate if extracted tasks capture ALL actions mentioned.

Check for:
- Conditionals: "if X, then Y; otherwise Z" → BOTH tasks needed
- Multiple activities: "do X and then Y" → BOTH tasks needed
- Parallel: "while X, also Y" → BOTH tasks needed
- Rename: extracted similar to existing with better name → signal rename

If rename needed: is_valid=false, incorrect_task=existing name, correct_task_name=better name.
""";

"""Validate graph structure"""
def validate_graph_structure(
    user_message: str,
    graph_nodes: list[str],
    graph_edges: list[dict[str, str]]
) -> GraphValidationResult by llm();

sem validate_graph_structure = """
Validate if graph structure correctly represents user intent for new tasks.

graph_nodes: ONLY newly added tasks
graph_edges: ONLY edges involving new tasks (as "to")

Check for proper conditional, sequential, parallel, and convergence structures.
""";

"""Validate rename operation"""
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
""";

"""Validate insert operation"""
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
""";

"""Validate reorder operation"""
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
""";

"""Validate edge labels"""
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
2. Missing "if X" or "otherwise" labels
3. Parallel tasks missing "while" label
""";

#===========================================================
#                  ANALYTICS FUNCTIONS
#===========================================================

"""Personalized insight"""
obj PersonalizedInsight {
    has title: str;
    has description: str;
    has category: str;
    has actionable: bool;
}

"""Generate personalized insights"""
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
Generate 3-4 insights based on actual data.

Categories: productivity, consistency, behavioral, recommendations
Base insights on numeric data (mention specific numbers)
New users (<5 tasks): focus on getting started
Active users (>=5 tasks): focus on optimization
""";

"""Routine pattern discovery"""
obj RoutinePattern {
    has pattern_name: str;
    has task_sequence: list[str];
    has frequency: int;
    has confidence: float;
    has time_context: str;
    has description: str;
}

"""Discover repeated task sequences"""
def discover_routine_patterns(
    activity_events: list[dict],
    task_graph_nodes: list[str],
    task_graph_edges: list[dict],
    time_window_days: int = 30
) -> list[RoutinePattern] by llm();

sem discover_routine_patterns = """
Analyze events to find repeated task sequences forming routines.

Look for patterns: morning routines, work workflows, evening wind-downs
Consider time context: morning/afternoon/evening/night/weekend
Only return patterns with frequency >= 2 and confidence >= 0.5.
""";

"""Temporal insight"""
obj TemporalInsight {
    has insight_type: str;
    has description: str;
    has peak_hours: list[int];
    has peak_days: list[str];
    has confidence: float;
    has recommendation: str;
}

"""Analyze temporal patterns"""
def analyze_temporal_patterns(
    activity_events: list[dict],
    lookback_days: int = 30
) -> list[TemporalInsight] by llm();

sem analyze_temporal_patterns = """
Analyze timestamps to discover when user is most active.

Extract hour (0-23) and day of week
Identify peak hours and peak days
Look for patterns: "weekend warrior", "morning person", "night owl"

Be specific: "9-11 AM" not "morning".
""";

"""Comparison insight between time periods"""
obj ComparisonInsight {
    has comparison_type: str;
    has current_period: dict;
    has previous_period: dict;
    has change_percentage: float;
    has trend: str;
    has narrative: str;
}

"""Generate comparative insights"""
def generate_comparative_insights(
    current_events: list[dict],
    previous_events: list[dict],
    period_type: str = "week"
) -> list[ComparisonInsight] by llm();

sem generate_comparative_insights = """
Compare activity between time periods to identify trends.

Count events, calculate percentage change, determine trend (improving/declining/stable)
Small fluctuations (<10%) = stable.
""";

"""Check if proactive insight should trigger"""
def should_trigger_proactive_insight(
    recent_events: list[dict],
    user_goals: list[dict],
    current_streak: int,
    last_insight_time: str,
    user_context: dict
) -> dict by llm();

sem should_trigger_proactive_insight = """
Determine if proactive insight should trigger.

Triggers: STREAK_AT_RISK, ACHIEVEMENT_UNLOCKED, GOAL_MILESTONE,
PATTERN_DETECTED, ENCOURAGEMENT_NEEDED, RETURNING_USER

Return dict with should_trigger, insight_type, urgency (low/medium/high), message.
Only trigger if valuable. Avoid spam.
""";
