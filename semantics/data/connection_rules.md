# Task Connection Rules

## Attachment Point Decision Rules

**OUTPUT FIELDS for AttachmentPointAnalysis:**
- `attachment_nodes`: List of node names to attach FROM
- `is_convergent`: TRUE if multiple attachment nodes (convergence point)
- `reasoning`: Brief explanation of attachment choice
- `user_specified`: TRUE if user named specific task like "after X"

**DECISION RULES (in order of priority):**

1. **INSERTION MODE** (context.correction_type in [INSERT_BEFORE, INSERT_AFTER, INSERT_FIRST]):
   - The service layer has ALREADY set last_task to the correct insertion point
   - INSERT_BEFORE: last_task was set to the node BEFORE the referenced task
   - INSERT_AFTER: last_task was set to the referenced task itself
   - INSERT_FIRST: last_task was set to "Start"
   - RETURN: attachment_nodes = [last_task] (use the pre-computed insertion point)

2. **OTHER REBUILD MODE** (context.needs_graph_rebuild=True but NOT insertion):
   - RETURN: attachment_nodes = [] (full rebuild, attachment not needed)

3. **DEFAULT MODE** (normal task addition):
   - RETURN: attachment_nodes = [last_task] (attach from last task)
   - If last_task contains "|", split it: "CheckMessages|HaveCoffee" → ["CheckMessages", "HaveCoffee"]

4. **USER-SPECIFIED OVERRIDE**:
   - User says "after X" → attach from X
   - User says "from Z" → attach from Z

**CRITICAL: NEVER default to ["Start"] unless the graph is empty**

## TaskRelationship Field Meanings

**OUTPUT FIELDS for TaskRelationship:**
- `from_task`: MUST be attachment.attachment_nodes[0] (NEVER use extracted task name unless it exists in existing_nodes)
- `to_task`: The task from extracted_tasks.names
- `connection_type`: "SEQUENTIAL" | "PARALLEL" | "CONDITIONAL" | "CONVERGENT"
- `edge_label`: "then" | "while" | "if X" | "otherwise" | "either way"
- `sequence_order`: 1, 2, 3... for ordering relationships

**MODE SWITCH:**
- If context.needs_graph_rebuild=False: Return ONLY new relationships (incremental)
- If context.needs_graph_rebuild=True: Return ALL relationships including existing_edges (full rebuild)

## Connection Types

- SEQUENTIAL: "then", "after", "afterwards" - A must complete before B
- PARALLEL: "while", "as", "during", "at the same time", "simultaneously", "and" - Tasks happen together
- CONDITIONAL: "if X", "otherwise" - Conditional branches
- CONVERGENT: "either way", "regardless", "in both cases" - Merging parallel/conditional branches

## Edge Label Rules

CRITICAL EDGE LABEL RULES:
- "then" or "afterwards": Default for sequential tasks (A happens, then B happens)
- "while" or "at same time": For PARALLEL tasks (A and B happen simultaneously)
- "if X" or "otherwise": For CONDITIONAL branches (if X happens do A, otherwise do B)
- "either way": ONLY for CONDITIONAL convergence where if/otherwise branches merge (NOT for parallel tasks)
- After PARALLEL tasks converge, use "then" or "afterwards" for the next sequential task

Examples:
Sequential: "have drink then head home then call a cab"
  → HaveDrink->HeadHome[label="then"], HeadHome->CallACab[label="then"]

Parallel: "have drink while chatting with buddies, then head home"
  → HaveDrink[label="while"], ChatWithBuddies[label="while"] from HeadToThePub
  → HaveDrink->HeadHome[label="then"], ChatWithBuddies->HeadHome[label="then"]

Conditional: "if raining, read book; otherwise, walk; either way go home"
  → IfRaining->ReadBook[label="if raining"], Otherwise->Walk[label="otherwise"]
  → ReadBook->GoHome[label="either way"], Walk->GoHome[label="either way"]

## JSON Structure Requirements

Each TaskRelationship object MUST have separate fields:
{
  "connection_type": "SEQUENTIAL",
  "from_task": "CheckMessages",
  "to_task": "WashFace",
  "edge_label": "then",
  "sequence_order": 1
}

NEVER concatenate fields like: from_task='WashFace to_task=HeadToGym label=then'

## Incremental vs Full Rebuild Modes

**DEFAULT BEHAVIOR - INCREMENTAL ADDITION:**
For normal COMMIT_ACTION with context.needs_graph_rebuild=False:
- Return ONLY the NEW relationships being added
- Do NOT include existing relationships from current_edges

**FULL REBUILD MODE (context.needs_graph_rebuild=True):**
When user is correcting/reordering existing tasks:
- Return ALL relationships to reconstruct the complete graph INCLUDING ALL EXISTING EDGES
- Start by INCLUDING all relationships from current_edges, then modify only the affected area

**NOTE FOR INSERTION MODE:**
When context.correction_type is INSERT_BEFORE/INSERT_AFTER/INSERT_FIRST:
- Service layer uses INCREMENTAL mode (intent is COMMIT_ACTION)
- Return ONLY the new relationships (attachment -> new_task, new_task -> referenced_task)
- The service layer handles edge removal via edge_to_split

## Insertion Mode (INSERT_BEFORE/INSERT_AFTER) Rules

