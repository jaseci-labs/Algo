import from datetime { datetime }
import from time { time }

impl get_session_token.fetch{
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
        error_msg = e.read().decode('utf-8') if e?.read else str(e);
        report {"error": f"HTTP Error: {e.code}", "details": error_msg} ;
    } except URLError as e {
        report {"error": "URL Error", "details": str(e.reason)} ;
    } except Exception as e {
        report {"error": "Server error", "details": str(e)} ;
    }
}

# WALKER: init_user_graph
impl init_user_graph.initialize{
    visit [-->](`?user_graph_data) else {
        (here ++> user_graph_data()) ++> TaskState(task_name="Start");
    }
    visit [-->](`?manager_comm_data) else {
        here ++> manager_comm_data();
    }
    visit [-->](`?user_routines) else { here ++> user_routines(); }
}

# WALKER: update_task_graph
impl update_task_graph.navigate_to_graph{
    user_graph = find_user_graph(here, self.username);
    if not user_graph {
        user_graph = here ++> user_graph_data(username=self.username);
    }
    visit user_graph;
}

impl update_task_graph.update_graph {
    # Find the most recent node with the previous task name
    prev_node = None;
    
    # Search ALL TaskState nodes in the graph
    all_task_nodes = [-->](`?TaskState);
    nodes_to_check = all_task_nodes.copy();
    all_nodes = [];
    
