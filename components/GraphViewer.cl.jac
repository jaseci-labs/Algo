# GraphViewer Component - Modern React Flow Visualization
import from react { useState, useEffect, useMemo }
import from "@xyflow/react" {
    ReactFlow,
    Background,
    Controls,
    MiniMap,
    useNodesState,
    useEdgesState
}
import "@xyflow/react/dist/style.css";

import from .nodes.StartNode { StartNode }
import from .nodes.TaskNode { TaskNode }
import from ..utils.graphLayout { transformGraphData, getLayoutedElements }

# Define custom node types
glob NODE_TYPES = {
    "startNode": StartNode,
    "taskNode": TaskNode
};

# Default edge options - bezier for curved lines with better label positioning
glob DEFAULT_EDGE_OPTIONS = {
    "type": "bezier",
    "animated": False,
    "labelBgPadding": [8, 4],
    "labelBgBorderRadius": 4
};

def:pub GraphViewer(graphEdges: list) -> any {
    [nodes, setNodes, onNodesChange] = useNodesState([]);
    [edges, setEdges, onEdgesChange] = useEdgesState([]);
    [isLoading, setIsLoading] = useState(True);

    # Transform and layout graph when edges change
    useEffect(
        lambda -> None {
            if not graphEdges or graphEdges.length == 0 {
                # Empty state - just show Start node centered
                startNode = {
                    "id": "Start",
                    "type": "startNode",
                    "data": { "label": "Start" },
                    "position": { "x": 250, "y": 50 }
                };
                setNodes([startNode]);
                setEdges([]);
                setIsLoading(False);
                return;
            }

            setIsLoading(True);

            # Async layout function
            async def layoutGraph() -> None {
                try {
                    # Transform edge data to React Flow format
                    transformed = transformGraphData(graphEdges);


                    # Apply ELK layout for automatic positioning (async)
                    layouted = await getLayoutedElements(
                        transformed.nodes,
                        transformed.edges
                    );

                    setNodes(layouted.nodes);
                    setEdges(layouted.edges);
                } except Exception as e {
                    console.error("Error laying out graph:", e);
                }
                setIsLoading(False);
            }

            layoutGraph();
        },
        [graphEdges]
    );

    # Memoize node types to prevent re-renders
     nodeTypes = useMemo(
        lambda -> dict { return NODE_TYPES; },
        []
    );

    # Empty state (no edges and not loading)
    if (not graphEdges or graphEdges.length == 0) and not isLoading and nodes.length == 0 {
        return <div className="flex items-center justify-center h-full text-text-secondary text-sm text-center p-8">
            <div>
                <div className="text-4xl mb-2">{"🌳"}</div>
                <div>{"Your task graph will appear here"}</div>
            </div>
        </div>;
    }

    # Loading state
    if isLoading {
        return <div className="flex items-center justify-center h-full text-text-secondary">
            <div className="flex items-center gap-2">
                <div className="w-5 h-5 border-2 border-text-secondary/30 border-t-text-secondary rounded-full animate-spin" />
                <span>{"Loading graph..."}</span>
            </div>
        </div>;
    }

    # Helper function for minimap node colors
    def getNodeColor(node: any) -> str {
        if node.type == "startNode" {
            return "hsl(var(--primary))";
        }
        return "hsl(var(--foreground))";
    }

    # Rendered graph with React Flow
    return <div className="w-full h-full graph-viewer-container">
        <ReactFlow
            nodes={nodes}
            edges={edges}
            nodeTypes={nodeTypes}
            defaultEdgeOptions={DEFAULT_EDGE_OPTIONS}
            fitView={True}
            fitViewOptions={{
                "padding": 0.2,
                "minZoom": 0.3,
                "maxZoom": 1
            }}
            nodesDraggable={False}
            nodesConnectable={False}
            elementsSelectable={False}
            panOnDrag={True}
            zoomOnScroll={True}
            zoomOnPinch={True}
            minZoom={0.2}
            maxZoom={1.5}
        >
            <Background
                gap={12}
                size={1}
                variant="dots"
            />
            <Controls showInteractive={False} />
            <MiniMap
                nodeColor={getNodeColor}
                nodeBorderRadius={4}
                zoomable={True}
                pannable={True}
            />
        </ReactFlow>
    </div>;
}