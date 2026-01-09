impl get_session_token.fetch {
    try {
        api_key = getenv("OPENAI_API_KEY");

        if not api_key {
            report {"error": "OPENAI_API_KEY not set in environment"} ;
            return;
        }

        url = "https://api.openai.com/v1/realtime/client_secrets";
        request_data = dumps(
            {"session": {"type": "realtime", "model": "gpt-realtime"}}
        );

        req = Request(
            url,
            data=request_data.encode('utf-8'),
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            },
            method="POST"
        );

        response = urlopen(req);
        data = loads(response.read().decode('utf-8'));

        if "value" in data {
            report {"key": data["value"]} ;
        } else {
            report {"error": "Failed to fetch key", "details": data} ;
        }
    } except HTTPError as e {
        error_msg = e.read().decode('utf-8') if hasattr(e, 'read') else str(e);
        report {"error": f"HTTP Error: {e.code}", "details": error_msg} ;
    } except URLError as e {
        report {"error": "URL Error", "details": str(e.reason)} ;
    } except Exception as e {
        report {"error": "Server error", "details": str(e)} ;
    }
}

impl traverse_graph.traverse_node {
    node_name = here.task_name;
    print(f"[TRAVERSE] Visiting node: {node_name}");
    already_visited = node_name in self.visited;
    
    if not already_visited {
        self.visited[node_name] = True;
        self.nodes_list.append(node_name);
    } else {
        print(f"[TRAVERSE] Already visited {node_name}, but continuing to check children");
    }

    all_edges = [edge here->:TaskFlow:->];
    print(f"[TRAVERSE] Node {node_name} has {len(all_edges)} TaskFlow edges");

    # Get direct successors (only immediate children)
    successors = [-->](`?TaskState);
    print(f"[TRAVERSE] Found {len(successors)} successors from {node_name}");

    # Match edges to successors by index
    # In Jac OSP, the order of edges typically matches the order of successors
    successor_idx = 0;
    for next_node in successors {
        if hasattr(next_node, 'task_name') {
            print(f"[TRAVERSE]   Successor [{successor_idx}]: {next_node.task_name}");

            # Get the corresponding edge label if available
            edge_label = "";
            if successor_idx < len(all_edges) {
                e = all_edges[successor_idx];
                edge_label = e.label if hasattr(e, 'label') else "";
            }

            # Add edge only if not already in list (avoid duplicate edges)
            edge_key = f"{node_name}->{next_node.task_name}";
            edge_exists = False;
            for existing_edge in self.edges_list {
                if existing_edge.get("from", "") == node_name and existing_edge.get("to", "") == next_node.task_name {
                    edge_exists = True;
                    break;
                }
            }
            
            if not edge_exists {
                self.edges_list.append({
                    "from": node_name,
                    "to": next_node.task_name,
                    "label": edge_label
                });
                print(f"[TRAVERSE]   Added edge: {node_name} --[{edge_label}]--> {next_node.task_name}");
            }

            successor_idx = successor_idx + 1;

            # Continue traversing
            visit next_node;
        }
    }
}

#WALKER: init_user_graph
impl init_user_graph.initialize {
    visit [-->](`?user_graph_data) else {
        # Create user graph container
        graph_cont = here ++> user_graph_data();

        # Create initial "Start" TaskState node connected to the graph
        start_node = TaskState(task_name="Start");
        graph_cont ++> start_node;
    }
    visit [-->](`?user_routines) else {
        routine_cont = here ++> user_routines();
    }
}

# WALKER: update_task_graph
impl update_task_graph.navigate_to_graph {
    # Find or create user-specific graph based on username
    all_graphs = [-->](`?user_graph_data);
    
    user_graph = None;
    for graph in all_graphs {
        if hasattr(graph, 'username') and graph.username == self.username {
            user_graph = graph;
            break;
        }
    }
    
    if user_graph == None {
        # Create new graph for this user
        user_graph = here ++> user_graph_data(username=self.username);
    }
    