    # Collect all nodes via traversal
    visited_ids = {};
    while len(nodes_to_check) > 0 {
        current = nodes_to_check.pop(0);
        if hasattr(current, 'task_name') {
            # Use object id to track unique nodes (not task_name)
            node_id = id(current);
            if node_id not in visited_ids {
                visited_ids[node_id] = True;
                all_nodes.append(current);
                # Get successors via TaskFlow edges
                successors = [current-->](`?TaskState);
                for succ in successors {
                    nodes_to_check.append(succ);
                }
            }
        }
    }
    
    # Now find the MOST RECENT node with the previous task name
    most_recent_time = None;
    for node in all_nodes {
        if node.task_name == self.previous_task {
            # Get the created_at timestamp
            if hasattr(node, 'created_at') and node.created_at {
                if most_recent_time == None or node.created_at > most_recent_time {
                    most_recent_time = node.created_at;
                    prev_node = node;
                }
            } else {
                # No timestamp (e.g., Start node) - use it if no other found
                if prev_node == None {
                    prev_node = node;
                }
            }
        }
    }
    # If previous task doesn't exist, create it (shouldn't happen normally, but safe fallback)
    if prev_node == None {
        prev_node = TaskState(task_name=self.previous_task);
        if self.previous_task == "Start" {
            here ++> prev_node;
        }
    }

    # Always create a new task node (even if task name was used before)
    new_node = TaskState(
        task_name=self.task_name,
        created_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    );
    
    # CRITICAL: Attach new node to user_graph_data for bounded traversal
    here ++> new_node;

    # Create edge and update last task
    prev_node +>: TaskFlow(label=self.edge_label) :+> new_node;
    here.last_task = self.task_name;
    
    # Get graph structure
    graph_data = get_graph_structure(here);
    report {
        "success": True,
        "message": f"Added task '{self.task_name}' connected from '{self.previous_task}'",
        "dotCode": graph_data[2],
        "nodes": graph_data[0],
        "edges": graph_data[1]
    } ;
}

# WALKER: get_task_graph
impl get_task_graph.navigate_to_graph{
    user_graph = find_user_graph(here, self.username);
    if not user_graph {
        report {"nodes": [], "edges": [], "dotCode": "", "lastTask": "Start"} ;
        disengage;
    }
    visit user_graph;
}

impl get_task_graph.get_graph{
    # Use bounded traversal to prevent cross-user contamination
    result = get_user_graph_structure(here);
    node_list = result[0];
    edge_list = result[1];
    dot_code = generate_dot_code_from_lists(node_list, edge_list);
    
    leaf_nodes = find_leaf_nodes(edge_list, node_list);
    last_task_to_report = (leaf_nodes[0] if len(leaf_nodes) == 1 
                           else "|".join(leaf_nodes) if leaf_nodes 
                           else here.last_task);
    
    report {
        "nodes": node_list,
        "edges": edge_list,
        "dotCode": dot_code,
        "lastTask": last_task_to_report
    } ;
}

# WALKER: clear_graph
impl clear_graph.navigate_to_graph{
    user_graph = find_user_graph(here, self.username);
    if not user_graph {
        report {"success": True, "message": "No graph to clear"} ;
        disengage;
    }
    visit user_graph;
}

impl clear_graph.clear_data{
    for node in [-->](`?TaskState) { del node; }
    here ++> TaskState(task_name="Start");
    here.last_task = "Start";
    report {"success": True, "message": "Graph cleared successfully"} ;
}

# WALKER: save_routine
impl save_routine.navigate_to_graph{
    user_graph = find_user_graph(here, self.username);
    if not user_graph {
        report {"error": "No graph to save", "success": False} ;
        disengage;
    }
    visit user_graph;
}

impl save_routine.save_routine_data{
    if not here?.saved_routines { here.saved_routines = {}; }
    
    timestamp = str(time());
    graph_data = get_graph_structure(here);
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
    } ;
}

# WALKER: load_past_routines
impl load_past_routines.navigate_to_routines{
    # Find user-specific routines
    all_routines = [-->](`?user_routines);
    user_routines_node = None;
    for r in all_routines {
        if r?.username and r.username == self.username {
            user_routines_node = r;
            break;
        }
    }
    if user_routines_node == None {
        # No routines yet
        report {"routines": {}, "count": 0, "message": "No past routines saved yet"} ;
        disengage;
    }
    visit user_routines_node;
}

impl load_past_routines.load_routines{
    # Count routines manually
    routine_count = 0;
    for _ in here.routines {
        routine_count = routine_count + 1;
    }
    if routine_count == 0 {
        report {"routines": {}, "count": 0, "message": "No past routines saved yet"} ;
    } else {
        report {
            "routines": here.routines,
            "count": routine_count,
            "message": f"Loaded {routine_count} saved routine(s)"
        } ;
    }
}

# WALKER: reset_session
impl reset_session.navigate_to_graph{
    user_graph = find_user_graph(here, self.username);
    if not user_graph {
        report {"success": True, "message": "Session already empty."} ;
        disengage;
    }
    visit user_graph;
}

impl reset_session.reset_graph{
    for node in [-->](`?TaskState) { del node; }
    here ++> TaskState(task_name="Start");
    here.last_task = "Start";
    report {"success": True, "message": "Session reset. Ready for a new conversation."} ;
}

# WALKER: rebuild_graph
impl rebuild_graph.navigate_to_graph{
    user_graph = find_user_graph(here, self.username);
    if not user_graph {
        user_graph = here ++> user_graph_data(username=self.username);
    }
    visit user_graph;
}

impl rebuild_graph.rebuild{
    # Delete all existing TaskState nodes
    all_task_nodes = [-->](`?TaskState);
    for node in all_task_nodes {
        del node ;
    }
    # Create a map to store created nodes
    node_map = {};
    # Create all nodes first
    for node_name in self.new_nodes {
        new_task = TaskState(
            task_name=node_name,
            created_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        );
        node_map[node_name] = new_task;

        # CRITICAL: Attach ALL nodes to user_graph_data for bounded traversal
        here ++> new_task;
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
            from_node +>: TaskFlow(label=edge_label) :+> to_node;
        }
    }
    # Update last task to the last node in the new list
    if self.new_nodes and len(self.new_nodes) > 0 {
        here.last_task = self.new_nodes[-1];
    } else {
        here.last_task = "Start";
    }
    # Generate DOT code with custom styling
    dot_code = generate_dot_code_from_lists(self.new_nodes, self.new_edges);
    report {
        "success": True,
        "message": "Graph rebuilt successfully",
        "dotCode": dot_code,
        "nodes": self.new_nodes,
        "edges": self.new_edges
    } ;
}

# WALKER: rename_task
impl rename_task.navigate_to_graph{
    user_graph = find_user_graph(here, self.username);
    if not user_graph {
        report {"success": False, "error": "No graph found to rename tasks in"} ;
        disengage;
    }
    visit user_graph;
}

impl rename_task.rename{
    all_task_nodes = [-->](`?TaskState);
    target_node = None;
    
    for node in all_task_nodes {
        if node?.task_name and node.task_name == self.old_name {
            target_node = node;
            break;
        }
    }
    
    if not target_node {
        report {"success": False, "error": f"Task '{self.old_name}' not found in graph"} ;
        return;
    }
    
    target_node.task_name = self.new_name;
    if here.last_task == self.old_name { here.last_task = self.new_name; }
    
    graph_data = get_graph_structure(here);
    
    report {
        "success": True,
        "message": f"Renamed '{self.old_name}' to '{self.new_name}'",
        "dotCode": graph_data[2],
        "nodes": graph_data[0],
        "edges": graph_data[1]
    } ;
}

# WALKER: call_graph_agent
impl call_graph_agent.call{
    try {
        api_key = getenv("OPENAI_API_KEY");
        if not api_key {
            report {"error": "OPENAI_API_KEY not set"} ;
            return;
        }

        # Load current graph state
        current_nodes = [];
        current_edges = [];
        last_task = "Start";
        
        user_graph = find_user_graph(here, self.username);
        if not user_graph {
            user_graph = here ++> user_graph_data(username=self.username);
            user_graph ++> TaskState(task_name="Start");
        }
        
        if user_graph {
            last_task = user_graph?.last_task or "Start";
            start_node = find_start_node(user_graph);

            if start_node {
                # Use bounded traversal to avoid crossing user boundaries
                graph_data = get_user_graph_structure(user_graph);
                current_nodes = graph_data[0];
                current_edges = graph_data[1];
                
                # Find leaf nodes for convergence detection
                leaf_nodes = find_leaf_nodes(current_edges, current_nodes);
                if len(leaf_nodes) > 1 {
                    last_task = "|".join(leaf_nodes);
                } elif len(leaf_nodes) == 1 {
                    last_task = leaf_nodes[0];
                } else {
                    # No Start node found, empty graph
                    current_nodes = ["Start"];
                }
            } else {
                # No Start node found, initialize
                current_nodes = ["Start"];
            }
        } else {
            current_nodes = ["Start"];
        }

        # Capture graph state BEFORE operation (for validation)
        before_nodes = current_nodes.copy();
        before_edges = current_edges.copy();

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

        # Step 2.5: Handle RENAME operations
        if intent_analysis.conversation_context.correction_type == "rename" {
            print(f"\n[RENAME] ===== RENAME OPERATION STARTED =====");
            print(f"[RENAME] User message: '{self.context_from_user}'");
            print(f"[RENAME] Current nodes: {current_nodes}");

            # Get referring_to_task from LLM
            referring_to = intent_analysis.conversation_context.referring_to_task;
            print(f"[RENAME] LLM identified referring_to_task: '{referring_to}'");

            # Find old_name (exact match or fallback)
            old_name = None;
            if referring_to and referring_to in current_nodes {
                old_name = referring_to;
                print(f"[RENAME] Exact match found: '{old_name}'");
            } else {
                # Try case-insensitive match
                for node in current_nodes {
                    if referring_to and node.lower() == referring_to.lower() {
                        old_name = node;
                        print(f"[RENAME] Case-insensitive match found: '{old_name}'");
                        break;
                    }
                }
                # Fallback to last_task
                if not old_name {
                    old_name = last_task.split("|")[0] if "|" in last_task else last_task;
                    print(f"[RENAME] No match found, using last_task fallback: '{old_name}'");
                }
            }

            # Extract new task name
            print(f"[RENAME] Calling extract_raw_task_names with correction_type='rename'...");
            extracted_tasks = extract_raw_task_names(
                user_message=self.context_from_user,
                conversation_context=intent_analysis.conversation_context,
                existing_nodes=current_nodes
            );

            print(f"[RENAME] extract_raw_task_names result:");
            print(f"[RENAME]   renamed_to: '{extracted_tasks.renamed_to}'");
            print(f"[RENAME]   raw_names: {extracted_tasks.raw_names}");
            print(f"[RENAME]   unique_names: {extracted_tasks.unique_names}");

            # Use the dedicated renamed_to field
            new_name = extracted_tasks.renamed_to;

            if old_name != "Start" and new_name {
                print(f"[RENAME] Final: '{old_name}' -> '{new_name}'");

                if old_name == new_name {
                    print(f"[RENAME] ERROR: Old and new names are the same! Rename will do nothing.");
                }

                # Rebuild graph with renamed node
                new_nodes = [new_name if n == old_name else n for n in current_nodes];
                new_edges = [
                    {
                        "from": new_name if e.get("from") == old_name else e.get("from"),
                        "to": new_name if e.get("to") == old_name else e.get("to"),
                        "label": e.get("label", "")
                    }
                    for e in current_edges
                ];

                print(f"[RENAME] Nodes changed from {current_nodes} to {new_nodes}");
                print(f"[RENAME] Calling rebuild_graph...");

                here spawn rebuild_graph(username=self.username, new_nodes=new_nodes, new_edges=new_edges);

                # Capture AFTER state for validation
                after_nodes = new_nodes;
                after_edges = new_edges;

                # Convert intent_analysis object to dict for passing
                intent_dict = {
                    "conversation_context": {
                        "intent": str(intent_analysis.conversation_context.intent),
                        "referring_to_task": intent_analysis.conversation_context.referring_to_task,
                        "correction_type": intent_analysis.conversation_context.correction_type,
                        "needs_graph_rebuild": intent_analysis.conversation_context.needs_graph_rebuild,
                        "is_insertion": intent_analysis.conversation_context.is_insertion,
                        "tasks_to_move": intent_analysis.conversation_context.tasks_to_move
                    },
                    "should_create_tasks": intent_analysis.should_create_tasks,
                    "confidence": intent_analysis.confidence
                };

                # Call Manager to validate the rename operation (passing context directly)
                root spawn validate_graph_output(
                    context_from_user=self.context_from_user,
                    username=self.username,
                    intent_analysis=intent_dict,
                    extracted_tasks=[new_name],
                    before_nodes=before_nodes,
                    before_edges=before_edges,
                    after_nodes=after_nodes,
                    after_edges=after_edges
                );

                # Generate response
                response = generate_friendly_response(self.context_from_user, emotional_state, "task_renamed", [new_name]);

                # Store response in manager_comm_data for frontend
                manager_data = find_manager_comm_data(here, self.username);
                if not manager_data {
                    manager_data = here ++> manager_comm_data(username=self.username);
                }
                manager_data.last_response = response;
                manager_data.last_suggestions = [];
                manager_data.last_thinking = {
                    "emotional": f"You seem {emotional_state.state} right now",
                    "intent": "You're renaming a task",
                    "tasks": f"Renamed: {old_name} → {new_name}",
                    "pattern": ""
                };
                manager_data.last_task_names = [new_name];
                manager_data.last_emotional_state = emotional_state.state;

                report {
                    "response": response,
                    "emotional_state": emotional_state.state,
                    "suggestions": [],
                    "thinking": manager_data.last_thinking,
                    "task_names": [new_name],
                    "validation_passed": True
                };
                return;
            }
        }

        # Step 3: Extract task sequence if creating tasks
        relationships = [];
        extracted_tasks = None;
        attachment_analysis = None;
        convergence_intent = None;
        edge_to_split = None;
        
        if intent_analysis.should_create_tasks {
            extracted_tasks = extract_raw_task_names(
                user_message=self.context_from_user,
                conversation_context=intent_analysis.conversation_context,
                existing_nodes=current_nodes
            );
            
            # Handle insertion corrections: adjust attachment point
            correction_type = intent_analysis.conversation_context.correction_type;
            referring_to = intent_analysis.conversation_context.referring_to_task;
            
            if correction_type in ["insert_before", "insert_after", "insert_first"] {
                print(f"[DEBUG] Insertion: {correction_type}, referring_to={referring_to}");
                
                if correction_type == "insert_before" and referring_to {
                    # Find predecessor of referring_to task
                    for edge in current_edges {
                        if edge.get("to") == referring_to {
                            last_task = edge.get("from");
                            edge_to_split = edge;
                            print(f"[DEBUG] Insert before {referring_to}: attach from {last_task}");
                            break;
                        }
                    }
                } elif correction_type == "insert_after" and referring_to {
                    last_task = referring_to;
                    edge_to_split = next((e for e in current_edges if e.get("from") == referring_to), None);
                    print(f"[DEBUG] Insert after {referring_to}");
                } elif correction_type == "insert_first" {
                    last_task = "Start";
                    print(f"[DEBUG] Insert first");
                }
            }
            
            attachment_analysis = determine_attachment_points(
                user_message=self.context_from_user,
                last_task=last_task,
                existing_nodes=current_nodes,
                conversation_context=intent_analysis.conversation_context
            );
            
            # 3.3: Determine where tasks should attach (now with corrected last_task)
            attachment_analysis = determine_attachment_points(
                user_message=self.context_from_user,
                last_task=last_task,
                existing_nodes=current_nodes,
                conversation_context=intent_analysis.conversation_context
            );
            
            # 3.4: Detect convergence intent
            convergence_intent = detect_convergence_intent(
                user_message=self.context_from_user,
                last_task=last_task,
                current_edges=current_edges
            );
            
            # 3.5: Build relationships using all analyzed data
            relationships = build_task_relationships(
                user_message=self.context_from_user,
                extracted_tasks=extracted_tasks,
                attachment_analysis=attachment_analysis,
                convergence_intent=convergence_intent,
                conversation_context=intent_analysis.conversation_context,
                current_edges=current_edges
            );
            
            # Log what LLM returned
            print(f"\n[DEBUG call_supervisor] LLM returned {len(relationships)} relationships:");
            for rel in relationships {
                print(f"  - from_task='{rel.from_task}' to_task='{rel.to_task}' label='{rel.edge_label}' order={rel.sequence_order}");
            }
            
            # Execute the graph updates
            if intent_analysis.conversation_context.needs_graph_rebuild
            and len(current_nodes) > 1 {
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
                # Add existing nodes that weren't mentioned (preserve them)
                for node in current_nodes {
                    if node not in added_nodes and node != "Start" {
                        all_nodes.append(node);
                        added_nodes[node] = True;
                    }
                }
                
                # Build edge map - strategy depends on whether tasks are being moved
                edge_map = {};
                tasks_to_move = intent_analysis.conversation_context.tasks_to_move if hasattr(intent_analysis.conversation_context, 'tasks_to_move') else [];
                
                if len(tasks_to_move) > 0 {
                    # REORDERING MODE: Remove ALL edges involving moved tasks
                    print(f"\n[DEBUG] Reordering mode: tasks_to_move = {tasks_to_move}");
                    
                    # Start with existing edges, but exclude any involving moved tasks
                    for edge in current_edges {
                        from_task = edge.get("from", "");
                        to_task = edge.get("to", "");
                        
                        # Skip edges that involve any of the tasks being moved
                        involves_moved_task = False;
                        for moved_task in tasks_to_move {
                            if from_task == moved_task or to_task == moved_task {
                                involves_moved_task = True;
                                print(f"[DEBUG] Removing old edge: {from_task} -> {to_task} (involves {moved_task})");
                                break;
                            }
                        }
                        
                        if not involves_moved_task {
                            edge_key = f"{from_task}->{to_task}";
                            edge_map[edge_key] = edge;
                        }
                    }
                } else {
                    # NORMAL MODE: Start with all existing edges
                    for edge in current_edges {
                        from_task = edge.get("from", "");
                        to_task = edge.get("to", "");
                        edge_key = f"{from_task}->{to_task}";
                        edge_map[edge_key] = edge;
                    }
                    
                    # INSERTION MODE: Remove the edge being split
                    if edge_to_split {
                        split_key = f"{edge_to_split.get('from', '')}->{edge_to_split.get('to', '')}";
                        if split_key in edge_map {
                            print(f"[DEBUG] Removing edge for insertion: {split_key}");
                            del edge_map[split_key];
                        }
                    }
                    
                    # Detect edges that should be removed (task insertion cases)
                    # If we're adding A->B->C, we should remove A->C if it exists
                    edges_to_remove = {};
                    for rel in relationships {
                        # Check if this relationship represents an insertion
                        # Look for pattern: if we have A->B and B->C, remove A->C
                        for other_rel in relationships {
                            if rel.to_task == other_rel.from_task {
                                # Found chain: rel.from_task -> rel.to_task -> other_rel.to_task
                                # Remove direct edge from rel.from_task -> other_rel.to_task if it exists
                                direct_edge_key = f"{rel.from_task}->{other_rel.to_task}";
                                if direct_edge_key in edge_map {
                                    edges_to_remove[direct_edge_key] = True;
                                }
                            }
                        }
                    }
                    
                    # Remove the identified edges
                    for edge_key in edges_to_remove {
                        if edge_key in edge_map {
                            del edge_map[edge_key];
                        }
                    }
                }
                # Add/override with new relationships
                for rel in relationships {
                    edge_key = f"{rel.from_task}->{rel.to_task}";
                    edge_map[edge_key] = {
                        "from": rel.from_task,
                        "to": rel.to_task,
                        "label": rel.edge_label
                    };
                }
                # Convert edge map back to list
                new_edges = [];
                for edge_key in edge_map {
                    new_edges.append(edge_map[edge_key]);
                }
                here spawn rebuild_graph(
                    username=self.username, new_nodes=all_nodes, new_edges=new_edges
                );
            } else {
                # Normal updates - execute each relationship in sequence order
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
        
        # Step 4: Generate thinking summary for transparency
        thinking_summary = generate_thinking_summary(
            user_message=self.context_from_user,
            emotional_state=emotional_state,
            intent_analysis=intent_analysis,
            extracted_tasks=extracted_tasks,
            attachment_analysis=attachment_analysis,
            convergence_intent=convergence_intent
        );
        
        # Step 5: Generate friendly response
        task_names = [];
        for rel in relationships {
            if rel.to_task not in task_names {
                task_names.append(rel.to_task);
            }
        }

        response = generate_friendly_response(
            user_message=self.context_from_user,
            emotional_state=emotional_state,
            action_taken="task_added"
            if intent_analysis.should_create_tasks
            else "none",
            task_names=task_names
        );
        
        # Step 6: Generate suggestions for next actions
        suggestions = [];
        try {
            # Get recent tasks (last 3 tasks from current_nodes, excluding Start)
            recent_tasks = [];
            task_count = 0;
            for i in range(len(current_nodes) - 1, -1, -1) {
                if current_nodes[i] != "Start" and task_count < 3 {
                    recent_tasks.insert(0, current_nodes[i]);
                    task_count = task_count + 1;
                }
            }

            suggestions = generate_next_suggestions(
                last_task=last_task,
                recent_tasks=recent_tasks,
                conversation_context=self.context_from_user,
                emotional_state=emotional_state.state
            );
        } except Exception as e {
            # If suggestions fail, just continue without them
            print(f"Failed to generate suggestions: {str(e)}");
            suggestions = [];
        }

        # Build thinking insights for frontend (convert to dict)
        thinking = {
            "emotional": thinking_summary.emotional_insight if thinking_summary.emotional_insight else "",
            "intent": thinking_summary.intent_insight if thinking_summary.intent_insight else "",
            "tasks": thinking_summary.task_insight if thinking_summary.task_insight else "",
            "pattern": thinking_summary.pattern_insight if thinking_summary.pattern_insight else ""
        };

        # Capture graph state AFTER operation (for validation)
        user_graph_after = find_user_graph(here, self.username);
        after_nodes = [];
        after_edges = [];
        if user_graph_after {
            graph_data = get_user_graph_structure(user_graph_after);
            after_nodes = graph_data[0];
            after_edges = graph_data[1];
        }

        # Store response data in manager_comm_data for frontend
        manager_data = find_manager_comm_data(here, self.username);
        if not manager_data {
            manager_data = here ++> manager_comm_data(username=self.username);
        }
        manager_data.last_response = response;
        manager_data.last_suggestions = suggestions;
        manager_data.last_thinking = thinking;
        manager_data.last_task_names = task_names;
        manager_data.last_emotional_state = emotional_state.state;

        # Convert intent_analysis object to dict for passing
        intent_dict = {
            "conversation_context": {
                "intent": str(intent_analysis.conversation_context.intent),
                "referring_to_task": intent_analysis.conversation_context.referring_to_task,
                "correction_type": intent_analysis.conversation_context.correction_type,
                "needs_graph_rebuild": intent_analysis.conversation_context.needs_graph_rebuild,
                "is_insertion": intent_analysis.conversation_context.is_insertion,
                "tasks_to_move": intent_analysis.conversation_context.tasks_to_move
            },
            "should_create_tasks": intent_analysis.should_create_tasks,
            "confidence": intent_analysis.confidence
        };

        # Call Manager to validate the Graph Agent's output (passing context directly)
        print(f"\n[GRAPH AGENT] Calling Manager for validation...");
        root spawn validate_graph_output(
            context_from_user=self.context_from_user,
            username=self.username,
            intent_analysis=intent_dict,
            extracted_tasks=task_names,
            before_nodes=before_nodes,
            before_edges=before_edges,
            after_nodes=after_nodes,
            after_edges=after_edges
        );

        # Read validation result from manager_comm_data (stored by validate_graph_output)
        manager_data = find_manager_comm_data(here, self.username);
        validation_failed = False;
        validation_reason = "";
        validation_type = "";
        missing_tasks = [];

        if manager_data and not manager_data.validation_passed {
            print(f"[GRAPH AGENT] Validation FAILED: {manager_data.validation_reason}");
            validation_failed = True;
            validation_reason = manager_data.validation_reason;
            validation_type = manager_data.validation_type or "";
            missing_tasks = manager_data.missing_tasks or [];
        }

        if validation_failed {
            print(f"[GRAPH AGENT] Validation type: {validation_type}");

            # Handle task rename (when existing task has wrong/incomplete name)
            if validation_type == "task_rename" {
                incorrect_task = manager_data.incorrect_task or "";
                correct_task_name = manager_data.correct_task_name or "";

                if incorrect_task and correct_task_name {
                    print(f"[GRAPH AGENT] Correcting by renaming task: '{incorrect_task}' -> '{correct_task_name}'");

                    # Perform the rename using the rename_task walker
                    here spawn rename_task(
                        old_name=incorrect_task,
                        new_name=correct_task_name,
                        username=self.username
                    );

                    # Update task_names to reflect the renamed task
                    for i in range(len(task_names)) {
                        if task_names[i] == incorrect_task {
                            task_names[i] = correct_task_name;
                        }
                    }

                    # Update response to acknowledge the correction
                    response = f"{response} I've renamed '{incorrect_task}' to '{correct_task_name}'.";

                    print(f"[GRAPH AGENT] Rename correction complete - reporting updated response");
                    report {
                        "response": response,
                        "emotional_state": emotional_state.state,
                        "suggestions": suggestions,
                        "thinking": thinking,
                        "task_names": task_names,
                        "validation_passed": True,
                        "corrected": True,
                        "renamed_task": {"from": incorrect_task, "to": correct_task_name}
                    };
                    return;
                }
            }

            # Handle task extraction failures
            if validation_type == "task_extraction" and len(missing_tasks) > 0 {
                print(f"[GRAPH AGENT] Correcting by adding missing tasks: {missing_tasks}");

                # Get the current graph state to find the last task
                user_graph = find_user_graph(here, self.username);
                last_task = "Start";
                if user_graph {
                    last_task = user_graph?.last_task or "Start";
                }

                # Add each missing task to the graph
                for missing_task in missing_tasks {
                    print(f"[GRAPH AGENT] Adding missing task: {missing_task}");
                    here spawn update_task_graph(
                        task_name=missing_task,
                        previous_task=last_task,
                        edge_label="then",
                        username=self.username
                    );
                    last_task = missing_task;
                }

                # Update task_names to include the newly added tasks
                task_names.extend(missing_tasks);

                # Update response to acknowledge the correction
                response = f"{response} I've also added: {', '.join(missing_tasks)}.";

                print(f"[GRAPH AGENT] Correction complete - reporting updated response");
                report {
                    "response": response,
                    "emotional_state": emotional_state.state,
                    "suggestions": suggestions,
                    "thinking": thinking,
                    "task_names": task_names,
                    "validation_passed": True,
                    "corrected": True,
                    "added_tasks": missing_tasks
                };
                return;
            }

            # Handle edge label failures
            elif validation_type == "edge_labels" {
                print(f"[GRAPH AGENT] Edge label validation failed: {validation_reason}");
                # For now, report as-is with validation info
                # TODO: Implement edge label correction logic
                report {
                    "response": response,
                    "emotional_state": emotional_state.state,
                    "suggestions": suggestions,
                    "thinking": thinking,
                    "task_names": task_names,
                    "validation_passed": False,
                    "validation_reason": validation_reason
                };
                return;
            }

            # Handle rename operation failures
            elif validation_type == "rename_operation" {
                print(f"[GRAPH AGENT] Rename validation failed: {validation_reason}");
                # For now, report as-is with validation info
                # TODO: Implement rename correction logic
                report {
                    "response": response,
                    "emotional_state": emotional_state.state,
                    "suggestions": suggestions,
                    "thinking": thinking,
                    "task_names": task_names,
                    "validation_passed": False,
                    "validation_reason": validation_reason
                };
                return;
            }

            # Handle insert operation failures
            elif validation_type == "insert_operation" {
                print(f"[GRAPH AGENT] Insert validation failed: {validation_reason}");
                # For now, report as-is with validation info
                # TODO: Implement insert position correction logic
                report {
                    "response": response,
                    "emotional_state": emotional_state.state,
                    "suggestions": suggestions,
                    "thinking": thinking,
                    "task_names": task_names,
                    "validation_passed": False,
                    "validation_reason": validation_reason
                };
                return;
            }

            # Handle reorder operation failures
            elif validation_type == "reorder_operation" {
                print(f"[GRAPH AGENT] Reorder validation failed: {validation_reason}");
                # For now, report as-is with validation info
                # TODO: Implement reorder correction logic
                report {
                    "response": response,
                    "emotional_state": emotional_state.state,
                    "suggestions": suggestions,
                    "thinking": thinking,
                    "task_names": task_names,
                    "validation_passed": False,
                    "validation_reason": validation_reason
                };
                return;
            }

            # Handle graph structure failures
            elif validation_type == "graph_structure" {
                print(f"[GRAPH AGENT] Graph structure validation failed: {validation_reason}");
                # For now, report as-is with validation info
                # TODO: Implement graph structure correction logic
                report {
                    "response": response,
                    "emotional_state": emotional_state.state,
                    "suggestions": suggestions,
                    "thinking": thinking,
                    "task_names": task_names,
                    "validation_passed": False,
                    "validation_reason": validation_reason
                };
                return;
            }

            # Unknown validation failure - report as-is
            print(f"[GRAPH AGENT] Unknown validation failure - reporting as-is");
            report {
                "response": response,
                "emotional_state": emotional_state.state,
                "suggestions": suggestions,
                "thinking": thinking,
                "task_names": task_names,
                "validation_passed": False,
                "validation_reason": validation_reason
            };
            return;
        }

        print(f"[GRAPH AGENT] Validation PASSED - reporting response to user");
        report {
            "response": response,
            "emotional_state": emotional_state.state,
            "suggestions": suggestions,
            "thinking": thinking,
            "task_names": task_names,
            "validation_passed": True
        };
    } except Exception as e {
        report {"error": "Supervisor error", "details": str(e)} ;
    }
}

# WALKER: call_manager
impl call_manager.orchestrate{
    try {
        api_key = getenv("OPENAI_API_KEY");
        if not api_key {
            report {"error": "OPENAI_API_KEY not set"} ;
            return;
        }

        print(f"\n[MANAGER ORCHESTRATE] Processing user message: '{self.context_from_user}'");

        # Spawn the Graph Agent (it handles its own validation via validate_graph_output)
        print(f"[MANAGER ORCHESTRATE] Spawning Graph Agent...");
        root spawn call_graph_agent(
            conversation_history=self.conversation_history,
            context_from_user=self.context_from_user,
            username=self.username
        );

        # Read the result from manager_comm_data (stored by call_graph_agent)
        manager_data = find_manager_comm_data(here, self.username);
        if manager_data and manager_data.last_response {
            graph_agent_result = {
                "response": manager_data.last_response,
                "emotional_state": manager_data.last_emotional_state or "neutral",
                "suggestions": manager_data.last_suggestions or [],
                "thinking": manager_data.last_thinking or {},
                "task_names": manager_data.last_task_names or []
            };
            print(f"[MANAGER ORCHESTRATE] Returning Graph Agent response to user");
            report graph_agent_result;
        } else {
            print(f"[MANAGER ORCHESTRATE] No response from Graph Agent");
            report {
                "error": "No response from graph agent",
                "response": "I apologize, something went wrong."
            };
        }

    } except Exception as e {
        print(f"[MANAGER ORCHESTRATE] Error: {str(e)}");
        report {
            "error": "Manager processing failed",
            "response": "I apologize, something went wrong while processing your request."
        };
    }
}

#===========================================================
#                       HELPER FUNCTIONS
#===========================================================

# Simple parser to extract TaskState nodes and TaskFlow edges from printgraph() output
def parse_printgraph_output(
    dot_output: str
) -> tuple {
    node_list = [];
    edge_list = [];
    node_map = {};  # id -> task_name

    if not dot_output {
        return (node_list, edge_list);
    }

    # Replace HTML entities with actual characters
    dot_output = dot_output.replace("&#x27;", "'");
    dot_output = dot_output.replace("&quot;", '"');

    lines = dot_output.split("\n");

    # FIRST PASS: Parse all node definitions
    for line in lines {
        line = line.strip();

        # Parse node: 0 [label="TaskState(task_name='Start', ...)"]
        if "[label=" in line and "->" not in line {
            parts = line.split("[label=");
            if len(parts) == 2 {
                node_id = parts[0].strip();
                label = parts[1];
                # Only process TaskState nodes
                if "TaskState(task_name=" in label {
                    # Extract task name: TaskState(task_name='Start', ...)
                    start = label.find("task_name=") + 11;  # after task_name='
                    end = label.find("'", start + 1);
                    if end > start {
                        task_name = label[start:end];
                        node_map[node_id] = task_name;
                        node_list.append(task_name);
                    }
                }
            }
        }
    }

    # SECOND PASS: Parse edges (now that we have all nodes)
    for line in lines {
        line = line.strip();

        # Parse edge: 0 -> 2  [label="TaskFlow(label='then')"]
        if "->" in line and not line.startswith("//") {
            parts = line.split("->");
            if len(parts) == 2 {
                from_id = parts[0].strip();
                to_part = parts[1].strip();
                # Extract to_id (handle spaces before [)
                to_id = "";
                if "[" in to_part {
                    to_id = to_part.split("[")[0].strip();
                } else {
                    to_id = to_part.strip().rstrip(";");
                }
                # Extract edge label from TaskFlow
                edge_label = "";
                if "TaskFlow(label=" in to_part {
                    # Find the label value inside TaskFlow
                    label_idx = to_part.find("TaskFlow(label=");
                    if label_idx >= 0 {
                        rest = to_part[label_idx + 15:];  # after "TaskFlow(label="
                        # Skip opening quote and find closing quote
                        if len(rest) > 1 and rest[0] == "'" {
                            quote_end = rest.find("'", 1);  # Find closing quote after position 1
                            if quote_end > 1 {
                                edge_label = rest[1:quote_end];  # Extract between quotes
                            }
                        }
                    }
                }
                # Only add edges between TaskState nodes
                if from_id in node_map and to_id in node_map {
                    edge_list.append(
                        {
                            "from": node_map[from_id],
                            "to": node_map[to_id],
                            "label": edge_label
                        }
                    );
                }
            }
        }
    }

    return (node_list, edge_list);
}

def generate_dot_code_from_lists(node_list: list, edge_list: list) -> str {
    # Generate custom styled DOT code from node and edge lists.
    # Used for applying custom styling not available in printgraph().
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
            lines.append(
                "  " + task_node + " [shape=circle, style=filled, fillcolor=\"#22c55e\", fontcolor=white];"
            );
        } else {
            lines.append(
                "  " + task_node + " [style=\"rounded,filled\", fillcolor=\"#3b82f6\", fontcolor=white];"
            );
        }
    }

    lines.append("");

    # Add edges
    for conn in edge_list {
        from_task = conn.get("from", "");
        to_task = conn.get("to", "");
        conn_label = conn.get("label", "");
        if conn_label {
            lines.append(
                "  " + from_task + " -> " + to_task + " [label=\"" + conn_label + "\"];"
            );
        } else {
            lines.append("  " + from_task + " -> " + to_task + ";");
        }
    }

    lines.append("}");
    return "\n".join(lines);
}

# Helper function to find all leaf nodes (nodes with no outgoing edges)
def find_leaf_nodes(
    edge_list: list, node_list: list
) -> list {
    # Find all nodes that have outgoing edges
    nodes_with_outgoing = {};
    for edge in edge_list {
        from_task = edge.get("from", "");
        if from_task {
            nodes_with_outgoing[from_task] = True;
        }
    }

    # Leaf nodes are those without outgoing edges (excluding Start)
    leaf_nodes = [];
    for node in node_list {
        if node != "Start" and node not in nodes_with_outgoing {
            leaf_nodes.append(node);
        }
    }

    # If no leaf nodes found, return the last node (shouldn't happen in practice)
    if len(leaf_nodes) == 0 and len(node_list) > 1 {
        return [node_list[-1]];
    }

    return leaf_nodes;
}


"""Find user's graph or return None"""
def find_user_graph(root_node: node, username: str) {
    all_graphs = [root_node-->](`?user_graph_data);
    for graph in all_graphs {
        graph_username = graph?.username if graph else None;
        if graph?.username and graph.username == username {
            return graph;
        }
    }
    return None;
}

"""Find manager comm data node or return None"""
def find_manager_comm_data(root_node: node, username: str) {
    all_comm_data = [root_node-->](`?manager_comm_data);
    for comm_data in all_comm_data {
        if comm_data?.username and comm_data.username == username {
            return comm_data;
        }
    }
    return None;
}

"""Find Start node in graph - only direct children of user_graph"""
def find_start_node(graph_node: node) {
    # Only get TaskState nodes directly connected to this graph (one hop)
    direct_task_nodes = [graph_node-->](`?TaskState);
    for node in direct_task_nodes {
        if node?.task_name and node.task_name == "Start" {
            return node;
        }
    }
    return None;
}

"""Get graph structure as node/edge lists and DOT code"""
def get_graph_structure(graph_node: node) {
    start_node = find_start_node(graph_node);
    node_list = [];
    edge_list = [];
    if start_node {
        dot_output = printgraph(node=start_node);
        result = parse_printgraph_output(dot_output);
        node_list = result[0];
        edge_list = result[1];
    }
    dot_code = generate_dot_code_from_lists(node_list, edge_list);
    return (node_list, edge_list, dot_code);
}

"""Get user-specific graph structure with bounded traversal"""
def get_user_graph_structure(user_graph_node: node) {
    node_list = [];
    edge_list = [];
    
    # Get only TaskState nodes directly connected to this user_graph (bounded)
    direct_nodes = [user_graph_node-->](`?TaskState);
    
    # Build node map for efficient lookup
    node_map = {};
    for node in direct_nodes {
        if node?.task_name {
            node_map[id(node)] = node.task_name;
            node_list.append(node.task_name);
        }
    }
    
    # Build edges only between nodes belonging to this user
    for from_node in direct_nodes {
        if from_node?.task_name {
            successors = [from_node-->](`?TaskState);
            
            for to_node in successors {
                # Only include edge if both nodes belong to this user's graph
                if id(to_node) in node_map {
                    # Extract edge label using printgraph
                    edge_label = extract_edge_label_via_printgraph(from_node, to_node);
                    
                    edge_list.append({
                        "from": from_node.task_name,
                        "to": to_node.task_name,
                        "label": edge_label
                    });
                }
            }
        }
    }
    
    return (node_list, edge_list);
}

# Extract edge label between two nodes using printgraph
def extract_edge_label_via_printgraph(from_node: node, to_node: node) -> str {
    try {
        dot_output = printgraph(node=from_node, depth=1);
        if not dot_output {
            return "";
        }
        
        # Replace HTML entities
        dot_output = dot_output.replace("&#x27;", "'");
        dot_output = dot_output.replace("&quot;", '"');
        lines = dot_output.split("\n");
        
        to_task_name = to_node.task_name if hasattr(to_node, 'task_name') else None;
        if not to_task_name {
            return "";
        }
        
        # FIRST PASS: Build node ID -> task_name map
        node_map = {};
        for line in lines {
            line = line.strip();
            if "[label=" in line and "->" not in line {
                parts = line.split("[label=");
                if len(parts) == 2 {
                    node_id = parts[0].strip();
                    label = parts[1];
                    if "TaskState(task_name=" in label {
                        start = label.find("task_name=") + 11;
                        end = label.find("'", start + 1);
                        if end > start {
                            node_map[node_id] = label[start:end];
                        }
                    }
                }
            }
        }
        
        # Find target node ID
        target_node_id = None;
        for node_id in node_map {
            if node_map[node_id] == to_task_name {
                target_node_id = node_id;
                break;
            }
        }
        
        if not target_node_id {
            return "";
        }
        
        # SECOND PASS: Find edge to target and extract TaskFlow label
        for line in lines {
            line = line.strip();
            if "->" in line and not line.startswith("//") {
                parts = line.split("->");
                if len(parts) == 2 {
                    to_part = parts[1].strip();
                    to_id = to_part.split("[")[0].strip() if "[" in to_part else to_part.strip().rstrip(";");
                    
                    if to_id == target_node_id and "TaskFlow(label=" in to_part {
                        label_idx = to_part.find("TaskFlow(label=");
                        rest = to_part[label_idx + 15:];
                        if len(rest) > 1 and rest[0] == "'" {
                            quote_end = rest.find("'", 1);
                            if quote_end > 1 {
                                return rest[1:quote_end];
                            }
                        }
                    }
                }
            }
        }
    } except Exception as e {
        # Silently fail and return empty label
        return "";
    }
    
    return "";
}

#===========================================================
#              MANAGER VALIDATION ABILITY
#===========================================================

# The validate ability is called by the Graph Agent to validate its output.
# It performs validation checks and stores results in manager_comm_data.
# The Manager NEVER sends responses to the user - only validates for Graph Agent.
impl validate_graph_output.validate {
    print(f"\n[MANAGER VALIDATE] Starting validation for user: {self.username}");

    # Find or create manager_comm_data to store validation results
    manager_data = find_manager_comm_data(here, self.username);
    if not manager_data {
        manager_data = here ++> manager_comm_data(username=self.username);
    }

    # Use passed parameters directly
    intent_analysis = self.intent_analysis or {};
    extracted_tasks = self.extracted_tasks or [];
    before_nodes = self.before_nodes or [];
    before_edges = self.before_edges or [];
    after_nodes = self.after_nodes or [];
    after_edges = self.after_edges or [];
    user_message = self.context_from_user;

    # Derive operation type from intent_analysis
    conversation_context = intent_analysis.get("conversation_context", {});
    correction_type = conversation_context.get("correction_type", "");
    referring_to_task = conversation_context.get("referring_to_task", "");
    tasks_to_move = conversation_context.get("tasks_to_move", []);

    print(f"[MANAGER VALIDATE] Operation type: '{correction_type}'");

    # Reset validation state
    manager_data.validation_passed = True;
    manager_data.validation_reason = "";
    manager_data.validation_type = "";
    manager_data.correction_needed = False;
    manager_data.missing_tasks = [];
    manager_data.incorrect_task = "";
    manager_data.correct_task_name = "";

    # Route to appropriate validation based on operation type
    if correction_type == "rename" {
        print(f"[MANAGER VALIDATE] Validating RENAME operation...");
        print(f"[MANAGER VALIDATE] before_nodes: {before_nodes}");
        print(f"[MANAGER VALIDATE] after_nodes: {after_nodes}");

        # Find which task was renamed (task in before but not in after)
        old_task = None;
        new_task = None;

        for node in before_nodes {
            if node not in after_nodes and node != "Start" {
                old_task = node;
                break;
            }
        }

        for node in after_nodes {
            if node not in before_nodes {
                new_task = node;
                break;
            }
        }

        print(f"[MANAGER VALIDATE] Detected old_task: {old_task}, new_task: {new_task}");

        # If no clear rename detected, skip validation
        if not old_task or not new_task {
            print(f"[MANAGER VALIDATE] Could not detect rename from before/after nodes, skipping validation");
            print(f"[MANAGER VALIDATE] This means the graph didn't actually change (old == new)");
            return;
        }

        print(f"[MANAGER VALIDATE] Rename: '{old_task}' -> '{new_task}'");

        rename_validation = validate_rename_operation(
            user_message=user_message,
            old_task=old_task,
            new_task=new_task,
            before_nodes=before_nodes,
            after_nodes=after_nodes,
            before_edges=before_edges,
            after_edges=after_edges
        );

        if not rename_validation.is_valid {
            print(f"[MANAGER VALIDATE] Rename validation FAILED: {rename_validation.reason}");
            manager_data.validation_passed = False;
            manager_data.validation_reason = rename_validation.reason;
            manager_data.validation_type = "rename_operation";
        }
    }
    elif correction_type in ["insert_before", "insert_after", "insert_first"] {
        print(f"[MANAGER VALIDATE] Validating INSERT operation: {correction_type}");

        insert_validation = validate_insert_operation(
            user_message=user_message,
            operation_type=correction_type,
            referring_to_task=referring_to_task,
            new_tasks=extracted_tasks,
            before_edges=before_edges,
            after_edges=after_edges
        );

        if not insert_validation.is_valid {
            print(f"[MANAGER VALIDATE] Insert validation FAILED: {insert_validation.reason}");
            manager_data.validation_passed = False;
            manager_data.validation_reason = insert_validation.reason;
            manager_data.validation_type = "insert_operation";
        }
    }
    elif correction_type == "reorder" or len(tasks_to_move) > 0 {
        print(f"[MANAGER VALIDATE] Validating REORDER operation");

        reorder_tasks = tasks_to_move if len(tasks_to_move) > 0 else extracted_tasks;

        reorder_validation = validate_reorder_operation(
            user_message=user_message,
            tasks_to_move=reorder_tasks,
            before_edges=before_edges,
            after_edges=after_edges
        );

        if not reorder_validation.is_valid {
            print(f"[MANAGER VALIDATE] Reorder validation FAILED: {reorder_validation.reason}");
            manager_data.validation_passed = False;
            manager_data.validation_reason = reorder_validation.reason;
            manager_data.validation_type = "reorder_operation";
        }
    }
    else {
        # Default validation: task extraction and graph structure
        print(f"[MANAGER VALIDATE] Using default validation (task extraction + graph structure)");

        # Check intent - if asking question or thinking aloud, no tasks expected
        conversation_context = intent_analysis.get("conversation_context", {});
        intent_str = str(conversation_context.get("intent", "")) if conversation_context.get("intent") else "";

        if "ASK_QUESTION" in intent_str or "THINK_ALOUD" in intent_str {
            print(f"[MANAGER VALIDATE] User intent is {intent_str} - no tasks expected, skipping validation");
            # No validation needed - user is asking questions or thinking, not committing to actions
            return;
        }

        # Validation 1: Task Extraction (pass before_nodes for rename detection)
        task_validation = validate_task_extraction(
            user_message=user_message,
            extracted_tasks=extracted_tasks,
            existing_nodes=before_nodes
        );

        if not task_validation.is_valid {
            print(f"[MANAGER VALIDATE] Task extraction FAILED: {task_validation.reason}");

            # Check if this is a rename case (incorrect_task is set)
            if task_validation.incorrect_task and len(task_validation.incorrect_task) > 0 {
                print(f"[MANAGER VALIDATE] Rename needed: '{task_validation.incorrect_task}' -> '{task_validation.correct_task_name}'");
                manager_data.validation_passed = False;
                manager_data.validation_reason = task_validation.reason;
                manager_data.validation_type = "task_rename";
                manager_data.incorrect_task = task_validation.incorrect_task;
                manager_data.correct_task_name = task_validation.correct_task_name;
                manager_data.correction_needed = True;
                return;
            }

            # Standard missing tasks case
            manager_data.validation_passed = False;
            manager_data.validation_reason = task_validation.reason;
            manager_data.correction_needed = True;
            manager_data.missing_tasks = task_validation.missing_tasks;
            manager_data.validation_type = "task_extraction";
            return;
        }

        # Validation 2: Edge Label Validation
        if len(after_edges) > 0 {
            edge_label_validation = validate_edge_labels(
                user_message=user_message,
                new_edges=after_edges
            );

            if not edge_label_validation.is_valid {
                print(f"[MANAGER VALIDATE] Edge label validation FAILED: {edge_label_validation.reason}");
                manager_data.validation_passed = False;
                manager_data.validation_reason = edge_label_validation.reason;
                manager_data.validation_type = "edge_labels";
                return;
            }
        }

        # Validation 3: Graph Structure Validation
        new_task_edges = [];
        for edge in after_edges {
            if edge.get("to", "") in extracted_tasks {
                new_task_edges.append(edge);
            }
        }

        graph_validation = validate_graph_structure(
            user_message=user_message,
            graph_nodes=extracted_tasks,
            graph_edges=new_task_edges
        );

        if not graph_validation.is_valid {
            print(f"[MANAGER VALIDATE] Graph structure validation FAILED: {graph_validation.reason}");
            manager_data.validation_passed = False;
            manager_data.validation_reason = graph_validation.reason;
            manager_data.validation_type = "graph_structure";
        }
    }

    print(f"[MANAGER VALIDATE] All validations PASSED");
}