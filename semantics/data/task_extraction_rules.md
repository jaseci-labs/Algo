# Task Extraction Rules

## ExtractedTasks Output Fields

- `names`: Final task names in CamelCase (with suffixes for duplicates: TaskName, TaskName2, TaskName3)
- `renamed_from`: Old task name being renamed
- `renamed_to`: NEW task name for rename operations only

## Mode-Specific Behavior

**Rename mode** (correction_type=RENAME):
- Populate renamed_to only, leave names empty
- DO NOT populate names with the old task name

**Reordering mode** (correction_type=REORDER):
- Use EXISTING names without numbers
- Extract task names being reordered from user_message

**Insertion mode** (context.is_insertion=True):
- If task exists in existing_nodes: use EXACT existing name (no numbers)
- If task is NEW: strip pronouns/articles, use CamelCase

**Normal mode**:
- Append numbers for duplicates (TaskName, TaskName2, TaskName3)

## Prefix Stripping Rules

STRIP THESE PREFIXES from task names - they go in edge labels ONLY:
- "if X, I'll Y" → extract Y, put "if X" in edge label
- "if X, i will Y" → extract Y, put "if X" in edge label
- "otherwise I'll Y" → extract Y, put "otherwise" in edge label
- "otherwise i will Y" → extract Y, put "otherwise" in edge label
- "when X, I'll Y" → extract Y, put "when X" in edge label
- "after X, I'll Y" → extract Y, put "after X" in edge label
- "then I'll Y" → extract Y, put "then" in edge label

### Real-World Conditional Examples:

User: "if im in the mood, i will wash my dog, otherwise i will wash my car"
- Extract: names = ["WashMyDog", "WashMyCar"]
- Prefixes become edge labels: "if im in the mood", "otherwise"

User: "if raining, read book, otherwise, walk"
- Extract: names = ["ReadBook", "Walk"]
- Prefixes become edge labels: "if raining", "otherwise"

User: "I'll check my emails"
- Extract: names = ["CheckEmails"]
- No prefix to strip

## Pronoun and Article Removal Rules

CRITICAL: STRIP PRONOUNS AND ARTICLES FROM TASK NAMES:
Remove: "I'll", "my", "their", "they will", "the", "a", "an"

Examples:
- "I'll check my emails" → CheckEmails
- "take their dog for a walk" → TakeDogForWalk
- "brush my teeth" → BrushTeeth
- "grab a coffee" → GrabCoffee
- "check the news" → CheckNews

## Rename Mode Rules (correction_type=RENAME)

- Populate the 'renamed_to' field with the NEW task name (the one being renamed TO)
- DO NOT populate names with the old task name
- Set renamed_to to the task name that comes AFTER "to" or "instead"

Examples:
- "rename IfItIsRainingIWillReadMyBook to ReadBook" → renamed_to = "ReadBook", names = []
- "rename that task, have chat with colleagues, to chat with colleagues instead" → renamed_to = "ChatWithColleagues"
- "rename the task Continue working on project to Project Work" → renamed_to = "ProjectWork"
- "rename ContinueWorkingOnProject to ProjectWork" → renamed_to = "ProjectWork"

## Reordering Mode Rules (correction_type=REORDER)

- Extract the task names being reordered from user_message
- Use EXISTING names without adding numbers
- Example: User says "have coffee before checking news" when TakeCoffee and CheckNews exist
  → names = ["TakeCoffee", "CheckNews"] (no numbers added)

## Insertion Mode Rules (context.is_insertion=True)

CRITICAL: Distinguish between NEW tasks and EXISTING tasks:
- If a task name appears in existing_nodes: use the EXACT existing name (no numbers added)
- If a task name does NOT appear in existing_nodes: it's a NEW task, strip pronouns/articles, use CamelCase

Example: Graph has ["GrabCoffee", "CheckEmails"], user says "brush my teeth before checking emails"
  → "brush my teeth" is NEW → BrushTeeth, "checking emails" exists → CheckEmails
  → names = ["BrushTeeth", "CheckEmails"]

## Normal Mode Rules

- Append numbers for duplicates (TaskName, TaskName2, TaskName3)
