import from os { getenv }
import from urllib.request { Request, urlopen }
import from urllib.error { URLError, HTTPError }
import from json { loads, dumps }
import from dotenv { load_dotenv }
import from semantics.semantics {
    EmotionalState,
    ConversationIntent,
    ConversationContext,
    ConnectionType,
    TaskRelationship,
    IntentAnalysis,
    ExtractedTasks,
    AttachmentPointAnalysis,
    ConvergenceIntent,
    ThinkingSummary,
    TaskValidationResult,
    GraphValidationResult,
    RenameValidationResult,
    InsertValidationResult,
    ReorderValidationResult,
    EdgeLabelValidationResult,
    detect_emotional_state,
    analyze_conversation_intent,
    extract_raw_task_names,
    determine_attachment_points,
    detect_convergence_intent,
    build_task_relationships,
    generate_friendly_response,
    generate_next_suggestions,
    generate_thinking_summary,
    validate_task_extraction,
    validate_graph_structure,
    validate_rename_operation,
    validate_insert_operation,
    validate_reorder_operation,
    validate_edge_labels
}

node TaskState {
    has task_name: str;
    has created_at: str = "";
}

edge TaskFlow {
    has label: str = "";  # "then", "if yes", "option 1", etc.
}

node user_graph_data {
    has username: str = "anonymous";
    has last_task: str = "Start";
    has saved_routines: dict = {};
}

node manager_comm_data {
    has username: str = "anonymous";
    has last_response: str = "";
    has last_suggestions: list = [];
    has last_thinking: dict = {};
    has last_task_names: list = [];
    has last_emotional_state: str = "neutral";
    has validation_passed: bool = True;
    has validation_reason: str = "";
    has validation_type: str = "";
    has correction_needed: bool = False;
    has missing_tasks: list[str] = [];
    has incorrect_task: str = "";      # Existing task with wrong name that should be renamed
    has correct_task_name: str = "";    # What the task should be renamed to
}

node user_routines {
    has username: str = "anonymous";
    has routines: dict = {};
}

with entry {
    load_dotenv();
}

walker :pub get_session_token {
    can fetch with `root entry;
}

walker :pub init_user_graph {
    can initialize with `root entry;
}

walker :pub update_task_graph {
    has task_name: str;
    has previous_task: str = "Start";
    has edge_label: str = "";
    has username: str = "anonymous";

    can navigate_to_graph with `root entry;
    can update_graph with user_graph_data entry;
}

walker :pub get_task_graph {
    has username: str = "anonymous";

    can navigate_to_graph with `root entry;
    can get_graph with user_graph_data entry;
}

walker :pub clear_graph {
    has username: str = "anonymous";

    can navigate_to_graph with `root entry;
    can clear_data with user_graph_data entry;
}

walker :pub save_routine {
    has routine_name: str = "daily_routine";
    has username: str = "anonymous";

    can navigate_to_graph with `root entry;
    can save_routine_data with user_graph_data entry;
}

walker :pub load_past_routines {
    has username: str = "anonymous";

    can navigate_to_routines with `root entry;
    can load_routines with user_routines entry;
}

walker :pub reset_session {
    has username: str = "anonymous";

    can navigate_to_graph with `root entry;
    can reset_graph with user_graph_data entry;
}

walker :pub rebuild_graph {
    has new_nodes: list;
    has new_edges: list;
    has username: str = "anonymous";

    can navigate_to_graph with `root entry;
    can rebuild with user_graph_data entry;
}

walker :pub rename_task {
    has old_name: str;
    has new_name: str;
    has username: str = "anonymous";

    can navigate_to_graph with `root entry;
    can rename with user_graph_data entry;
}

walker :pub call_graph_agent {
    has conversation_history: list;
    has context_from_user: str;
    has username: str = "anonymous";

    can call with `root entry;
}

walker :pub call_manager {
    has conversation_history: list;
    has context_from_user: str;
    has username: str = "anonymous";

    can orchestrate with `root entry;
}

walker :pub validate_graph_output {
    has context_from_user: str;
    has intent_analysis: dict;
    has extracted_tasks: list;
    has before_nodes: list;
    has before_edges: list;
    has after_nodes: list;
    has after_edges: list;
    has username: str = "anonymous";

    can validate with `root entry;
}
