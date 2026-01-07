# useGraph Hook
# Custom hook for managing task graph state and operations

cl import from react { useState }

cl import from ..service.mainAppService {
    getTaskGraph,
    clearTaskGraph,
    getUsernameFromToken
}

cl {
    def:pub useGraph(addMessage: any) -> any {
        # Graph state for task visualization
        [graphDotCode, setGraphDotCode] = useState("");
        [graphEdges, setGraphEdges] = useState([]);
        [lastTask, setLastTask] = useState("Start");
        
        # Fetch and update graph state from backend using service layer
        async def refreshGraphState(username: str) -> None {
            try {
                result = await getTaskGraph(username);
                console.log("Fetched updated graph:", result);

                if result.success and result.data {
                    graph_data = result.data;
                    console.log("Graph data received:", graph_data);

                    if graph_data.dotCode != None {
                        newDotCode = String(graph_data.dotCode);
                        console.log("Setting new DOT code, length:", newDotCode.length);
                        setGraphDotCode(newDotCode);
                    }
                    if graph_data.edges != None {
                        newEdges = Array.from(graph_data.edges);
                        console.log("Setting new edges, count:", newEdges.length);
                        setGraphEdges(newEdges);
                    }
                    if graph_data.lastTask {
                        setLastTask(graph_data.lastTask);
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
                console.log("Clear graph response:", result);
                
                if result.success {
                    data = result.data;
                    setGraphDotCode(data.dotCode or "");
                    setGraphEdges(data.edges or []);
                    setLastTask(data.lastTask or "Start");
                    
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
}