    visit user_graph;
}

impl update_task_graph.update_graph {
    # Find or create the previous task node
    prev_node = None;
    
    # Search ALL TaskState nodes in the graph, not just those connected to user_graph_data
    # Start with nodes directly connected to user_graph_data
    all_task_nodes = [-->](`?TaskState);
    
    # Also traverse the graph to find all reachable TaskState nodes
    visited_for_search = {};
    nodes_to_check = all_task_nodes.copy();
    
    while len(nodes_to_check) > 0 {
        current = nodes_to_check.pop(0);
        if hasattr(current, 'task_name') {
            node_id = current.task_name;
            if node_id not in visited_for_search {
                visited_for_search[node_id] = current;
                # Get successors via TaskFlow edges
                successors = [current-->](`?TaskState);
                for succ in successors {
                    nodes_to_check.append(succ);
                }
            }
        }
    }
    
    # Now search for the previous task in all found nodes
    for node_name in visited_for_search {
        nodex = visited_for_search[node_name];
        if nodex.task_name == self.previous_task {
            prev_node = nodex;
            break;
        }
    }

    # If previous task doesn't exist, create it (shouldn't happen normally, but safe fallback)
    if prev_node == None {
        print(f"[DEBUG CREATE] Creating prev_node: {self.previous_task}");
        prev_node = TaskState(task_name=self.previous_task);
        # Only connect to user_graph_data if it's the Start node
        # All other nodes should only be reachable through TaskFlow edges
        if self.previous_task == "Start" {
            here ++> prev_node;
            print(f"[DEBUG CREATE] Connected {self.previous_task} to user_graph_data");
        } else {
            print(f"[DEBUG CREATE] WARNING: Creating orphaned node {self.previous_task} - it won't be reachable!");
        }
    }

    # Find or create the new task node
    new_node = None;
    for node_name in visited_for_search {
        nodex = visited_for_search[node_name];
        if nodex.task_name == self.task_name {
            new_node = nodex;
            break;
        }
    }

    if new_node == None {
        # Create new task node
        print(f"[DEBUG CREATE] Creating new_node: {self.task_name}");
        import from datetime { datetime }
        new_node = TaskState(
            task_name=self.task_name,
            created_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        );
        # Don't connect to user_graph_data - nodes are only reachable through TaskFlow edges
        # This ensures traversal from Start works correctly
        print(f"[DEBUG CREATE] Created {self.task_name} (will be connected via TaskFlow edge)");
    }

    # For branching logic (multiple paths from one node), we always create the edge
    # Jac OSP supports multiple edges from one node to different nodes
    # NOTE: We're not checking for duplicates here - each call creates a new edge
    # This is intentional to support branching workflows (if/else, options, etc.)

    # Always create the edge to support branching
    if True {
        print(f"[DEBUG EDGE] Creating edge: {self.previous_task} --[{self.edge_label}]--> {self.task_name}");
        print(f"[DEBUG EDGE] prev_node type: {type(prev_node)}, new_node type: {type(new_node)}");
        prev_node +>:TaskFlow(label=self.edge_label):+> new_node;
        print(f"[DEBUG EDGE] Edge created successfully");

        # Verify the edge was created
        verify_edges = [edge prev_node->:TaskFlow:->];
        print(f"[DEBUG EDGE] prev_node now has {len(verify_edges)} TaskFlow edges");
    }

    # Update last task
    here.last_task = self.task_name;

    # Use helper walker to traverse the graph and collect structure
    # Find the "Start" node to begin traversal
    all_task_nodes = [-->](`?TaskState);
    print(f"[DEBUG] Found {len(all_task_nodes)} TaskState nodes connected to user_graph_data");

    start_node = None;
    for node in all_task_nodes {
        if hasattr(node, 'task_name') {
            print(f"[DEBUG]   Node: {node.task_name}");
            if node.task_name == "Start" {
                start_node = node;
            }
        }
    }

    node_list = [];
    edge_list = [];

    if start_node != None {
        print(f"[DEBUG] Starting traversal from Start node");
        # Spawn walker at the Start node
        traverser = start_node spawn traverse_graph();

        # Get the collected node and edge lists from the walker
        node_list = traverser.nodes_list;
        edge_list = traverser.edges_list;
    } else {
        print(f"[DEBUG] WARNING: Start node not found!");
    }

    # Generate DOT code
    dot_code = generate_dot_code_from_lists(node_list, edge_list);

    report {
        "success": True,
        "message": f"Added task '{self.task_name}' connected from '{self.previous_task}'",
        "dotCode": dot_code,
        "nodes": node_list,
        "edges": edge_list
    };
}

# WALKER: get_task_graph
impl get_task_graph.navigate_to_graph {
    # Find user-specific graph based on username
    all_graphs = [-->](`?user_graph_data);
    
    user_graph = None;
    for graph in all_graphs {
        if hasattr(graph, 'username') and graph.username == self.username {
            user_graph = graph;
            break;
        }
    }
    
    if user_graph == None {
        # No graph yet, return empty
        report {
            "nodes": [],
            "edges": [],
            "dotCode": "",
            "lastTask": "Start"
        };
        disengage;
    }
    
    visit user_graph;
}

