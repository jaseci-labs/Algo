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
    PersonalizedInsight,
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
    validate_edge_labels,
    generate_personalized_insights
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

# Analytics: Activity Event Tracking
node ActivityEvent {
    has event_type: str;
    has timestamp: str;
    has event_data: dict = {};
    has session_id: str = "";
}

edge EventFlow {
    has temporal_order: int = 0;
}

with entry {
    load_dotenv();
}

walker :pub get_session_token {
    can fetch with Root entry;
}

walker :pub init_user_graph {
    can initialize with Root entry;
}

walker :pub update_task_graph {
    has task_name: str;
    has previous_task: str = "Start";
    has edge_label: str = "";
    has username: str = "anonymous";

    can navigate_to_graph with Root entry;
    can update_graph with user_graph_data entry;
}

walker :pub get_task_graph {
    has username: str = "anonymous";

    can navigate_to_graph with Root entry;
    can get_graph with user_graph_data entry;
}

walker :pub clear_graph {
    has username: str = "anonymous";

    can navigate_to_graph with Root entry;
    can clear_data with user_graph_data entry;
}

walker :pub save_routine {
    has routine_name: str = "daily_routine";
    has username: str = "anonymous";

    can navigate_to_graph with Root entry;
    can save_routine_data with user_graph_data entry;
}

walker :pub load_past_routines {
    has username: str = "anonymous";

    can navigate_to_routines with Root entry;
    can load_routines with user_routines entry;
}

walker :pub reset_session {
    has username: str = "anonymous";

    can navigate_to_graph with Root entry;
    can reset_graph with user_graph_data entry;
}

walker :pub rebuild_graph {
    has new_nodes: list;
    has new_edges: list;
    has username: str = "anonymous";

    can navigate_to_graph with Root entry;
    can rebuild with user_graph_data entry;
}

walker :pub rename_task {
    has old_name: str;
    has new_name: str;
    has username: str = "anonymous";

    can navigate_to_graph with Root entry;
    can rename with user_graph_data entry;
}

walker :pub call_graph_agent {
    has conversation_history: list;
    has context_from_user: str;
    has username: str = "anonymous";

    can call with Root entry;
}

walker :pub call_manager {
    has conversation_history: list;
    has context_from_user: str;
    has username: str = "anonymous";

    can orchestrate with Root entry;
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

    can validate with Root entry;
}

# ========== Analytics Walkers ==========

walker :pub get_activity_report {
    has username: str = "anonymous";
    has date_range: dict = {};

    can generate_report with Root entry;
}

walker :pub get_trend_analysis {
    has username: str = "anonymous";
    has period: str = "week";

    can analyze_trends with Root entry;
}

walker :pub analyze_behavioral_patterns {
    has username: str = "anonymous";

    can extract_patterns with Root entry;
}

walker :pub calculate_productivity_metrics {
    has username: str = "anonymous";

    can compute_metrics with Root entry;
}

walker :pub generate_insights {
    has username: str = "anonymous";
    has category: str = "all";

    can create_insights with Root entry;
}

# Event Logging Walker
walker :pub log_activity_event {
    has event_type: str;
    has event_data: dict = {};
    has session_id: str = "";
    has username: str = "anonymous";
    can log_event with Root entry;
}

# Real Trends Analysis Walker
walker :pub compute_real_trends {
    has username: str = "anonymous";
    has period: str = "week";

    can compute_trends with Root entry;
}
