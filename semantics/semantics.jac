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
}

sem ConversationContext.intent = "COMMIT_ACTION: new task commitment | CORRECT_PREVIOUS: 'actually', 'before', 'first' corrections | CLARIFY_PREVIOUS: 'no i meant', 'after X' clarifications | ASK_QUESTION: questions | THINK_ALOUD: wondering/maybe";
sem ConversationContext.referring_to_task = "Which existing task is user referring to? Empty if none, or task name from existing_nodes";
sem ConversationContext.correction_type = "For CORRECT_PREVIOUS: 'insert_before', 'reorder', 'replace' | For CLARIFY_PREVIOUS: 'attachment_point', 'sequence_order' | Empty otherwise";
sem ConversationContext.needs_graph_rebuild = "TRUE for CORRECT_PREVIOUS or CLARIFY_PREVIOUS with existing tasks, FALSE for COMMIT_ACTION on empty/simple graphs";

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

sem TaskRelationship.connection_type = "SEQUENTIAL: then/after | PARALLEL: and/also | CONDITIONAL: if/otherwise | CONVERGENT: merge point";
sem TaskRelationship.from_task = "Task name in CamelCase (previous task in sequence)";
sem TaskRelationship.to_task = "Next task name in CamelCase (e.g., MakeCoffee, BrushTeeth)";
sem TaskRelationship.edge_label = "Edge label: 'then', 'if raining', 'otherwise', etc.";
sem TaskRelationship.sequence_order = "Sequence number (1, 2, 3...) to preserve order when multiple relationships";

"""Intent and commitment analysis result"""
obj IntentAnalysis {
    has should_create_tasks: bool;
    has conversation_context: ConversationContext;
    has confidence: float;
}

sem IntentAnalysis.should_create_tasks = "TRUE only if user committed to action, FALSE for questions/thinking/uncertain";
sem IntentAnalysis.conversation_context = "Context about what user is doing: correcting, clarifying, committing new";
sem IntentAnalysis.confidence = "Confidence 0.0-1.0 in the intent classification";

"""Strategy for generating unique task names"""
obj TaskNamingStrategy {
    has base_name: str;
    has unique_name: str;
    has counter: int;
    has already_exists: bool;
}

sem TaskNamingStrategy.base_name = "Original task name extracted from user message";
sem TaskNamingStrategy.unique_name = "Final unique name with number suffix if needed";
sem TaskNamingStrategy.counter = "Number suffix used (0 if no suffix needed)";
sem TaskNamingStrategy.already_exists = "Whether base_name already existed in graph";

"""Analysis of where new tasks should attach in the graph"""
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

"""Detection of convergence patterns in user intent"""
obj ConvergenceIntent {
    has should_converge: bool;
    has source_nodes: list[str];
    has convergence_type: str;
    has trigger_phrase: str;
}

sem ConvergenceIntent.should_converge = "TRUE if user intends parallel branches to merge";
sem ConvergenceIntent.source_nodes = "List of nodes to converge from (leaf nodes)";
sem ConvergenceIntent.convergence_type = "explicit (keywords like 'either way') | implicit (last_task has '|' and no specific task named) | none";
sem ConvergenceIntent.trigger_phrase = "The phrase that triggered convergence detection";

"""Extracted task names from user message"""
obj ExtractedTasks {
    has raw_names: list[str];
    has unique_names: list[str];
    has name_mappings: list[dict];
}

sem ExtractedTasks.raw_names = "Task names extracted from user message in CamelCase";
sem ExtractedTasks.unique_names = "Unique task names with number suffixes if duplicates exist";
sem ExtractedTasks.name_mappings = "List of {raw: str, unique: str} mappings";