For insertion mode (context.correction_type in [INSERT_BEFORE, INSERT_AFTER, INSERT_FIRST]):
- The service layer has already set up the insertion point
- attachment.attachment_nodes[0] contains the correct source node
- Return ONLY the new relationships (service layer uses incremental mode)
- Create sequential chain from attachment through all extracted tasks

### Real-World "before X" Example (INCREMENTAL MODE):
User says: "before i make coffee, i need to buy coffee beans"
- Context: Existing graph has Start -> BrewFreshCoffee
- context.correction_type: INSERT_BEFORE
- context.referring_to_task: "BrewFreshCoffee"
- context.needs_graph_rebuild: True (signals insertion behavior)
- extracted_tasks.names: ["BuyCoffeeBeans"]
- attachment.attachment_nodes: ["Start"] (service layer found this by tracing back from "BrewFreshCoffee")
- Returned relationships (INCREMENTAL MODE - only new edges):
  1. Start->BuyCoffeeBeans[connection_type=SEQUENTIAL, edge_label="then", sequence_order=1]
  2. BuyCoffeeBeans->BrewFreshCoffee[connection_type=SEQUENTIAL, edge_label="then", sequence_order=2]

The service layer will:
1. Remove the old edge Start->BrewFreshCoffee (via edge_to_split)
2. Add the two new relationships above

**WRONG** (creates self-loop and circular edge):
- BuyCoffeeBeans->BuyCoffeeBeans (self-loop) ❌
- BrewFreshCoffee->BuyCoffeeBeans (wrong direction) ❌
- Using extracted task as from_task for first relationship ❌

**WRONG** (missing connection to original task):
- Start->BuyCoffeeBeans only (doesn't connect to BrewFreshCoffee) ❌

## Critical: from_task Source Rule (Fixes Self-Loop Bug)

**CRITICAL: When adding NEW tasks to existing graph, from_task MUST be attachment.attachment_nodes[0]**

The `from_task` is ALWAYS the attachment point from the existing graph.
NEVER use an extracted task name as `from_task` unless that task already exists in `existing_nodes`.

### WRONG (creates self-loop bug):
```
extracted_tasks.names = ["WashDog", "WashCar"]
LLM incorrectly uses: from_task = "WashDog" (first extracted task)
Result: WashDog->WashDog (self-loop!), WashDog->WashCar ❌
```

### CORRECT:
```
attachment.attachment_nodes = ["GrabCoffee"]
extracted_tasks.names = ["WashDog", "WashCar"]
LLM correctly uses: from_task = "GrabCoffee" (attachment point)
Result: GrabCoffee->WashDog, GrabCoffee->WashCar ✅
```

### More Examples:
- attachment = ["Start"], tasks = ["MakeCoffee"]
  → Start->MakeCoffee (NOT MakeCoffee->anything)
- attachment = ["CheckMessages"], tasks = ["Reply", "Archive"]
  → CheckMessages->Reply, CheckMessages->Archive (NOT Reply->Reply or Reply->Archive)

## Parallel Task Detection

Analyze user_message for parallel keywords:
- PARALLEL: "while", "as", "during", "at the same time", "simultaneously", "and" (when tasks happen together)
- Create N relationships, ALL with SAME from_task (attachment.attachment_nodes[0])
- ALL relationships use connection_type = PARALLEL
- Each relationship goes to a different unique task
- sequence_order: 1, 2, 3... for each parallel branch

## Conditional Task Handling

CONDITIONAL branches ("if X", "otherwise"):
- Create N relationships (one per branch), ALL with SAME from_task (attachment.attachment_nodes[0])
- The `from_task` is NEVER the first extracted task - it's always the attachment point
- Use "if X" label for first branch (include full condition text), "otherwise" label for second branch
- All relationships use connection_type = CONDITIONAL

### Real-World Examples:

**Example 1**: User says "if im in the mood, i will wash my dog, otherwise i will wash my car"
- attachment.attachment_nodes = ["CheckMessages"]
- extracted_tasks.names = ["WashMyDog", "WashMyCar"]
- Result:
  - CheckMessages->WashMyDog[connection_type=CONDITIONAL, edge_label="if im in the mood"]
  - CheckMessages->WashMyCar[connection_type=CONDITIONAL, edge_label="otherwise"]

**Example 2**: User says "if raining, read book, otherwise, walk"
- attachment.attachment_nodes = ["HaveCoffee"]
- extracted_tasks.names = ["ReadBook", "Walk"]
- Result:
  - HaveCoffee->ReadBook[connection_type=CONDITIONAL, edge_label="if raining"]
  - HaveCoffee->Walk[connection_type=CONDITIONAL, edge_label="otherwise"]

**WRONG** (creates sequential):
- WashMyDog->WashMyCar or using connection_type=SEQUENTIAL ❌
- Using extracted task as from_task ❌

## Convergence Handling

PARALLEL CONVERGENCE (multiple nodes converging after simultaneous activities):
- attachment.attachment_nodes contains multiple nodes from parallel activities
- Create edges from EACH attachment node to the FIRST extracted task
- Use "then" or "afterwards" for these converging edges

CONDITIONAL CONVERGENCE (if/otherwise branches merging):
- Only use "either way" label when converging CONDITIONAL branches (if X / otherwise)
- User must say "either way", "both paths", "regardless", or similar

## Forbidden Operations

- NEVER create circular dependencies
- NEVER link a task to itself
- NEVER create orphaned tasks (no incoming edges except Start node)
