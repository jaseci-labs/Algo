# useGraph Hook
# Custom hook for managing task graph state and operations

import from react { useRef }

import from ..api.api {
    getTaskGraph,
    clearTaskGraph,
    getUsernameFromToken
}

def:pub useGraph(addMessage: any) -> any {
    # Reactive state using has variables
    has graphDotCode: str = "";
    has graphEdges: list = [];
    has lastTask: str = "Start";

    # Track processing state for incremental updates
    has displayEdges: list = [];  # Merged graphEdges + pendingEdges
    has pendingEdges: list = [];  # Optimistic pending edges
    has isProcessing: bool = False;
    has processingMessage: str = "";

    # Refs to always access current state values (avoids closure stale values)
    graphEdgesRef = useRef([]);
    pendingEdgesRef = useRef([]);

    # Sync refs with state whenever values change
    can with [graphEdges] entry {
        graphEdgesRef.current = graphEdges;
    }
    can with [pendingEdges] entry {
        pendingEdgesRef.current = pendingEdges;
    }

    # Fetch and update graph state from backend using service layer
    async def refreshGraphState(username: str) -> None {
        console.log("[useGraph] refreshGraphState called for:", username);
        try {
            result = await getTaskGraph(username);
            console.log("[useGraph] getTaskGraph result:", result);

            if result.success and result.data {
                graph_data = result.data;
                console.log("[useGraph] graph_data:", graph_data);

                if graph_data.dotCode != None {
                    newDotCode = String(graph_data.dotCode);
                    graphDotCode = newDotCode;
                }
                if graph_data.edges != None {
                    newEdges = Array.from(graph_data.edges);
                    graphEdges = newEdges;
                    console.log("[useGraph] graphEdges updated:", graphEdges);
                }
                if graph_data.lastTask {
                    lastTask = graph_data.lastTask;
                    console.log("[useGraph] lastTask updated:", lastTask);
                }

                # Small delay before clearing pending to show "adding..." state
                setTimeout(lambda -> None {
                    console.log("[useGraph] Clearing pending after timeout");
                    clearPending();
                }, 500);
            } else {
                console.error("[useGraph] Failed to fetch graph:", result.error);
            }
        } except Exception as graph_error {
            console.error("Failed to fetch updated graph:", graph_error);
        }
    }

    # Update display edges - inlined to avoid closure stale values
    # NOTE: This is called directly from can with block to get fresh values
    def updateDisplayEdgesImpl(currentGraphEdges: list, currentPendingEdges: list) -> list {
        console.log("[useGraph] updateDisplayEdgesImpl called");
        console.log("[useGraph] currentGraphEdges:", currentGraphEdges);
        console.log("[useGraph] currentPendingEdges:", currentPendingEdges);

        merged = Array.from(currentGraphEdges);

        # Add any pending edges not already in base - IMMUTABLY
        for pending in currentPendingEdges {
            exists = merged.some(lambda edge: any -> bool {
                return edge.from == pending.from and edge.to == pending.to;
            });

            if not exists {
                # CRITICAL: Use concat() instead of + to avoid string concatenation
                # In JavaScript, array + array = string concatenation!
                merged = merged.concat([pending]);
                console.log("[useGraph] Added pending edge:", pending);
            }
        }

        console.log("[useGraph] Final merged edges:", merged);
        return merged;
    }

    # Add pending nodes optimistically before backend confirms
    def addPendingNodes(taskNames: list, fromTask: str) -> None {
        console.log("[DEBUG] addPendingNodes called:", taskNames, "from:", fromTask);

        # Use ref to get current pendingEdges value
        currentPending = pendingEdgesRef.current;
        console.log("[DEBUG] currentPending from ref:", currentPending);

        # Build new edges array all at once
        newEdges = [];
        for name in taskNames {
            newEdge = {
                "from": fromTask,
                "to": name,
                "label": "adding...",
                "pending": True
            };
            newEdges.push(newEdge);
        }

        # Use concat to create new array
        updatedPending = currentPending.concat(newEdges);
        pendingEdges = updatedPending;
        isProcessing = True;

        if taskNames.length == 1 {
            processingMessage = "Adding: " + taskNames[0];
        } else {
            processingMessage = "Adding " + String(taskNames.length) + " tasks...";
        }

        console.log("[DEBUG] pendingEdges after set:", updatedPending);
        console.log("[DEBUG] isProcessing:", isProcessing);
    }

    # Clear pending nodes and sync with backend
    def clearPending() -> None {
        console.log("[DEBUG] clearPending called");
        pendingEdges = [];
        isProcessing = False;
        processingMessage = "";
    }

    # Reactive effect: update displayEdges when graphEdges or pendingEdges changes
    can with [graphEdges, pendingEdges] entry {
        displayEdges = updateDisplayEdgesImpl(graphEdges, pendingEdges);
    }

    # Clear the task graph using service layer
    async def handleClearGraph() -> None {
        console.log("[useGraph] handleClearGraph called!");
        try {
            username = getUsernameFromToken();
            console.log("[useGraph] Clearing graph for user:", username);

            result = await clearTaskGraph(username);
            console.log("[useGraph] clearTaskGraph result:", result);

            if result.success {
                data = result.data;
                console.log("[useGraph] Graph data after clear:", data);
                graphDotCode = data.dotCode or "";
                graphEdges = data.edges or [];
                lastTask = data.lastTask or "Start";

                console.log("[useGraph] Calling addMessage for system notification");
                addMessage("system", "Graph cleared! Starting fresh.");
                console.log("[useGraph] addMessage called successfully");
            } else {
                addMessage("error", "Failed to clear graph");
            }
        } except Exception as e {
            console.error("Clear graph error:", e);
            addMessage("error", "Error clearing graph");
        }
    }

    return {
        "graphDotCode": graphDotCode,
        "graphEdges": graphEdges,
        "displayEdges": displayEdges,
        "lastTask": lastTask,
        "isProcessing": isProcessing,
        "processingMessage": processingMessage,
        "refreshGraphState": refreshGraphState,
        "addPendingNodes": addPendingNodes,
        "clearPending": clearPending,
        "handleClearGraph": handleClearGraph
    };
}