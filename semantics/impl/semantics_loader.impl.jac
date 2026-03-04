"""Implementation of rule file loading for semantics module."""

import os;

impl load_task_extraction_rules() -> str {
    rules_path = os.path.join(os.getcwd(), "semantics", "data", "task_extraction_rules.md");
    try {
        with open(rules_path, "r") as f {
            return f.read();
        }
    } except (FileNotFoundError, OSError) {
        return "";
    }
}

impl load_connection_rules() -> str {
    rules_path = os.path.join(os.getcwd(), "semantics", "data", "connection_rules.md");
    try {
        with open(rules_path, "r") as f {
            return f.read();
        }
    } except (FileNotFoundError, OSError) {
        return "";
    }
}

impl load_conversation_intent_rules() -> str {
    rules_path = os.path.join(os.getcwd(), "semantics", "data", "conversation_intent_rules.md");
    try {
        with open(rules_path, "r") as f {
            return f.read();
        }
    } except (FileNotFoundError, OSError) {
        return "";
    }
}

impl load_validation_rules() -> str {
    rules_path = os.path.join(os.getcwd(), "semantics", "data", "validation_rules.md");
    try {
        with open(rules_path, "r") as f {
            return f.read();
        }
    } except (FileNotFoundError, OSError) {
        return "";
    }
}
