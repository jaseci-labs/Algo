# Graph Layout Utilities
# Transforms edge data to React Flow format and applies ELK layout

import from "elkjs/lib/elk.bundled.js" { default as ELK }


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
        if `edge.`from {
            nodeSet.add(`edge.`from);
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
            "source": `edge.`from,
            "target": edge["to"],
            "label": edge["label"] or "",
            "type": "bezier"
        });
        idx = idx + 1;
    }

    return { "nodes": nodes, "edges": edges };
}

# Apply ELK layout to position nodes hierarchically
async def:pub getLayoutedElements(nodes: list, edges: list) -> dict {
    elk = Reflect.construct(ELK, []);

    elkGraph = {
        "id": "root",
        "layoutOptions": {
            "elk.algorithm": "layered",
            "elk.direction": "DOWN",
            "elk.layered.spacing.nodeNodeBetweenLayers": "50",
            "elk.spacing.nodeNode": "30"
        },
        "children": [],
        "edges": []
    };

    for node in nodes {
        width = START_NODE_SIZE if node.type == "startNode" else NODE_WIDTH;
        height = START_NODE_SIZE if node.type == "startNode" else NODE_HEIGHT;

        elkGraph.children.push({
            "id": node.id,
            "width": width,
            "height": height
        });
    }

    for edge in edges {
        elkGraph.edges.push({
            "id": edge["id"],
            "sources": Array.of(edge["source"]),
            "targets": Array.of(edge["target"])
        });
    }

    layout = await elk.layout(elkGraph);

    layoutedNodes = [];
    for node in nodes {
        lnode = layout.children.find(lambda n:any -> None { return n["id"] == node["id"]; });

        layoutedNodes.push(Object.assign({}, node, {
            "position": {
                "x": lnode["x"],
                "y": lnode["y"]
            }
        }));
    }

    return { "nodes": layoutedNodes, "edges": edges };
}
