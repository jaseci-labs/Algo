# useGraph Hook
# Custom hook for managing task graph state and operations

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

    # Fetch and update graph state from backend using service layer
    async def refreshGraphState(username: str) -> None {
        try {
            result = await getTaskGraph(username);

            if result.success and result.data {
                graph_data = result.data;

                if graph_data.dotCode != None {
                    newDotCode = String(graph_data.dotCode);
                    graphDotCode = newDotCode;
                }
                if graph_data.edges != None {
                    newEdges = Array.from(graph_data.edges);
                    graphEdges = newEdges;
                }
                if graph_data.lastTask {
                    lastTask = graph_data.lastTask;
                }
            } else {
                console.error("Failed to fetch graph:", result.error);
            }
        } except Exception as graph_error {
            console.error("Failed to fetch updated graph:", graph_error);
        }
    }

    # Clear the task graph using service layer
    async def handleClearGraph() -> None {
        try {
            username = getUsernameFromToken();

            result = await clearTaskGraph(username);

            if result.success {
                data = result.data;
                graphDotCode = data.dotCode or "";
                graphEdges = data.edges or [];
                lastTask = data.lastTask or "Start";

                addMessage("system", "Graph cleared! Starting fresh.");
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
        "lastTask": lastTask,
        "refreshGraphState": refreshGraphState,
        "handleClearGraph": handleClearGraph
    };
}
