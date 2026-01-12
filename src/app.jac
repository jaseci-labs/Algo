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
    detect_emotional_state,
    analyze_conversation_intent,
    extract_task_sequence,
    generate_friendly_response,
    generate_decision_reasoning,
    generate_next_suggestions
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

node user_routines {
    has username: str = "anonymous";
    has routines: dict = {};
}

with entry {
    load_dotenv();
}

walker get_session_token {
    can fetch with `root entry;
}

walker init_user_graph {
    can initialize with `root entry;
}

walker update_task_graph {
    has task_name: str;
    has previous_task: str = "Start";
    has edge_label: str = "";
    has username: str = "anonymous";

    can navigate_to_graph with `root entry;
    can update_graph with user_graph_data entry;
}

walker get_task_graph {
    has username: str = "anonymous";

    can navigate_to_graph with `root entry;
    can get_graph with user_graph_data entry;
}

walker clear_graph {
    has username: str = "anonymous";
    
    can navigate_to_graph with `root entry;
    can clear_data with user_graph_data entry;
}

walker save_routine {
    has routine_name: str = "daily_routine";
    has username: str = "anonymous";

    can navigate_to_graph with `root entry;
    can save_routine_data with user_graph_data entry;
}

walker load_past_routines {
    has username: str = "anonymous";
    
    can navigate_to_routines with `root entry;
    can load_routines with user_routines entry;
}

walker reset_session {
    has username: str = "anonymous";
    
    can navigate_to_graph with `root entry;
    can reset_graph with user_graph_data entry;
}

walker rebuild_graph {
    has new_nodes: list;
    has new_edges: list;
    has username: str = "anonymous";
    
    can navigate_to_graph with `root entry;
    can rebuild with user_graph_data entry;
}

walker call_supervisor {
    has conversation_history: list;
    has context_from_user: str;
    has username: str = "anonymous";
    
    can call with `root entry;
}
