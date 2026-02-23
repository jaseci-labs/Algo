# useGraph Hook
# Custom hook for managing task graph state and operations
# Graph data now comes directly in the response - WebSocket style!

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
    has isProcessing: bool = False;
    has processingMessage: str = "";
    has displayEdges: list = [];  # Computed from graphEdges

    # Reactive effect: update displayEdges when graphEdges changes
    can with [graphEdges] entry {
        console.log("[useGraph] graphEdges changed, updating displayEdges:", graphEdges);
        displayEdges = Array.from(graphEdges);
    }

    # Update graph directly from response data - no separate fetch needed!
    # This is the WebSocket-style approach: data pushed to frontend
    def updateGraphFromResponse(edges: list, newLastTask: str) -> None {
        console.log("[useGraph] updateGraphFromResponse called with edges:", edges, "lastTask:", newLastTask);

        if edges and Array.isArray(edges) {
            graphEdges = Array.from(edges);
        }

        if newLastTask {
            lastTask = newLastTask;
        }

        # Clear processing state after graph is updated
        isProcessing = False;
        processingMessage = "";
    }

    # Set processing state
    def setProcessing(message: str) -> None {
        console.log("[useGraph] setProcessing called:", message);
        isProcessing = True;
        processingMessage = message;
    }

    # Add pending nodes - shows processing state immediately
    def addPendingNodes(taskNames: list, fromTask: str) -> None {
        console.log("[useGraph] addPendingNodes called:", taskNames, "from:", fromTask);

        isProcessing = True;

        if taskNames.length == 1 {
            processingMessage = "Adding: " + taskNames[0];
        } else {
            processingMessage = "Adding " + String(taskNames.length) + " tasks...";
        }
    }

    # Clear the task graph using service layer
    async def handleClearGraph() -> None {
        console.log("[useGraph] handleClearGraph called!");

        # IMMEDIATE clear - optimistic update for instant feedback
        graphDotCode = "";
        graphEdges = [];
        lastTask = "Start";

        try {
            username = getUsernameFromToken();
            result = await clearTaskGraph(username);
            console.log("[useGraph] clearTaskGraph result:", result);

            if result.success {
                # Already cleared locally, just add confirmation message
                addMessage("system", "Graph cleared! Starting fresh.");
            } else {
                addMessage("error", "Failed to clear graph");
            }
        } except Exception as e {
            console.error("Clear graph error:", e);
            addMessage("error", "Error clearing graph");
        }
    }

    # Load initial graph on mount
    async def loadInitialGraph() -> None {
        try {
            username = getUsernameFromToken();
            result = await getTaskGraph(username);
            console.log("[useGraph] loadInitialGraph result:", result);

            if result.success and result.data {
                graph_data = result.data;
                if graph_data.dotCode != None {
                    graphDotCode = String(graph_data.dotCode);
                }
                if graph_data.edges != None {
                    graphEdges = Array.from(graph_data.edges);
                }
                if graph_data.lastTask {
                    lastTask = graph_data.lastTask;
                }
            }
        } except Exception as e {
            console.error("Failed to load initial graph:", e);
        }
    }

    return {
        "graphDotCode": graphDotCode,
        "graphEdges": graphEdges,
        "displayEdges": displayEdges,
        "lastTask": lastTask,
        "isProcessing": isProcessing,
        "processingMessage": processingMessage,
        "updateGraphFromResponse": updateGraphFromResponse,
        "setProcessing": setProcessing,
        "addPendingNodes": addPendingNodes,
        "handleClearGraph": handleClearGraph,
        "loadInitialGraph": loadInitialGraph
    };
}