"""Detect the user's emotional state from their message and conversation context"""
def detect_emotional_state(
    user_message: str,
    conversation_history: list[dict]
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

"""Analyze conversation intent and determine if user is committing, correcting, or clarifying"""
def analyze_conversation_intent(
    user_message: str,
    conversation_history: list[dict],
    existing_nodes: list[str],
    last_task: str
) -> IntentAnalysis by llm();

sem analyze_conversation_intent = """
Classify user's intent by analyzing RECENT conversation context:

COMMIT_ACTION: Definite statements about tasks/actions
- Patterns: "I'll X", "I'm going to X", "I need to X", "then X", "X afterwards"
- Conditionals: "if X then Y", "either way Z"
- Simple statements: "make coffee", "brush teeth", "have lunch"
- should_create_tasks: TRUE ✓
- needs_graph_rebuild: FALSE (unless correcting)

CORRECT_PREVIOUS: Corrections/reorganizations
- Keywords: "actually", "before", "first", "instead", "wait"
- Patterns: "I need to X before Y" when Y exists
- should_create_tasks: TRUE ✓
- needs_graph_rebuild: TRUE ✓
- referring_to_task: what they're correcting
- correction_type: "insert_before" | "reorder" | "replace"

CLARIFY_PREVIOUS: Clarifications after assistant response
- Keywords: "no i meant", "I meant Y not Z"
- Patterns: "after X" (when clarifying attachment)
- should_create_tasks: TRUE ✓ (if adding tasks)
- needs_graph_rebuild: TRUE ✓ (if existing tasks involved)
- referring_to_task: what they're clarifying about
- correction_type: "attachment_point" | "sequence_order"

ASK_QUESTION: Questions about what to do
- Patterns: "Should I?", "Is it better?", "Would you?", "What do you think?"
- Seeking advice, not committing to action
- should_create_tasks: FALSE ✗

THINK_ALOUD: Thinking/uncertain/considering options
- Keywords: "maybe", "I might", "wondering if", "possibly"
- Uncertain, not committing
- should_create_tasks: FALSE ✗

CRITICAL RULES:
1. DEFAULT to COMMIT_ACTION if message mentions any task/action
2. Only use ASK_QUESTION if it's clearly a question (ends with ?)
3. Only use THINK_ALOUD if there's clear uncertainty ("maybe", "might")
4. When in doubt between COMMIT and others → choose COMMIT
5. Check last 2-3 conversation turns for context
""";

"""Extract raw task names from user message in CamelCase format"""
def extract_raw_task_names(
    user_message: str,
    conversation_context: ConversationContext
) -> ExtractedTasks by llm();

sem extract_raw_task_names = """
Extract all task mentions from user message and convert to CamelCase.
- "make coffee" → "MakeCoffee"
- "check emails" → "CheckEmails"
- "have breakfast then brush teeth" → ["HaveBreakfast", "BrushTeeth"]

Return ExtractedTasks with:
- raw_names: list of CamelCase names
- unique_names: empty (will be filled by generate_unique_task_name)
- name_mappings: empty (will be filled by generate_unique_task_name)
""";

"""Generate unique task name by checking existing nodes and appending number suffix"""
def generate_unique_task_name(
    desired_name: str,
    existing_nodes: list[str]
) -> TaskNamingStrategy by llm();

sem generate_unique_task_name = """
Given a desired task name and existing nodes, generate a unique name.

Rules:
- Count occurrences of desired_name in existing_nodes
- If name doesn't exist: return as-is (counter=0)
- If exists once: append "2" (counter=2)
- If "Name2" exists: append "3" (counter=3), etc.

Examples:
- desired="Coffee", existing=["Start","Lunch"] → unique="Coffee", counter=0
- desired="Coffee", existing=["Coffee","Lunch"] → unique="Coffee2", counter=2
- desired="Coffee", existing=["Coffee","Coffee2"] → unique="Coffee3", counter=3

Return TaskNamingStrategy with all fields populated.
""";

"""Determine where new tasks should attach in the graph"""
def determine_attachment_points(
    user_message: str,
    last_task: str,
    existing_nodes: list[str],
    conversation_context: ConversationContext
) -> AttachmentPointAnalysis by llm();

sem determine_attachment_points = """
Analyze where new tasks should connect in the graph.

DEFAULT RULE: Use last_task as attachment point (this is 99% of cases)

Special cases:
1. last_task contains "|" (e.g., "GoToGym|GoForRun"):
   - Split by "|" to get multiple attachment nodes
   - Set is_convergent=True
   - attachment_nodes = ["GoToGym", "GoForRun"]

2. User explicitly names a task (e.g., "after GoToGym, do X"):
   - attachment_nodes = ["GoToGym"]
   - user_specified = True
   - is_convergent = False

3. Normal case (user says "then X", "check emails"):
   - attachment_nodes = [last_task]
   - user_specified = False
   - is_convergent = False (unless last_task has "|")

4. needs_graph_rebuild = True:
   - Return empty attachment_nodes (will rebuild full graph)
   - reasoning explains the correction/clarification

Always provide clear reasoning for transparency.
""";

"""Detect if user intends to converge parallel branches"""
def detect_convergence_intent(
    user_message: str,
    last_task: str,
    current_edges: list[dict]
) -> ConvergenceIntent by llm();

sem detect_convergence_intent = """
Detect convergence patterns from user message.

Types:
1. EXPLICIT convergence (should_converge=True):
   - Keywords: "either way", "regardless", "in both cases", "afterwards" (after branches)
   - trigger_phrase: the exact phrase used
   - convergence_type: "explicit"

2. IMPLICIT convergence (should_converge=True):
   - last_task contains "|" (e.g., "GoToGym|GoForRun")
   - User adds task WITHOUT naming specific source
   - Message: "then shower", "have lunch"
   - convergence_type: "implicit"

3. NO convergence (should_converge=False):
   - User names specific task: "after GoToGym"
   - Linear flow: normal "then X" when last_task is single
   - convergence_type: "none"

Extract source_nodes by splitting last_task by "|" if convergence detected.
""";

"""Build task relationships using pre-analyzed context"""
def build_task_relationships(
    user_message: str,
    unique_task_names: list[str],
    attachment_analysis: AttachmentPointAnalysis,
    convergence_intent: ConvergenceIntent,
    conversation_context: ConversationContext
) -> list[TaskRelationship] by llm();

sem build_task_relationships = """
Build TaskRelationship list using pre-analyzed data.

Inputs are already processed:
- unique_task_names: guaranteed unique, no duplicates
- attachment_analysis: knows where to attach
- convergence_intent: knows if converging
- conversation_context: knows if rebuild needed

Your job: Determine connection_type, edge_label, and sequence_order

1. CONNECTION TYPES:
   - SEQUENTIAL: "then", "after" → linear chain
   - PARALLEL: "and", "also" → multiple edges from same source
   - CONDITIONAL: "if", "otherwise" → branches with conditions
   - CONVERGENT: convergence_intent.should_converge=True → multiple sources, one target

2. EDGE LABELS:
   - Sequential: "then", "after that"
   - Conditional: "if raining", "otherwise"
   - Parallel: "and", "also"
   - Convergent: "then", "afterwards"

3. SEQUENCING:
   - If conversation_context.needs_graph_rebuild=True:
     * Reconstruct FULL graph structure
     * Include ALL existing nodes with correct relationships
     * Return complete ordered sequence
   
   - If normal addition (needs_graph_rebuild=False):
     * Use attachment_analysis.attachment_nodes as from_task(s)
     * Create edges to unique_task_names
     * If convergence_intent.should_converge:
       * Create edges from ALL source_nodes to first new task
       * Chain remaining tasks sequentially

4. SEQUENCE ORDER:
   - Number relationships 1, 2, 3, ... in execution order
   - For convergent edges, all edges to same target get sequential numbers

Example 1 - Simple sequential:
- attachment_analysis.attachment_nodes = ["Breakfast"]
- unique_task_names = ["CleanDishes"]
- Result: [Breakfast→CleanDishes, connection_type=SEQUENTIAL, sequence_order=1]

Example 2 - Convergent:
- convergence_intent.should_converge = True
- convergence_intent.source_nodes = ["GoToGym", "GoForRun"]
- unique_task_names = ["Shower"]
- Result: [
    GoToGym→Shower (CONVERGENT, sequence_order=1),
    GoForRun→Shower (CONVERGENT, sequence_order=2)
  ]

SIMPLIFIED: No name generation, no attachment logic - just focus on relationships!
""";

"""REFACTORED: Extract complete task sequence using decomposed semantic functions"""
def extract_task_sequence(
    user_message: str,
    conversation_context: ConversationContext,
    existing_nodes: list[str],
    last_task: str,
    current_edges: list[dict]
) -> list[TaskRelationship] by llm();

sem extract_task_sequence = """
Orchestrate task extraction by calling specialized sub-functions in sequence:

1. extract_raw_task_names() - Get task names from message
2. generate_unique_task_name() - Ensure no duplicates (for each task)
3. determine_attachment_points() - Find where to connect
4. detect_convergence_intent() - Check for parallel branch merging
5. build_task_relationships() - Create final relationships

Pass results from each step to the next. All complexity is handled by sub-functions.
Return the TaskRelationship list from step 5.
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

"""Generate structured reasoning explanation for complex decisions"""
def generate_decision_reasoning(
    user_message: str,
    context_considered: list[str],
    options: list[str],
    recommendation: str,
    tradeoffs: list[str]
) -> str by llm();

sem generate_decision_reasoning = """
Structured reasoning with emoji markers:
🤔 Context → 💡 Options → ⚖️ Tradeoffs → ✅ Recommendation

Use for advice/complex decisions, not simple tracking.
""";

"""Generate 2 contextual suggestions for what the user might do next"""
def generate_next_suggestions(
    last_task: str,
    recent_tasks: list[str],
    conversation_context: str,
    emotional_state: str
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