impl get_task_graph.get_graph {
    # Use helper walker to traverse the graph
    # Find the "Start" node to begin traversal
    all_task_nodes = [-->](`?TaskState);
    print(f"[DEBUG GET_GRAPH] Found {len(all_task_nodes)} TaskState nodes connected to user_graph_data");

    start_node = None;
    for node in all_task_nodes {
        if hasattr(node, 'task_name') {
            print(f"[DEBUG GET_GRAPH]   Node: {node.task_name}");
            if node.task_name == "Start" {
                start_node = node;
            }
        }
    }

    node_list = [];
    edge_list = [];

    if start_node != None {
        print(f"[DEBUG GET_GRAPH] Starting traversal from Start node");
        # Spawn walker at the Start node
        traverser = start_node spawn traverse_graph();

        # Get the collected node and edge lists
        node_list = traverser.nodes_list;
        edge_list = traverser.edges_list;
    } else {
        print(f"[DEBUG GET_GRAPH] WARNING: Start node not found!");
    }

    # Generate DOT code
    dot_code = generate_dot_code_from_lists(node_list, edge_list);

    report {
        "nodes": node_list,
        "edges": edge_list,
        "dotCode": dot_code,
        "lastTask": here.last_task
    };
}

# WALKER: clear_graph
impl clear_graph.navigate_to_graph {
    # Find user-specific graph
    print(f"DEBUG CLEAR_GRAPH: Looking for graph for user: {self.username}");
    
    all_graphs = [-->](`?user_graph_data);
    
    user_graph = None;
    for graph in all_graphs {
        if hasattr(graph, 'username') and graph.username == self.username {
            user_graph = graph;
            break;
        }
    }
    
    if user_graph == None {
        report {"success": True, "message": "No graph to clear"};
        disengage;
    }
    
    visit user_graph;
}

impl clear_graph.clear_data {
    # Delete all TaskState nodes connected to this graph
    all_task_nodes = [-->](`?TaskState);

    print(f"[DEBUG CLEAR] Found {len(all_task_nodes)} TaskState nodes to delete");

    for node in all_task_nodes {
        if hasattr(node, 'task_name') {
            print(f"[DEBUG CLEAR] Deleting node: {node.task_name}");
        }
        # Delete the node
        del node;
    }

    # Recreate the Start node
    start_node = TaskState(task_name="Start");
    here ++> start_node;

    # Reset last task
    here.last_task = "Start";

    print(f"[DEBUG CLEAR] Graph cleared for user {self.username}, Start node recreated");

    report {
        "success": True,
        "message": "Graph cleared successfully"
    };
}

# WALKER: save_routine
impl save_routine.navigate_to_graph {
    # Find user-specific graph
    all_graphs = [-->](`?user_graph_data);
    
