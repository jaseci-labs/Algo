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
sem TaskRelationship.from_task = "Exact task name from existing_nodes OR new task name in CamelCase";
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

"""Extract complete task sequence from user message with correct ordering"""
def extract_task_sequence(
    user_message: str,
    conversation_context: ConversationContext,
    existing_nodes: list[str],
    last_task: str,
    current_edges: list[dict]
) -> list[TaskRelationship] by llm();

sem extract_task_sequence = """
Extract ALL task relationships with CORRECT sequencing and attachment points:

1. IDENTIFY ALL TASKS mentioned (new and existing)
   - Check if task name exists in existing_nodes list
   - Match existing names EXACTLY (case-sensitive)

2. DETERMINE SEQUENCING from keywords:
   - "X then Y": X→Y (sequence_order: 1,2)
   - "X before Y": Create X→Y (Y might exist)
   - "after X do Y": X→Y  
   - "X and Y": Parallel from same point
   - "if C, X otherwise Y": Conditional branches

3. ANALYZE GRAPH STRUCTURE (use current_edges):
   - Identify recent conditional branches (edges with "if", "otherwise" labels)
   - Find sibling branches (multiple nodes with edges from same parent)
   - Detect convergence opportunities

4. CONNECTION TYPES:
   - SEQUENTIAL: Linear chain with "then"/"after"
   - PARALLEL: Same source, different branches (and/also)
   - CONDITIONAL: Branches with if/otherwise labels
   - CONVERGENT: Multiple sources→one target
     * AUTOMATIC DETECTION: When message says "afterwards", "then", or adds task after last_task:
       1. Check if last_task has siblings (other nodes from same parent in current_edges)
       2. If siblings exist with conditional labels ("if", "otherwise"), assume convergence
       3. Create edges from ALL sibling branches to new task
     * EXPLICIT: "either way", "regardless", "in both cases"
     * Example: last_task=GoToOffice, sibling=WorkFromHome (both from Breakfast)
     * Message: "then have lunch" → WorkFromHome→HaveLunch AND GoToOffice→HaveLunch

4. CRITICAL ATTACHMENT RULES:
   
   A. For FIRST MESSAGE (existing_nodes only has "Start"):
      - First task connects from "Start"
      - All other tasks chain sequentially
   
   B. For NORMAL ADDITIONS (conversation_context.needs_graph_rebuild = False):
      - Use last_task as attachment point
      - Example: last_task="BrushTeeth", message="then shower"
      - Result: [BrushTeeth→Shower]
   
   C. For CORRECTIONS/CLARIFICATIONS (conversation_context.needs_graph_rebuild = True):
      ⚠️ CRITICAL: Return COMPLETE graph structure with ALL tasks!
      - Analyze the correction and reconstruct the FULL intended graph
      - Include ALL existing nodes and their correct relationships
      - Example: existing=[Start,Coffee,Breakfast], message="actually brush teeth before coffee"
      - Result: [Start→BrushTeeth, BrushTeeth→Coffee, Coffee→Breakfast]
      - NOT just: [Start→BrushTeeth, BrushTeeth→Coffee] ❌

5. EXAMPLES:
   
   Example 1 - Normal addition:
   - existing_nodes: ["Start", "Coffee", "Breakfast"]
   - last_task: "Breakfast"
   - message: "then clean dishes"
   - needs_graph_rebuild: False
   - Result: [Breakfast→CleanDishes]
   
   Example 2 - Correction (FULL GRAPH):
   - existing_nodes: ["Start", "Coffee", "Breakfast", "Shower"]
   - last_task: "Shower"
   - message: "actually brush teeth before coffee"
   - needs_graph_rebuild: True
   - Result: [Start→BrushTeeth (1), BrushTeeth→Coffee (2), Coffee→Breakfast (3), Breakfast→Shower (4)]
   - ⚠️ Must include ALL tasks in correct order!
   
   Example 3 - Clarification (FULL GRAPH):
   - existing_nodes: ["Start", "Coffee", "Breakfast", "Shower"]
   - message: "no i meant shower after coffee"
   - needs_graph_rebuild: True
   - Result: [Start→Coffee (1), Coffee→Shower (2), Shower→Breakfast (3)]
   
   Example 4 - Convergent (MULTIPLE SOURCES):
   - existing_nodes: ["Start", "Breakfast", "WorkFromHome", "GoToOffice"]
   - last_task: "GoToOffice"
   - message: "either way i need to have lunch afterwards"
   - needs_graph_rebuild: False
   - Analysis: "either way" refers to BOTH branches (WorkFromHome and GoToOffice)
   - Result: [WorkFromHome→HaveLunch (1), GoToOffice→HaveLunch (2)]
   - ⚠️ Both branches converge to the same target!

CRITICAL: 
- When needs_graph_rebuild=True: Return COMPLETE graph with ALL existing nodes
- Use existing_nodes names EXACTLY as provided
- Return relationships in sequence_order
- NEVER create edges from "Start" unless it's truly the first task
- "either way"/"regardless"/"in both cases" → convergent edges from ALL recent branches
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
