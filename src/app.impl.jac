# WALKER: get_session_token 
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

# WALKER: traverse_graph
impl traverse_graph.traverse_node {
    # Get this node's name
    node_name = here.task_name;

    # Debug logging
    print(f"[TRAVERSE] Visiting node: {node_name}");

    # Skip if already visited
    if node_name in self.visited {
        print(f"[TRAVERSE] Already visited {node_name}, skipping");
        disengage;
    }

    self.visited[node_name] = True;
    self.nodes_list.append(node_name);

    # Get all TaskFlow edges from this node
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

            # Add this edge to our list
            self.edges_list.append({
                "from": node_name,
                "to": next_node.task_name,
                "label": edge_label
            });
            print(f"[TRAVERSE]   Added edge: {node_name} --[{edge_label}]--> {next_node.task_name}");

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
    all_task_nodes = [-->](`?TaskState);

    for node in all_task_nodes {
        if hasattr(node, 'task_name') and node.task_name == self.previous_task {
            prev_node = node;
            break;
        }
    }

    # If previous task doesn't exist, create it (shouldn't happen normally, but safe fallback)
    if prev_node == None {
        print(f"[DEBUG CREATE] Creating prev_node: {self.previous_task}");
        prev_node = TaskState(task_name=self.previous_task);
        # Connect ALL nodes to user_graph_data to anchor them in the graph
        # The TaskFlow edges will represent the actual workflow relationships
        here ++> prev_node;
        print(f"[DEBUG CREATE] Connected {self.previous_task} to user_graph_data");
    }

    # Find or create the new task node
    new_node = None;
    for node in all_task_nodes {
        if hasattr(node, 'task_name') and node.task_name == self.task_name {
            new_node = node;
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
        # Connect to user_graph_data to anchor it in the graph
        # The TaskFlow edge will be created below to show the workflow
        here ++> new_node;
        print(f"[DEBUG CREATE] Connected {self.task_name} to user_graph_data");
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

        # Connect first node (Start) to user_graph_data
        if node_name == self.new_nodes[0] {
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
        
        # Load user's past routines for context
        past_routines_context = "";
        # Note: Skipping routines for now due to walker spawn issues
        # TODO: Fix walker result handling

        # Load user's current graph state by traversing the OSP graph
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
                break;
            }
        }

        # Traverse OSP graph to build node and edge lists
        # Note: Can't use "from" syntax here, so we'll need to traverse differently
        # For now, we'll temporarily use an empty graph until we can fix the traversal logic
        # TODO: Implement proper graph traversal in walkers that can access OSP syntax

        # Build the request body for OpenAI Responses API
        request_body = {
            "model": "gpt-4.1",
            "input": [
                {
                    "type": "message",
                    "role": "system",
                    "content": SUPERVISOR_INSTRUCTIONS
                },
                {
                    "type": "message",
                    "role": "user",
                    "content": f"""==== Conversation History ====
                    {dumps(self.conversation_history, indent=2)}

                    ==== Relevant Context From Last User Message ====
                    {self.context_from_user}

                    ==== Current Task Graph ====
                    Existing Nodes: {dumps(current_nodes)}
                    Existing Edges: {dumps(current_edges)}
                    Last Task (most recent): {last_task}
                    {past_routines_context}

                    IMPORTANT: 
                    - When adding a new task, check the Existing Nodes list first
                    - If a similar task already exists (e.g., "GoToMall" exists), use that EXACT name, don't create "GoMall"
                    - Use the Last Task as previousTask when connecting sequential activities
                    - Only create a new node if the task doesn't already exist in the Existing Nodes
                    """
                }
            ],
            "tools": SUPERVISOR_TOOLS,
            "parallel_tool_calls": False
        };
        
        # Make initial API call
        data = make_responses_api_call(request_body, api_key);
        output_items = data["output"] if "output" in data else [];
        
        # Process tool calls iteratively (up to 5 rounds)
        max_iterations = 5;
        iteration = 0;
        
        while iteration < max_iterations {
            # Check for function calls
            function_calls = [];
            for item in output_items {
                item_type = item["type"] if "type" in item else "";
                if item_type == "function_call" {
                    function_calls = function_calls + [item];
                }
            }

            # Count function calls
            fc_count = 0;
            for _ in function_calls {
                fc_count = fc_count + 1;
            }

            if fc_count == 0 {
                # No more function calls - extract final response
                break;
            }
            
            # Execute function calls
            for tool_call in function_calls {
                f_name = tool_call["name"] if "name" in tool_call else "";
                f_args_str = tool_call["arguments"] if "arguments" in tool_call else "{}";
                f_args = loads(f_args_str);

                # Execute the tool - use per-user walker for updateTaskGraph and rebuildGraph
                tool_output = {};
                if f_name == "updateTaskGraph" {
                    # Use per-user walker to update the graph
                    task_name = f_args["taskName"] if "taskName" in f_args else "";
                    previous_task = f_args["previousTask"] if "previousTask" in f_args else "Start";
                    edge_label = f_args["edgeLabel"] if "edgeLabel" in f_args else "";

                    # Spawn walker - pass username for isolation
                    here spawn update_task_graph(
                        task_name=task_name,
                        previous_task=previous_task,
                        edge_label=edge_label,
                        username=self.username
                    );
                    # Return success - the walker handles the actual update
                    tool_output = {
                        "success": True,
                        "message": f"Updated graph with task: {task_name}"
                    };
                } elif f_name == "rebuildGraph" {
                    # Use rebuild walker to completely reconstruct the graph
                    new_nodes = f_args["nodes"] if "nodes" in f_args else ["Start"];
                    new_edges = f_args["edges"] if "edges" in f_args else [];

                    # Spawn rebuild walker - pass username for isolation
                    here spawn rebuild_graph(
                        username=self.username,
                        new_nodes=new_nodes,
                        new_edges=new_edges
                    );
                    # Return success - the walker handles the actual rebuild
                    tool_output = {
                        "success": True,
                        "message": f"Rebuilt graph with {len(new_nodes)} nodes"
                    };
                } else {
                    # Use existing function for other tools
                    tool_output = execute_local_tool(f_name, f_args);
                }

                # Add function call and result to the request body
                call_id = tool_call["call_id"] if "call_id" in tool_call else "";
                request_body["input"] = request_body["input"] + [{
                    "type": "function_call",
                    "call_id": call_id,
                    "name": f_name,
                    "arguments": f_args_str
                }];
                request_body["input"] = request_body["input"] + [{
                    "type": "function_call_output",
                    "call_id": call_id,
                    "output": dumps(tool_output)
                }];
            }
            
            # Make follow-up request
            data = make_responses_api_call(request_body, api_key);
            output_items = data["output"] if "output" in data else [];
            iteration = iteration + 1;
        }
        
        # Extract final text
        final_response = extract_response_text(output_items);

        # TODO: Get updated graph state - fix walker spawn result handling
        # For now, return empty graph data since updates happen in update_task_graph walker
        report {
            "response": final_response,
            "dotCode": "",
            "graphNodes": [],
            "graphEdges": []
        };
        
    } except HTTPError as e {
        error_msg = e.read().decode('utf-8') if hasattr(e, 'read') else str(e);
        report {"error": f"HTTP Error: {e.code}", "details": error_msg};
    } except URLError as e {
        report {"error": "URL Error", "details": str(e.reason)};
    } except Exception as e {
        report {"error": "Server error", "details": str(e)};
    }
}