    user_graph = None;
    for graph in all_graphs {
        if hasattr(graph, 'username') and graph.username == self.username {
            user_graph = graph;
            break;
        }
    }
    
    if user_graph == None {
        report {"error": "No graph to save", "success": False};
        disengage;
    }
    
    visit user_graph;
}

impl save_routine.save_routine_data {
    # Store routine directly in the user_graph_data node

    # Initialize saved_routines dict if needed
    if not hasattr(here, 'saved_routines') or here.saved_routines == None {
        here.saved_routines = {};
    }

    # Get current timestamp
    import from time { time }
    timestamp = str(time());

    # Build node and edge lists by traversing the OSP graph
    node_list = [];
    edge_list = [];

    # Get all TaskState nodes reachable from this graph
    all_nodes = [-->](`?TaskState);

    # First pass: collect all node names
    for node in all_nodes {
        if hasattr(node, 'task_name') {
            node_list.append(node.task_name);
        }
    }

    # Second pass: collect all edges by checking each node's outgoing connections
    for node in all_nodes {
        if not hasattr(node, 'task_name') {
            continue;
        }

        from_task = node.task_name;

        # Get edges from this node
        edges = [edge node->:TaskFlow:->];
        for e in edges {
            # For each edge, check all nodes to find the target
            for target in all_nodes {
                if hasattr(target, 'task_name') {
                    # Check if this could be the target
                    # We'll add all edges we find
                    edge_label = e.label if hasattr(e, 'label') else "";
                    # Only add if we haven't already added this edge
                    edge_exists = False;
                    for existing_edge in edge_list {
                        if existing_edge.get("from") == from_task and existing_edge.get("to") == target.task_name {
                            edge_exists = True;
                            break;
                        }
                    }
                    if not edge_exists {
                        edge_list.append({
                            "from": from_task,
                            "to": target.task_name,
                            "label": edge_label
                        });
                    }
                }
            }
        }
    }

    # Save the routine as dict for compatibility
    here.saved_routines[self.routine_name] = {
        "nodes": node_list.copy(),
        "edges": edge_list.copy(),
        "saved_at": timestamp
    };

    # Count nodes manually
    node_count = 0;
    for _ in node_list {
        node_count = node_count + 1;
    }

    report {
        "success": True,
        "message": f"Saved routine with {node_count} tasks",
        "routine": here.saved_routines[self.routine_name]
    };
}

# WALKER: load_past_routines
impl load_past_routines.navigate_to_routines {
    # Find user-specific routines
    all_routines = [-->](`?user_routines);
    
    user_routines_node = None;
    for r in all_routines {
        if hasattr(r, 'username') and r.username == self.username {
            user_routines_node = r;
            break;
        }
    }
    
    if user_routines_node == None {
        # No routines yet
        report {"routines": {}, "count": 0, "message": "No past routines saved yet"};
        disengage;
    }
    
    visit user_routines_node;
}

impl load_past_routines.load_routines {
    # Count routines manually
    routine_count = 0;
    for _ in here.routines {
        routine_count = routine_count + 1;
    }

    if routine_count == 0 {
        report {"routines": {}, "count": 0, "message": "No past routines saved yet"};
    } else {
        report {
            "routines": here.routines,
            "count": routine_count,
            "message": f"Loaded {routine_count} saved routine(s)"
        };
    }
}

# WALKER: reset_session
impl reset_session.navigate_to_graph {
    # Find user-specific graph
    all_graphs = [-->](`?user_graph_data);
    
    user_graph = None;
    for graph in all_graphs {
        if hasattr(graph, 'username') and graph.username == self.username {
            user_graph = graph;
            break;
        }
    }
    
    if user_graph == None {
        report {
            "success": True,
            "message": "Session already empty."
        };
        disengage;
    }
    
    visit user_graph;
}

impl reset_session.reset_graph {
    # Delete all TaskState nodes
    all_task_nodes = [-->](`?TaskState);
    for node in all_task_nodes {
        del node;
    }

