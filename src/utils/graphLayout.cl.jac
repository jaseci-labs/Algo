# Graph Layout Utilities
# Transforms edge data to React Flow format and applies dagre layout

import from "@dagrejs/dagre" { graphlib, layout }

# Node dimensions
glob NODE_WIDTH = 180;
glob NODE_HEIGHT = 50;
glob START_NODE_SIZE = 70;

# Helper function to add spaces before capital letters in camelCase strings

def addSpacesToCamelCase(word:str) -> str{
    
   result = '';

  for i = 0 to i < word.length by i+=1{
    char = word[i];
    if (i > 0 && char == char.toUpperCase() && char != char.toLowerCase()) {
      result += ' ';
    }

    result += char;
  }

  return result;
}

# Transform raw edge data to React Flow nodes and edges format
def:pub transformGraphData(graphEdges: list) -> dict {
    nodeSet = Reflect.construct(Set, []);

    # Always include Start node
    nodeSet.add("Start");

    # Extract unique nodes from edges
    for edge in graphEdges {
        if <>edge.<>from {
            nodeSet.add(<>edge.<>from);
        }
        if edge["to"] {
            nodeSet.add(edge["to"]);
        }
    }

    # Create nodes array with formatted labels
    nodes = [];
    for nodeId in nodeSet {
        displayLabel = addSpacesToCamelCase(nodeId) or nodeId;
        nodes.push({
            "id": nodeId,
            "type": "startNode" if nodeId == "Start" else "taskNode",
            "data": { "label": displayLabel },
            "position": { "x": 0, "y": 0 }
        });
    }

    # Create edges array
    edges = [];
    idx = 0;
    for edge in graphEdges {
        edges.push({
            "id": f"edge-{idx}",
            "source": <>edge.<>from,
            "target": edge["to"],
            "label": edge["label"] or "",
            "type": "bezier"
        });
        idx = idx + 1;
    }

    return { "nodes": nodes, "edges": edges };
}

# Apply dagre layout to position nodes hierarchically
def:pub getLayoutedElements(nodes: list, edges: list) -> dict {
    dagreGraph = Reflect.construct(graphlib.Graph, []);
    dagreGraph.setDefaultEdgeLabel(lambda -> dict { return {}; });

    # Layout configuration for top-to-bottom flow
    dagreGraph.setGraph({
        "rankdir": "TB",
        "nodesep": 80,
        "ranksep": 100,
        "marginx": 20,
        "marginy": 20
    });

    # Add nodes to dagre graph with dimensions
    for node in nodes {
        width = START_NODE_SIZE if node.type == "startNode" else NODE_WIDTH;
        height = START_NODE_SIZE if node.type == "startNode" else NODE_HEIGHT;
        dagreGraph.setNode(node.id, { "width": width, "height": height });
    }

    # Add edges to dagre graph
    for edge in edges {
        dagreGraph.setEdge(edge.source, edge.target);
    }

    # Calculate layout
    layout(dagreGraph);

    # Apply calculated positions to nodes (dagre gives center, React Flow uses top-left)
    layoutedNodes = [];
    for node in nodes {
        nodeWithPosition = dagreGraph.node(node.id);
        width = START_NODE_SIZE if node.type == "startNode" else NODE_WIDTH;
        height = START_NODE_SIZE if node.type == "startNode" else NODE_HEIGHT;

        layoutedNodes.push(Object.assign({}, node, {
            "position": {
                "x": nodeWithPosition.x - width / 2,
                "y": nodeWithPosition.y - height / 2
            }
        }));
    }

    return { "nodes": layoutedNodes, "edges": edges };
}