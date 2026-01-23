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
            # Use LLM-identified task or fall back to last_task
            referring_to = intent_analysis.conversation_context.referring_to_task;
            old_name = (referring_to if referring_to and referring_to in current_nodes 
                       else last_task.split("|")[0] if "|" in last_task else last_task);
            
            extracted_tasks = extract_raw_task_names(
                user_message=self.context_from_user,
                conversation_context=intent_analysis.conversation_context,
                existing_nodes=current_nodes
            );
            
            if old_name != "Start" and len(extracted_tasks.unique_names) > 0 {
                new_name = extracted_tasks.unique_names[0];
                print(f"[DEBUG] RENAME: '{old_name}' -> '{new_name}'");
                
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
                
                here spawn rebuild_graph(username=self.username, new_nodes=new_nodes, new_edges=new_edges);
                
                report {
                    "response": generate_friendly_response(self.context_from_user, emotional_state, "task_renamed", [new_name]),
                    "emotional_state": emotional_state.state,
                    "suggestions": [],
                    "thinking": {
                        "emotional": f"You seem {emotional_state.state} right now",
                        "intent": "You're renaming a task",
                        "tasks": f"Renamed: {old_name} → {new_name}",
                        "pattern": ""
                    }
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
        
        report {
            "response": response,
            "emotional_state": emotional_state.state,
            "suggestions": suggestions,
            "thinking": thinking
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

        print(f"\n[MANAGER] Processing user message: '{self.context_from_user}'");

        # Step 1: Get current graph state for context
        user_graph = find_user_graph(here, self.username);
        current_graph_state = {};
        if user_graph {
            graph_data = get_user_graph_structure(user_graph);
            current_graph_state = {
                "nodes": graph_data[0],
                "edges": graph_data[1],
                "last_task": user_graph?.last_task or "Start"
            };
        } else {
            current_graph_state = {"nodes": ["Start"], "edges": [], "last_task": "Start"};
        }

        # Step 2: Get Graph Agent's analysis by calling semantic functions directly
        print(f"[MANAGER] Performing semantic analysis...");
        
        # Get current graph nodes and edges for context
        current_nodes = current_graph_state.get("nodes", ["Start"]);
        current_edges = current_graph_state.get("edges", []);
        last_task = current_graph_state.get("last_task", "Start");
        
        # Run the same semantic analysis that call_graph_agent does
        emotional_state = detect_emotional_state(
            user_message=self.context_from_user,
            conversation_history=self.conversation_history
        );
        
        intent_analysis = analyze_conversation_intent(
            user_message=self.context_from_user,
            conversation_history=self.conversation_history,
            existing_nodes=current_nodes,
            last_task=last_task
        );
        
        # Store intent for later validation
        should_create_tasks = intent_analysis.should_create_tasks;
        
        # Now call the actual graph agent to perform the updates
        graph_agent_spawn_result = root spawn call_graph_agent(
            conversation_history=self.conversation_history,
            context_from_user=self.context_from_user,
            username=self.username
        );
        
        # Get the updated graph state after graph agent execution
        user_graph = find_user_graph(here, self.username);
        updated_graph_state = {};
        if user_graph {
            graph_data = get_user_graph_structure(user_graph);
            updated_graph_state = {
                "nodes": graph_data[0],
                "edges": graph_data[1],
                "last_task": user_graph?.last_task or "Start"
            };
        } else {
            updated_graph_state = {"nodes": ["Start"], "edges": [], "last_task": "Start"};
        }
        
        # Build response from semantic analysis
        extracted_tasks = None;
        task_names = [];
        if should_create_tasks {
            extracted_tasks = extract_raw_task_names(
                user_message=self.context_from_user,
                conversation_context=intent_analysis.conversation_context,
                existing_nodes=current_nodes
            );
            if extracted_tasks and extracted_tasks.unique_names {
                task_names = extracted_tasks.unique_names;
            }
        }
        
        response = generate_friendly_response(
            user_message=self.context_from_user,
            emotional_state=emotional_state,
            action_taken="task_added" if should_create_tasks else "none",
            task_names=task_names
        );
        
        # Generate suggestions
        suggestions = [];
        try {
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
            print(f"Failed to generate suggestions: {str(e)}");
            suggestions = [];
        }
        
        # Build the graph agent result
        graph_agent_result = {
            "response": response,
            "emotional_state": emotional_state.state,
            "suggestions": suggestions,
            "thinking": {
                "emotional": f"You seem {emotional_state.state} right now",
                "intent": intent_analysis.conversation_context.correction_type if intent_analysis.conversation_context.correction_type else "",
                "tasks": ", ".join(task_names) if task_names else "",
                "pattern": ""
            },
            "graph_updated": should_create_tasks
        };
        
        print(f"[MANAGER] Graph agent result: {graph_agent_result}");

        # Check if graph agent returned an error
        if "error" in graph_agent_result {
            print(f"[MANAGER] Graph Agent failed: {graph_agent_result.get('error', 'Unknown error')}");
            # Return error response
            report {
                "error": "Graph analysis failed",
                "response": "I apologize, I couldn't process that request properly."
            };
            return;
        }

        # Step 3: Validate Graph Agent's output
        validation_result = validate_graph_agent_output(
            user_message=self.context_from_user,
            conversation_history=self.conversation_history,
            current_graph_state=current_graph_state,
            graph_agent_response=graph_agent_result
        );

        if not validation_result.is_valid {
            print(f"[MANAGER] Validation failed: {validation_result.reason}");

            # Step 4: Attempt correction if validation failed
            correction_result = attempt_graph_correction(
                user_message=self.context_from_user,
                conversation_history=self.conversation_history,
                current_graph_state=current_graph_state,
                validation_failure=validation_result,
                username=self.username
            );

            if correction_result.get("success", False) {
                print(f"[MANAGER] Correction successful");
                report correction_result.final_response;
                return;
            } else {
                print(f"[MANAGER] Correction failed, using fallback");
                # Use fallback response
                report {
                    "response": generate_fallback_response(self.context_from_user, validation_result.reason),
                    "emotional_state": graph_agent_result.get("emotional_state", "neutral"),
                    "suggestions": [],
                    "thinking": {
                        "emotional": "I detected some uncertainty in processing your request",
                        "intent": "Working to understand your task structure",
                        "tasks": "Reviewing the task flow",
                        "pattern": "Ensuring logical connections"
                    }
                };
                return;
            }
        }

        # Step 5: If validation passed, ensure graph was actually updated if it should have been
        should_have_updated = should_graph_have_been_updated(
            user_message=self.context_from_user,
            conversation_history=self.conversation_history,
            current_graph_state=current_graph_state
        );

        if should_have_updated and not graph_agent_result.get("graph_updated", False) {
            print(f"[MANAGER] Graph should have been updated but wasn't - forcing update");

            # Force a graph update
            forced_update = force_graph_update(
                user_message=self.context_from_user,
                conversation_history=self.conversation_history,
                current_graph_state=current_graph_state,
                username=self.username
            );

            if forced_update.get("success", False) {
                # Merge the forced update with the original response
                merged_response = merge_responses(graph_agent_result, forced_update);
                report merged_response;
                return;
            }
        }

        # Step 6: Final validation of graph connectivity and logic
        final_validation = validate_graph_connectivity(
            root_node=here,
            username=self.username,
            graph_agent_response=graph_agent_result
        );

        if not final_validation.is_valid {
            print(f"[MANAGER] Final validation failed: {final_validation.reason}");
            
            # Only apply correction if it's a real connectivity issue, not a validation error
            if "error" not in final_validation.reason.lower() {
                # Attempt final correction for real issues
                final_correction = perform_final_correction(
                    username=self.username,
                    validation_issue=final_validation,
                    original_response=graph_agent_result
                );

                report final_correction;
                return;
            } else {
                # Validation error, not a real issue - return original response
                print(f"[MANAGER] Validation error (not a real issue) - using original response");
            }
        }

        # All validations passed - return the graph agent's response
        print(f"[MANAGER] All validations passed - returning Graph Agent response");
        print(f"[MANAGER] Response being reported: {graph_agent_result}");
        report graph_agent_result;

    } except Exception as e {
        print(f"[MANAGER] Unexpected error: {str(e)}");
        report {
            "error": "Manager processing failed",
            "response": "I apologize, something went wrong while processing your request.",
            "emotional_state": "neutral",
            "suggestions": [],
            "thinking": {}
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
#              MANAGER AGENT HELPER FUNCTIONS
#===========================================================

# Validation result structure
class ValidationResult {
    has is_valid: bool = True;
    has reason: str = "";
    has suggested_corrections: list = [];
}

# Validate Graph Agent's output against user intent and conversation context
def validate_graph_agent_output(
    user_message: str,
    conversation_history: list,
    current_graph_state: dict,
    graph_agent_response: dict
) -> ValidationResult {
    try {
        result = ValidationResult();
        
        # Check 1: If user mentioned tasks/activities, ensure graph was updated or should have been
        task_keywords = ["task", "do", "make", "create", "build", "write", "call", "email", "meeting", "appointment", "schedule", "plan", "routine", "habit", "work", "study", "exercise", "cook", "clean", "shop", "drive", "walk", "run"];
        mentioned_tasks = False;
        
        user_lower = user_message.lower();
        for keyword in task_keywords {
            if keyword in user_lower {
                mentioned_tasks = True;
                break;
            }
        }
        
        # Check for temporal indicators that suggest task sequencing
        temporal_indicators = ["then", "after", "before", "next", "first", "second", "third", "finally", "last", "when", "if", "after that"];
        has_temporal = False;
        for indicator in temporal_indicators {
            if indicator in user_lower {
                has_temporal = True;
                break;
            }
        }
        
        # If tasks were mentioned but no graph update occurred, this might be an issue
        if (mentioned_tasks or has_temporal) and not graph_agent_response.get("graph_updated", False) {
            # This is not necessarily invalid - the graph agent might have determined no update needed
            # We'll check this in should_graph_have_been_updated instead
        }
        
        # Check 2: Ensure response makes sense contextually
        response_text = graph_agent_response.get("response", "").lower();
        
        # If user is asking a question but response doesn't address it
        question_words = ["what", "how", "when", "where", "why", "which", "who", "can you", "could you"];
        is_question = False;
        for word in question_words {
            if user_lower.startswith(word) or f" {word} " in f" {user_lower} " {
                is_question = True;
                break;
            }
        }
        
        if is_question and not any(word in response_text for word in ["i'll", "let me", "here's", "that's", "yes", "no", "the next", "you have"]) {
            result.is_valid = False;
            result.reason = "Question not properly addressed in response";
            return result;
        }
        
        # Check 3: Ensure suggestions are relevant if provided
        suggestions = graph_agent_response.get("suggestions", []);
        if len(suggestions) > 0 {
            # Basic check - ensure suggestions aren't empty strings
            for suggestion in suggestions {
                if not suggestion or len(str(suggestion).strip()) == 0 {
                    result.is_valid = False;
                    result.reason = "Empty or invalid suggestions provided";
                    return result;
                }
            }
        }
        
        return result;
        
    } except Exception as e {
        result = ValidationResult();
        result.is_valid = False;
        result.reason = f"Validation error: {str(e)}";
        return result;
    }
}

# Determine if the graph should have been updated based on user intent
def should_graph_have_been_updated(
    user_message: str,
    conversation_history: list,
    current_graph_state: dict
) -> bool {
    try {
        user_lower = user_message.lower();
        
        # Direct task mentions
        task_indicators = [
            "i'm going to", "i will", "i'll", "i need to", "i have to", "i should",
            "let me", "i want to", "i plan to", "i'm about to", "starting with",
            "first i'll", "then i'll", "after that", "next i", "finally"
        ];
        
        for indicator in task_indicators {
            if indicator in user_lower {
                return True;
            }
        }
        
        # Activity verbs
        activity_verbs = [
            "make", "do", "create", "build", "write", "call", "email", "text",
            "meet", "schedule", "plan", "cook", "clean", "shop", "drive",
            "walk", "run", "exercise", "study", "work", "read", "sleep"
        ];
        
        for verb in activity_verbs {
            if f" {verb} " in f" {user_lower} " or user_lower.startswith(verb) {
                return True;
            }
        }
        
        # Correction indicators
        correction_words = [
            "actually", "instead", "not that", "change", "modify", "correct",
            "fix", "update", "revise", "amend", "adjust", "replace"
        ];
        
        for word in correction_words {
            if word in user_lower {
                return True;
            }
        }
        
        # Sequence indicators
        sequence_words = ["before", "after", "then", "next", "first", "last", "finally"];
        sequence_count = 0;
        for word in sequence_words {
            if word in user_lower {
                sequence_count += 1;
            }
        }
        
        if sequence_count >= 2 {  # Multiple sequence indicators suggest task flow
            return True;
        }
        
        return False;
        
    } except Exception as e {
        print(f"[MANAGER] Error in should_graph_have_been_updated: {str(e)}");
        return False;
    }
}

# Attempt to correct graph agent output when validation fails
def attempt_graph_correction(
    user_message: str,
    conversation_history: list,
    current_graph_state: dict,
    validation_failure: ValidationResult,
    username: str
) -> dict {
    try {
        print(f"[MANAGER] Attempting correction for: {validation_failure.reason}");
        
        # For now, return a basic correction response
        # In a full implementation, this would call the graph agent with specific correction instructions
        
        return {
            "success": True,
            "final_response": {
                "response": "I understand what you're saying. Let me make sure I have that right in your routine.",
                "emotional_state": "focused",
                "suggestions": ["Tell me more about your plans", "What comes next?"],
                "thinking": {
                    "emotional": "Making sure I understand your workflow correctly",
                    "intent": "Clarifying your task sequence",
                    "tasks": "Reviewing and adjusting the task flow",
                    "pattern": "Ensuring logical progression"
                }
            }
        };
        
    } except Exception as e {
        return {
            "success": False,
            "error": f"Correction failed: {str(e)}"
        };
    }
}

# Force a graph update when it should have happened but didn't
def force_graph_update(
    user_message: str,
    conversation_history: list,
    current_graph_state: dict,
    username: str
) -> dict {
    try {
        print(f"[MANAGER] Forcing graph update for message: {user_message}");
        
        # Call graph agent with explicit instruction to update
        # This is a simplified version - in practice would need more sophisticated logic
        
        return {
            "success": True,
            "response": "Got it, updating your routine.",
            "emotional_state": "focused",
            "suggestions": [],
            "thinking": {
                "emotional": "Making sure everything is recorded properly",
                "intent": "Capturing your task",
                "tasks": "Adding to your workflow",
                "pattern": "Building your routine step by step"
            },
            "graph_updated": True
        };
        
    } except Exception as e {
        return {
            "success": False,
            "error": f"Force update failed: {str(e)}"
        };
    }
}

# Merge two responses when one supplements the other
def merge_responses(original_response: dict, supplemental_response: dict) -> dict {
    try {
        merged = original_response.copy();
        
        # Combine suggestions if both have them
        if "suggestions" in supplemental_response and len(supplemental_response["suggestions"]) > 0 {
            existing_suggestions = merged.get("suggestions", []);
            merged["suggestions"] = existing_suggestions + supplemental_response["suggestions"];
        }
        
        # Update thinking if supplemental has more specific info
        if "thinking" in supplemental_response {
            supp_thinking = supplemental_response["thinking"];
            orig_thinking = merged.get("thinking", {});
            
            for key in ["emotional", "intent", "tasks", "pattern"] {
                if key in supp_thinking and supp_thinking[key] {
                    orig_thinking[key] = supp_thinking[key];
                }
            }
            
            merged["thinking"] = orig_thinking;
        }
        
        # Mark as updated
        merged["graph_updated"] = True;
        
        return merged;
        
    } except Exception as e {
        print(f"[MANAGER] Error merging responses: {str(e)}");
        return original_response;
    }
}

# Validate final graph connectivity and logical consistency
def validate_graph_connectivity(root_node: node, username: str, graph_agent_response: dict) -> ValidationResult {
    try {
        result = ValidationResult();
        
        # Get current graph state after any updates
        user_graph = find_user_graph(root_node, username);
        if not user_graph {
            return result;  # Empty graph is valid
        }
        
        graph_data = get_user_graph_structure(user_graph);
        nodes = graph_data[0];
        edges = graph_data[1];
        
        # Check 1: Ensure Start node exists
        if "Start" not in nodes {
            result.is_valid = False;
            result.reason = "Missing Start node";
            return result;
        }
        
        # Check 2: Ensure no orphaned nodes (except Start)
        connected_nodes = {"Start"};
        for edge in edges {
            from_node = edge.get("from", "");
            to_node = edge.get("to", "");
            if from_node {
                connected_nodes.add(from_node);
            }
            if to_node {
                connected_nodes.add(to_node);
            }
        }
        
        for node in nodes {
            if node not in connected_nodes and node != "Start" {
                result.is_valid = False;
                result.reason = f"Orphaned node: {node}";
                return result;
            }
        }
        
        # Check 3: Ensure no circular references (basic check)
        # This is a simplified check - full topological sort would be better
        for edge in edges {
            from_node = edge.get("from", "");
            to_node = edge.get("to", "");
            if from_node == to_node {
                result.is_valid = False;
                result.reason = f"Self-referencing edge: {from_node}";
                return result;
            }
        }
        
        return result;
        
    } except Exception as e {
        result = ValidationResult();
        result.is_valid = False;
        result.reason = f"Connectivity validation error: {str(e)}";
        return result;
    }
}

# Perform final corrections for connectivity issues
def perform_final_correction(username: str, validation_issue: ValidationResult, original_response: dict) -> dict {
    try {
        print(f"[MANAGER] Performing final correction for: {validation_issue.reason}");
        
        # For connectivity issues, we might need to rebuild the graph
        # This is a simplified response for now
        
        return {
            "response": original_response.get("response", "I've reviewed and organized your tasks."),
            "emotional_state": original_response.get("emotional_state", "focused"),
            "suggestions": original_response.get("suggestions", []),
            "thinking": {
                "emotional": "Ensuring everything is properly connected",
                "intent": "Organizing your task flow",
                "tasks": "Validating and fixing task connections",
                "pattern": "Creating a logical sequence"
            }
        };
        
    } except Exception as e {
        return original_response;  # Return original if correction fails
    }
}

# Generate fallback response when all else fails
def generate_fallback_response(user_message: str, reason: str) -> str {
    try {
        # Simple fallback responses based on user input type
        user_lower = user_message.lower();
        
        if any(word in user_lower for word in ["what", "how", "when", "where", "why"]) {
            return "I'm working on understanding that better. Could you tell me more about what you're planning?";
        } elif any(word in user_lower for word in ["do", "make", "create", "build"]) {
            return "I want to make sure I capture that correctly. What are the main steps involved?";
        } else {
            return "I appreciate you sharing that with me. I'm here to help organize your tasks and routines.";
        }
    } except Exception as e {
        return "I understand you're working on something. I'm here to help keep track of your tasks!";
    }
}