    # Recreate the Start node
    start_node = TaskState(task_name="Start");
    here ++> start_node;

    # Reset last task
    here.last_task = "Start";

    report {
        "success": True,
        "message": "Session reset. Ready for a new conversation."
    };
}

# WALKER: rebuild_graph
impl rebuild_graph.navigate_to_graph {
    # Find user-specific graph
    all_graphs = [-->](`?user_graph_data);
    
    user_graph = None;
    for graph in all_graphs {
        if hasattr(graph, 'username') and graph.username == self.username {
            user_graph = graph;
            break;
        }
    }
    
    if user_graph == None {
        # Create new graph if doesn't exist
        user_graph = here ++> user_graph_data(username=self.username);
    }
    
    visit user_graph;
}

impl rebuild_graph.rebuild {
    # Delete all existing TaskState nodes
    all_task_nodes = [-->](`?TaskState);
    for node in all_task_nodes {
        del node;
    }

    # Create a map to store created nodes
    node_map = {};

    # Create all nodes first
    for node_name in self.new_nodes {
        import from datetime { datetime }
        new_task = TaskState(
            task_name=node_name,
            created_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        );
        node_map[node_name] = new_task;

        # ONLY connect Start node to user_graph_data
        if node_name == "Start" {
            here ++> new_task;
        }
    }

    # Create all edges
    for edge_spec in self.new_edges {
        from_name = edge_spec.get("from", "");
        to_name = edge_spec.get("to", "");
        edge_label = edge_spec.get("label", "");

        if from_name in node_map and to_name in node_map {
            from_node = node_map[from_name];
            to_node = node_map[to_name];

            # Create typed edge with label
            from_node +>:TaskFlow(label=edge_label):+> to_node;
        }
    }

    # Update last task to the last node in the new list
    if self.new_nodes and len(self.new_nodes) > 0 {
        here.last_task = self.new_nodes[-1];
    } else {
        here.last_task = "Start";
    }

    # Generate updated DOT code
    dot_code = generate_dot_code_from_lists(self.new_nodes, self.new_edges);

    report {
        "success": True,
        "message": "Graph rebuilt successfully",
        "dotCode": dot_code,
        "nodes": self.new_nodes,
        "edges": self.new_edges
    };
}

