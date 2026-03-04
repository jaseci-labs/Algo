# Conversation Intent Classification Rules

## Intent Types

COMMIT_ACTION: task mentioned (default) - User wants to ADD new tasks
CORRECT_PREVIOUS: "actually", "instead of", "no wait"
CLARIFY_PREVIOUS: "no I meant", "after X"
ASK_QUESTION: "what should I do", "can you help"
THINK_ALOUD: "maybe", "not sure", "wondering"

## Real-World Examples

### Example 1: "before X" Pattern (Insertion)
User says: "before i make coffee, i need to buy coffee beans"
- Existing graph has: Start -> MakeCoffee
- Intent: COMMIT_ACTION (user is adding a task)
- correction_type: INSERT_BEFORE
- referring_to_task: "MakeCoffee" (the task referenced in "before X")
- needs_graph_rebuild: True (insertion requires full rebuild)
- is_insertion: True
- Expected result: Start -> BuyCoffeeBeans -> MakeCoffee

### Example 2: Normal Task Addition
User says: "I'll make some coffee"
- Existing graph: Start
- Intent: COMMIT_ACTION
- correction_type: NONE
- referring_to_task: "" (empty)
- needs_graph_rebuild: False (simple addition)
- is_insertion: False
- Expected result: Start -> MakeCoffee

### Example 3: Conditional Tasks
User says: "if im in the mood, i will wash my dog, otherwise i will wash my car"
- Intent: COMMIT_ACTION
- correction_type: NONE (conditional branching, not insertion)
- Expected result: Two branches from attachment point with CONDITIONAL connection type

## Insertion Pattern Rules

**CRITICAL: Insertion Patterns ("before X", "after X", "first")**
- These are COMMIT_ACTION (user is adding tasks) but with special positioning
- User says "before X, i will Y" → Set intent=COMMIT_ACTION, correction_type=INSERT_BEFORE, needs_graph_rebuild=True, is_insertion=True
- User says "after X, i will Y" → Set intent=COMMIT_ACTION, correction_type=INSERT_AFTER, needs_graph_rebuild=True, is_insertion=True
- User says "first, i will Y" → Set intent=COMMIT_ACTION, correction_type=INSERT_FIRST, needs_graph_rebuild=True, is_insertion=True

## Correction Type Mappings

IMPORTANT for correction_type field:

**INSERTION PATTERNS** (trigger rebuild mode):
- "before X, i will Y" → INSERT_BEFORE, needs_graph_rebuild=True, is_insertion=True
- "after X, i will Y" → INSERT_AFTER, needs_graph_rebuild=True, is_insertion=True
- "first, i will Y" → INSERT_FIRST, needs_graph_rebuild=True, is_insertion=True

- COMMIT_ACTION (adding new tasks normally): Set correction_type=NONE, needs_graph_rebuild=False
- RENAME: Only when user explicitly says "change X to Y", "rename X", or "actually" + similar task name
- REORDER: When repositioning existing tasks → needs_graph_rebuild=True
- ATTACHMENT_POINT: When specifying where new tasks connect → needs_graph_rebuild=True
- SEQUENCE_ORDER: When clarifying execution order → needs_graph_rebuild=True

## Graph Rebuild Rules

CRITICAL: needs_graph_rebuild should be TRUE for:
- INSERT_BEFORE, INSERT_AFTER, INSERT_FIRST operations (triggered by "before X", "after X", "first" patterns)
- REORDER, REPLACE operations
- Any CORRECT_PREVIOUS intent with existing tasks
- Any CLARIFY_PREVIOUS intent
