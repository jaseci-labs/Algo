# mainAppService - Service Layer for MainApp
# Centralizes all root spawn API calls for better reusability and maintainability
# This service layer abstracts backend communication from UI components

# ============================================
# Graph Service
# ============================================

# Fetch the task graph for a specific user
# @param username - The username to fetch the graph for
# @returns Graph data containing dotCode, edges, and lastTask
async def:pub getTaskGraph(username: str) -> any {
        try {
            response = root spawn get_task_graph(username=username);
            
            if response and response.reports and response.reports.length > 0 {
                return {
                    "success": True,
                    "data": response.reports[0]
                };
            }
            
            return {
                "success": False,
                "error": "No data returned from get_task_graph"
            };
        } except Exception as e {
            console.error("getTaskGraph error:", e);
            return {
                "success": False,
                "error": String(e)
            };
        }
    }

# Clear the task graph for a specific user
# @param username - The username whose graph should be cleared
# @returns Success status and cleared graph data
async def:pub clearTaskGraph(username: str) -> any {
    try {
        clearResponse = root spawn clear_graph(username=username);
        clearResult = clearResponse.reports[0] if clearResponse.reports else {};
        
        if clearResult and clearResult.success {
            # Fetch the updated (empty) graph state
            graphResponse = root spawn get_task_graph(username=username);
            graphData = graphResponse.reports[0] if graphResponse.reports else {};
            
            return {
                "success": True,
                "data": {
                    "dotCode": graphData.dotCode or "",
                    "edges": graphData.edges or [],
                    "lastTask": graphData.lastTask or "Start"
                }
            };
        }
        
        return {
            "success": False,
            "error": clearResult.error if clearResult and clearResult.error else "Failed to clear graph"
        };
    } except Exception as e {
        console.error("clearTaskGraph error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}


# ============================================
# Session Service
# ============================================

# Fetch ephemeral session token for OpenAI Realtime API
# @returns The ephemeral API key or None if failed
async def:pub getSessionToken() -> any {
    try {
        response = root spawn get_session_token();
        data = response.reports[0] if response.reports else None;
        
        if data and "error" in data {
            console.error("Error fetching session:", data);
            return {
                "success": False,
                "error": data.error or "Session token error"
            };
        }
        
        if data and "key" in data {
            return {
                "success": True,
                "key": data.key
            };
        }
        
        return {
            "success": False,
            "error": "No key returned from get_session_token"
        };
    } except Exception as e {
        console.error("getSessionToken error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}


# ============================================
# Supervisor Service
# ============================================

# Call the supervisor agent with conversation context
# @param context_from_user - The relevant context from user's message
# @param conversation_history - Array of conversation history items
# @param username - The current user's username
# @returns Manager response with nextResponse or error
async def:pub callManager(context_from_user: str, conversation_history: list, username: str) -> any {
    console.log("[API] callManager called with context:", context_from_user);
    try {
        result = root spawn call_manager(
            conversation_history=conversation_history,
            context_from_user=context_from_user,
            username=username
        );

        console.log("[API] result.reports:", result.reports);
        response_data = result.reports[result.reports.length - 1] if result.reports and result.reports.length > 0 else {};
        console.log("[API] response_data from backend:", response_data);

        if response_data and "error" in response_data {
            console.error("Manager error:", response_data);
            return {
                "success": False,
                "error": response_data.error or "Manager error"
            };
        }

        # Extract response
        next_resp = "";
        if "response" in response_data {
            next_resp = response_data["response"];
        } else {
            next_resp = "I apologize, I couldn't get a response.";
        }

        # Extract suggestions if available
        suggestions = [];
        if "suggestions" in response_data {
            suggestions = response_data["suggestions"];
        }

        # Extract thinking insights if available
        thinking = None;
        if "thinking" in response_data {
            thinking = response_data["thinking"];
        }

        # Extract task_names for incremental graph updates
        task_names = [];
        if "task_names" in response_data {
            task_names = response_data["task_names"];
            console.log("[API] task_names extracted:", task_names);
        }

        # Extract graph data directly from response - no separate fetch needed!
        graph_edges = [];
        if "graph_edges" in response_data {
            graph_edges = response_data["graph_edges"];
            console.log("[API] graph_edges extracted:", graph_edges);
        }

        graph_last_task = "Start";
        if "graph_last_task" in response_data {
            graph_last_task = response_data["graph_last_task"];
            console.log("[API] graph_last_task extracted:", graph_last_task);
        }

        console.log("[API] Returning from callManager with task_names:", task_names);
        return {
            "success": True,
            "response": next_resp,
            "suggestions": suggestions,
            "thinking": thinking,
            "task_names": task_names,
            "graph_edges": graph_edges,  # Direct graph data - WebSocket style!
            "graph_last_task": graph_last_task,
            "data": response_data
        };
    } except Exception as e {
        console.error("callManager error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# Legacy function - redirects to callManager for backward compatibility
async def:pub callSupervisor(context_from_user: str, conversation_history: list, username: str) -> any {
    return await callManager(context_from_user, conversation_history, username);
}
# Send a text message to the supervisor (simplified version for text-only mode)
# @param message - The user's message
# @param username - The current user's username
# @returns Supervisor response
async def:pub sendTextMessage(message: str, username: str) -> any {
    return await callSupervisor(
        context_from_user=message,
        conversation_history=[],
        username=username
    );
}


# ============================================
# Routine Service
# ============================================

# Save the current routine for a user
# @param routine_name - Name of the routine to save
# @param username - The current user's username
# @returns Success status and any error message
async def:pub saveRoutine(routine_name: str, username: str) -> any {
    try {
        saveResponse = root spawn save_routine(routine_name=routine_name, username=username);
        saveResult = saveResponse.reports[0] if saveResponse.reports else {};
        
        if saveResult and saveResult.success {
            return {
                "success": True,
                "data": saveResult
            };
        }
        
        return {
            "success": False,
            "error": saveResult.error if saveResult and saveResult.error else "Failed to save routine"
        };
    } except Exception as e {
        console.error("saveRoutine error:", e);
        return {
            "success": False,
            "error": String(e)
        };
    }
}

# Save the default daily routine
# @param username - The current user's username
# @returns Success status
async def:pub saveDailyRoutine(username: str) -> any {
    return await saveRoutine(routine_name="daily_routine", username=username);
}


# ============================================
# Utility Functions
# ============================================

# Extract username from JWT token stored in localStorage
# @returns Username string or "anonymous" if not found
def:pub getUsernameFromToken() -> str {
    token = localStorage.getItem("jac_token");
    username = "anonymous";
    if token {
        try {
            parts = token.split(".");
            if parts.length > 1 {
                payload = JSON.parse(atob(parts[1]));
                username = payload.username or "anonymous";
            }
        } except Exception as decode_error {
            console.error("Failed to decode token:", decode_error);
        }
    }
    return username;
}

# Check if user is authenticated
# @returns True if user has a valid token
def:pub isAuthenticated() -> bool {
    token = localStorage.getItem("jac_token");
    return token != None and token != "";
}