# WALKER: call_supervisor
impl call_supervisor.call {
    try {
        api_key = getenv("OPENAI_API_KEY");
        
        if not api_key {
            report {"error": "OPENAI_API_KEY not set"};
            return;
        }
        
        # Load user's current graph state
        current_nodes = [];
        current_edges = [];
        last_task = "Start";

        # Find user-specific graph data
        all_graphs = [-->](`?user_graph_data);
        user_graph = None;

        for graph in all_graphs {
            if hasattr(graph, 'username') and graph.username == self.username {
                user_graph = graph;
                last_task = graph.last_task if hasattr(graph, 'last_task') else "Start";
                
                # Find Start node (only node directly connected to graph)
                all_task_nodes = [graph-->](`?TaskState);
                start_node = None;
                for node in all_task_nodes {
                    if hasattr(node, 'task_name') and node.task_name == "Start" {
                        start_node = node;
                        break;
                    }
                }
                
                # Traverse the ENTIRE graph to get all nodes and edges
                if start_node != None {
                    traverser = start_node spawn traverse_graph();
                    current_nodes = traverser.nodes_list;
                    current_edges = traverser.edges_list;
                    print(f"[DEBUG CALL_SUPERVISOR] Loaded {len(current_nodes)} nodes and {len(current_edges)} edges");
                } else {
                    # No Start node found, empty graph
                    current_nodes = ["Start"];
                }
                
                break;
            }
        }

        # ============================================
        # NEW SEMANTIC APPROACH (Multi-Step Analysis)
        # ============================================
        
        # Step 1: Detect emotional state
        emotional_state = detect_emotional_state(
            user_message=self.context_from_user,
            conversation_history=self.conversation_history
        );
        
        # Step 2: Analyze conversation intent (commit, correct, clarify, question, think)
        intent_analysis = analyze_conversation_intent(
            user_message=self.context_from_user,
            conversation_history=self.conversation_history,
            existing_nodes=current_nodes,
            last_task=last_task
        );
        
        print(f"[DEBUG] Intent: {intent_analysis.conversation_context.intent}");
        print(f"[DEBUG] Should create tasks: {intent_analysis.should_create_tasks}");
        print(f"[DEBUG] Needs rebuild: {intent_analysis.conversation_context.needs_graph_rebuild}");
        
        # Step 3: Extract task sequence if creating tasks
        relationships = [];
        if intent_analysis.should_create_tasks {
            relationships = extract_task_sequence(
                user_message=self.context_from_user,
                conversation_context=intent_analysis.conversation_context,
                existing_nodes=current_nodes,
                last_task=last_task,
                current_edges=current_edges
            );
            
            print(f"[DEBUG] Parsed {len(relationships)} relationships");
            for rel in relationships {
                print(f"[DEBUG]   [{rel.sequence_order}] {rel.from_task} --[{rel.edge_label}]--> {rel.to_task} ({rel.connection_type})");
            }
            
            # Execute the graph updates
            print(f"[DEBUG CHECK] needs_graph_rebuild={intent_analysis.conversation_context.needs_graph_rebuild}, current_nodes={len(current_nodes)}, current_nodes={current_nodes}");
            if intent_analysis.conversation_context.needs_graph_rebuild and len(current_nodes) > 1 {
                print(f"[DEBUG] Using rebuildGraph (complete graph rebuild)");
                
                # Collect all nodes (existing + new)
                all_nodes = ["Start"];
                added_nodes = {"Start": True};
                
                # Add nodes from new relationships
                for rel in relationships {
                    if rel.from_task not in added_nodes {
                        all_nodes.append(rel.from_task);
                        added_nodes[rel.from_task] = True;
                    }
                    if rel.to_task not in added_nodes {
                        all_nodes.append(rel.to_task);
                        added_nodes[rel.to_task] = True;
                    }
                }
                
                # Add existing nodes that weren't mentioned (preserve them as orphans)
                for node in current_nodes {
                    if node not in added_nodes and node != "Start" {
                        all_nodes.append(node);
                        added_nodes[node] = True;
                        print(f"[DEBUG REBUILD] Preserving unmentioned node: {node}");
                    }
                }
                
                # Create edges ONLY from new relationships (no merging with old edges)
                new_edges = [];
                for rel in relationships {
                    new_edges.append({
                        "from": rel.from_task,
                        "to": rel.to_task,
                        "label": rel.edge_label
                    });
                }
                
                print(f"[DEBUG REBUILD] Complete rebuild: {len(all_nodes)} nodes, {len(new_edges)} edges");
                for edge in new_edges {
                    print(f"[DEBUG REBUILD] Edge: {edge['from']} -> {edge['to']} [{edge['label']}]");
                }
                
                here spawn rebuild_graph(
                    username=self.username,
                    new_nodes=all_nodes,
                    new_edges=new_edges
                );
            } else {
                print(f"[DEBUG] Using updateTaskGraph (normal addition)");
                # Normal updates - execute each relationship in sequence order
                # Manual sort since sorted() with key might not work in Jac
                sorted_rels = [];
                for rel in relationships {
                    inserted = False;
                    for i in range(len(sorted_rels)) {
                        if rel.sequence_order < sorted_rels[i].sequence_order {
                            sorted_rels.insert(i, rel);
                            inserted = True;
                            break;
                        }
                    }
                    if not inserted {
                        sorted_rels.append(rel);
                    }
                }
                
                for rel in sorted_rels {
                    here spawn update_task_graph(
                        task_name=rel.to_task,
                        previous_task=rel.from_task,
                        edge_label=rel.edge_label,
                        username=self.username
                    );
                }
            }
        }
        
        # Step 4: Generate friendly response
        task_names = [];
        for rel in relationships {
            if rel.to_task not in task_names {
                task_names.append(rel.to_task);
            }
        }
        
        response = generate_friendly_response(
            user_message=self.context_from_user,
            emotional_state=emotional_state,
            action_taken="task_added" if intent_analysis.should_create_tasks else "none",
            task_names=task_names
        );
        
        report {"response": response, "emotional_state": emotional_state.state};
    } except Exception as e {
        report {"error": "Supervisor error", "details": str(e)};
    }
}

#===========================================================
#                       HELPER FUNCTIONS
#===========================================================

# Helper function to generate DOT code from node and edge lists
def generate_dot_code_from_lists(node_list: list, edge_list: list) -> str {
    # Check if graph is empty
    if len(node_list) == 0 {
        return "";
    }

    lines = ["digraph TaskGraph {"];
    lines.append("  rankdir=TB;");
    lines.append("  node [shape=box, style=rounded, fontname=\"Arial\"];");
    lines.append("  edge [fontname=\"Arial\", fontsize=10];");
    lines.append("");

    # Add nodes with styling
    for task_node in node_list {
        if task_node == "Start" {
            lines.append("  " + task_node + " [shape=circle, style=filled, fillcolor=\"#22c55e\", fontcolor=white];");
        } else {
            lines.append("  " + task_node + " [style=\"rounded,filled\", fillcolor=\"#3b82f6\", fontcolor=white];");
        }
    }

    lines.append("");

    # Add edges
    for conn in edge_list {
        from_task = conn.get("from", "");
        to_task = conn.get("to", "");
        conn_label = conn.get("label", "");
        if conn_label {
            lines.append("  " + from_task + " -> " + to_task + " [label=\"" + conn_label + "\"];");
        } else {
            lines.append("  " + from_task + " -> " + to_task + ";");
        }
    }

    lines.append("}");
    return "\n".join(lines);
}

# Function to handle non-graph tool execution (calendar, emails, GitHub, etc.)
def execute_local_tool(tool_name: str, tool_args: object) -> dict {
    if tool_name == "getCalendarEvents" {
        # Filter by date if provided
        date_filter = tool_args["date"] if "date" in tool_args else "today";
        # For demo, return all events (in real app, would filter by date)
        return {"events": SAMPLE_CALENDAR_EVENTS, "query": date_filter};
    } elif tool_name == "getEmails" {
        # Filter emails based on parameters
        filter_type = tool_args["filter"] if "filter" in tool_args else "all";
        count = tool_args["count"] if "count" in tool_args else 5;
        emails = SAMPLE_EMAILS[:count];
        if filter_type == "unread" {
            emails = [e for e in SAMPLE_EMAILS if "unread" in e and e["unread"]][:count];
        } elif filter_type == "important" {
            emails = [e for e in SAMPLE_EMAILS if "important" in e and e["important"]][:count];
        }
        return {"emails": emails, "filter": filter_type};
    } elif tool_name == "getGitHubIssues" {
        # Filter GitHub issues
        filter_type = tool_args["filter"] if "filter" in tool_args else "all";
        issue_type = tool_args["type"] if "type" in tool_args else "all";
        issues = SAMPLE_GITHUB_ISSUES;
        if filter_type == "open" {
            issues = [i for i in issues if "state" in i and i["state"] == "open"];
        } elif filter_type == "assigned" {
            issues = [i for i in issues if "assignee" in i and i["assignee"] == "me"];
        }
        return {"issues": issues, "filter": filter_type};
    } else {
        return {"result": True};
    }
}