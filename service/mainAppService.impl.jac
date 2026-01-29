import from datetime { datetime }
import from time { time }

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
    prev_node = None;
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

    most_recent_time = None;
    for node in all_nodes {
        if node.task_name == self.previous_task {
            if hasattr(node, 'created_at') and node.created_at {
                if most_recent_time == None or node.created_at > most_recent_time {
                    most_recent_time = node.created_at;
                    prev_node = node;
                }
            } else {
                if prev_node == None {
                    prev_node = node;
                }
            }
        }
    }

    if prev_node == None {
        prev_node = TaskState(task_name=self.previous_task);
        if self.previous_task == "Start" {
            here ++> prev_node;
        }
    }

    new_node = TaskState(
        task_name=self.task_name,
        created_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    );
    here ++> new_node;
    prev_node +>: TaskFlow(label=self.edge_label) :+> new_node;
    here.last_task = self.task_name;

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
    here.saved_routines[self.routine_name] = {
        "nodes": graph_data[0].copy(),
        "edges": graph_data[1].copy(),
        "saved_at": timestamp
    };

    node_count = 0;
    for _ in graph_data[0] {
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
    all_routines = [-->](`?user_routines);
    user_routines_node = None;
    for r in all_routines {
        if r?.username and r.username == self.username {
            user_routines_node = r;
            break;
        }
    }
    if user_routines_node == None {
        report {"routines": {}, "count": 0, "message": "No past routines saved yet"} ;
        disengage;
    }
    visit user_routines_node;
}

impl load_past_routines.load_routines{
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
    all_task_nodes = [-->](`?TaskState);
    for node in all_task_nodes {
        del node ;
    }

    node_map = {};
    for node_name in self.new_nodes {
        new_task = TaskState(
            task_name=node_name,
            created_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        );
        node_map[node_name] = new_task;
        here ++> new_task;
    }

    for edge_spec in self.new_edges {
        from_name = edge_spec.get("from", "");
        to_name = edge_spec.get("to", "");
        edge_label = edge_spec.get("label", "");

        if from_name in node_map and to_name in node_map {
            from_node = node_map[from_name];
            to_node = node_map[to_name];
            from_node +>: TaskFlow(label=edge_label) :+> to_node;
        }
    }

    here.last_task = (self.new_nodes[-1] if self.new_nodes and len(self.new_nodes) > 0 else "Start");
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
                graph_data = get_user_graph_structure(user_graph);
                current_nodes = graph_data[0];
                current_edges = graph_data[1];

                leaf_nodes = find_leaf_nodes(current_edges, current_nodes);
                if len(leaf_nodes) > 1 {
                    last_task = "|".join(leaf_nodes);
                } elif len(leaf_nodes) == 1 {
                    last_task = leaf_nodes[0];
                } else {
                    current_nodes = ["Start"];
                }
            } else {
                current_nodes = ["Start"];
            }
        } else {
            current_nodes = ["Start"];
        }

        before_nodes = current_nodes.copy();
        before_edges = current_edges.copy();

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

        if intent_analysis.conversation_context.correction_type == "rename" {
            referring_to = intent_analysis.conversation_context.referring_to_task;

            old_name = None;
            if referring_to and referring_to in current_nodes {
                old_name = referring_to;
            } else {
                for node in current_nodes {
                    if referring_to and node.lower() == referring_to.lower() {
                        old_name = node;
                        break;
                    }
                }
                if not old_name {
                    old_name = last_task.split("|")[0] if "|" in last_task else last_task;
                }
            }

            extracted_tasks = extract_raw_task_names(
                user_message=self.context_from_user,
                conversation_context=intent_analysis.conversation_context,
                existing_nodes=current_nodes
            );

            new_name = extracted_tasks.renamed_to;

            if old_name != "Start" and new_name {
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

                root spawn validate_graph_output(
                    context_from_user=self.context_from_user,
                    username=self.username,
                    intent_analysis=intent_dict,
                    extracted_tasks=[new_name],
                    before_nodes=before_nodes,
                    before_edges=before_edges,
                    after_nodes=new_nodes,
                    after_edges=new_edges
                );

                response = generate_friendly_response(self.context_from_user, emotional_state, "task_renamed", [new_name]);

                manager_data = find_manager_comm_data(here, self.username);
                if not manager_data {
                    manager_data = manager_comm_data(username=self.username);
                    here ++> manager_data;
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

            correction_type = intent_analysis.conversation_context.correction_type;
            referring_to = intent_analysis.conversation_context.referring_to_task;

            if correction_type in ["insert_before", "insert_after", "insert_first"] {
                if correction_type == "insert_before" and referring_to {
                    for edge in current_edges {
                        if edge.get("to") == referring_to {
                            last_task = edge.get("from");
                            edge_to_split = edge;
                            break;
                        }
                    }
                } elif correction_type == "insert_after" and referring_to {
                    last_task = referring_to;
                    edge_to_split = next((e for e in current_edges if e.get("from") == referring_to), None);
                } elif correction_type == "insert_first" {
                    last_task = "Start";
                }
            }

            attachment_analysis = determine_attachment_points(
                user_message=self.context_from_user,
                last_task=last_task,
                existing_nodes=current_nodes,
                conversation_context=intent_analysis.conversation_context
            );

            convergence_intent = detect_convergence_intent(
                user_message=self.context_from_user,
                last_task=last_task,
                current_edges=current_edges
            );

            relationships = build_task_relationships(
                user_message=self.context_from_user,
                extracted_tasks=extracted_tasks,
                attachment_analysis=attachment_analysis,
                convergence_intent=convergence_intent,
                conversation_context=intent_analysis.conversation_context,
                current_edges=current_edges
            );

            if intent_analysis.conversation_context.needs_graph_rebuild
            and len(current_nodes) > 1 {
                all_nodes = ["Start"];
                added_nodes = {"Start": True};

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

                for node in current_nodes {
                    if node not in added_nodes and node != "Start" {
                        all_nodes.append(node);
                        added_nodes[node] = True;
                    }
                }

                edge_map = {};
                tasks_to_move = intent_analysis.conversation_context.tasks_to_move if hasattr(intent_analysis.conversation_context, 'tasks_to_move') else [];

                if len(tasks_to_move) > 0 {
                    for edge in current_edges {
                        from_task = edge.get("from", "");
                        to_task = edge.get("to", "");

                        involves_moved_task = False;
                        for moved_task in tasks_to_move {
                            if from_task == moved_task or to_task == moved_task {
                                involves_moved_task = True;
                                break;
                            }
                        }

                        if not involves_moved_task {
                            edge_key = f"{from_task}->{to_task}";
                            edge_map[edge_key] = edge;
                        }
                    }
                } else {
                    for edge in current_edges {
                        from_task = edge.get("from", "");
                        to_task = edge.get("to", "");
                        edge_key = f"{from_task}->{to_task}";
                        edge_map[edge_key] = edge;
                    }

                    if edge_to_split {
                        split_key = f"{edge_to_split.get('from', '')}->{edge_to_split.get('to', '')}";
                        if split_key in edge_map {
                            del edge_map[split_key];
                        }
                    }

                    edges_to_remove = {};
                    for rel in relationships {
                        for other_rel in relationships {
                            if rel.to_task == other_rel.from_task {
                                direct_edge_key = f"{rel.from_task}->{other_rel.to_task}";
                                if direct_edge_key in edge_map {
                                    edges_to_remove[direct_edge_key] = True;
                                }
                            }
                        }
                    }

                    for edge_key in edges_to_remove {
                        if edge_key in edge_map {
                            del edge_map[edge_key];
                        }
                    }
                }

                for rel in relationships {
                    edge_key = f"{rel.from_task}->{rel.to_task}";
                    edge_map[edge_key] = {
                        "from": rel.from_task,
                        "to": rel.to_task,
                        "label": rel.edge_label
                    };
                }

                new_edges = [];
                for edge_key in edge_map {
                    new_edges.append(edge_map[edge_key]);
                }
                here spawn rebuild_graph(
                    username=self.username, new_nodes=all_nodes, new_edges=new_edges
                );
            } else {
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

        thinking_summary = generate_thinking_summary(
            user_message=self.context_from_user,
            emotional_state=emotional_state,
            intent_analysis=intent_analysis,
            extracted_tasks=extracted_tasks,
            attachment_analysis=attachment_analysis,
            convergence_intent=convergence_intent
        );

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
            suggestions = [];
        }

        thinking = {
            "emotional": thinking_summary.emotional_insight if thinking_summary.emotional_insight else "",
            "intent": thinking_summary.intent_insight if thinking_summary.intent_insight else "",
            "tasks": thinking_summary.task_insight if thinking_summary.task_insight else "",
            "pattern": thinking_summary.pattern_insight if thinking_summary.pattern_insight else ""
        };

        user_graph_after = find_user_graph(here, self.username);
        after_nodes = [];
        after_edges = [];
        if user_graph_after {
            graph_data = get_user_graph_structure(user_graph_after);
            after_nodes = graph_data[0];
            after_edges = graph_data[1];
        }

        manager_data = find_manager_comm_data(here, self.username);
        if not manager_data {
            manager_data = manager_comm_data(username=self.username);
            here ++> manager_data;
        }
        manager_data.last_response = response;
        manager_data.last_suggestions = suggestions;
        manager_data.last_thinking = thinking;
        manager_data.last_task_names = task_names;
        manager_data.last_emotional_state = emotional_state.state;

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

        # Read validation result from manager_comm_data
        validation_failed = False;
        validation_reason = "";
        validation_type = "";
        missing_tasks = [];

        if not manager_data.validation_passed {
            validation_failed = True;
            validation_reason = manager_data.validation_reason;
            validation_type = manager_data.validation_type or "";
            missing_tasks = manager_data.missing_tasks or [];
        }

        if validation_failed {
            if validation_type == "task_rename" {
                incorrect_task = manager_data.incorrect_task or "";
                correct_task_name = manager_data.correct_task_name or "";

                if incorrect_task and correct_task_name {
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

                    response = f"{response} I've renamed '{incorrect_task}' to '{correct_task_name}'.";

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
                user_graph = find_user_graph(here, self.username);
                last_task = "Start";
                if user_graph {
                    last_task = user_graph?.last_task or "Start";
                }

                # Add each missing task to the graph
                for missing_task in missing_tasks {
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
                response = f"{response} I've also added: {', '.join(missing_tasks)}.";

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

            elif validation_type in ["edge_labels", "rename_operation", "insert_operation", "reorder_operation", "graph_structure"] {
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
        }

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
            report graph_agent_result;
        } else {
            report {
                "error": "No response from graph agent",
                "response": "I apologize, something went wrong."
            };
        }

    } except Exception as e {
        report {
            "error": "Manager processing failed",
            "response": "I apologize, something went wrong while processing your request."
        };
    }
}

def parse_printgraph_output(dot_output: str) -> tuple {
    node_list = [];
    edge_list = [];
    node_map = {};

    if not dot_output {
        return (node_list, edge_list);
    }

    dot_output = dot_output.replace("&#x27;", "'");
    dot_output = dot_output.replace("&quot;", '"');
    lines = dot_output.split("\n");

    # FIRST PASS: Parse all node definitions
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
        if "->" in line and not line.startswith("//") {
            parts = line.split("->");
            if len(parts) == 2 {
                from_id = parts[0].strip();
                to_part = parts[1].strip();
                to_id = "";
                if "[" in to_part {
                    to_id = to_part.split("[")[0].strip();
                } else {
                    to_id = to_part.strip().rstrip(";");
                }

                edge_label = "";
                if "TaskFlow(label=" in to_part {
                    label_idx = to_part.find("TaskFlow(label=");
                    if label_idx >= 0 {
                        rest = to_part[label_idx + 15:];
                        if len(rest) > 1 and rest[0] == "'" {
                            quote_end = rest.find("'", 1);
                            if quote_end > 1 {
                                edge_label = rest[1:quote_end];
                            }
                        }
                    }
                }

                if from_id in node_map and to_id in node_map {
                    edge_list.append({
                        "from": node_map[from_id],
                        "to": node_map[to_id],
                        "label": edge_label
                    });
                }
            }
        }
    }

    return (node_list, edge_list);
}

def generate_dot_code_from_lists(node_list: list, edge_list: list) -> str {
    if len(node_list) == 0 {
        return "";
    }

    lines = ["digraph TaskGraph {"];
    lines.append("  rankdir=TB;");
    lines.append("  node [shape=box, style=rounded, fontname=\"Arial\"];");
    lines.append("  edge [fontname=\"Arial\", fontsize=10];");
    lines.append("");

    for task_node in node_list {
        if task_node == "Start" {
            lines.append("  " + task_node + " [shape=circle, style=filled, fillcolor=\"#22c55e\", fontcolor=white];");
        } else {
            lines.append("  " + task_node + " [style=\"rounded,filled\", fillcolor=\"#3b82f6\", fontcolor=white];");
        }
    }

    lines.append("");

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

def find_leaf_nodes(edge_list: list, node_list: list) -> list {
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

    if len(leaf_nodes) == 0 and len(node_list) > 1 {
        return [node_list[-1]];
    }

    return leaf_nodes;
}

"""Find user's graph or return None"""
def find_user_graph(root_node: node, username: str) {
    all_graphs = [root_node-->](`?user_graph_data);
    for graph in all_graphs {
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

    direct_nodes = [user_graph_node-->](`?TaskState);
    node_map = {};
    for node in direct_nodes {
        if node?.task_name {
            node_map[id(node)] = node.task_name;
            node_list.append(node.task_name);
        }
    }

    for from_node in direct_nodes {
        if from_node?.task_name {
            successors = [from_node-->](`?TaskState);
            for to_node in successors {
                if id(to_node) in node_map {
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

impl validate_graph_output.validate {
    manager_data = find_manager_comm_data(here, self.username);
    if not manager_data {
        manager_data = manager_comm_data(username=self.username);
        here ++> manager_data;
    }

    intent_analysis = self.intent_analysis or {};
    extracted_tasks = self.extracted_tasks or [];
    before_nodes = self.before_nodes or [];
    before_edges = self.before_edges or [];
    after_nodes = self.after_nodes or [];
    after_edges = self.after_edges or [];
    user_message = self.context_from_user;

    conversation_context = intent_analysis.get("conversation_context", {});
    correction_type = conversation_context.get("correction_type", "");
    referring_to_task = conversation_context.get("referring_to_task", "");
    tasks_to_move = conversation_context.get("tasks_to_move", []);

    manager_data.validation_passed = True;
    manager_data.validation_reason = "";
    manager_data.validation_type = "";
    manager_data.correction_needed = False;
    manager_data.missing_tasks = [];
    manager_data.incorrect_task = "";
    manager_data.correct_task_name = "";

    # Route to appropriate validation based on operation type
    if correction_type == "rename" {
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

        if not old_task or not new_task {
            return;
        }

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
            manager_data.validation_passed = False;
            manager_data.validation_reason = rename_validation.reason;
            manager_data.validation_type = "rename_operation";
        }
    }
    elif correction_type in ["insert_before", "insert_after", "insert_first"] {
        insert_validation = validate_insert_operation(
            user_message=user_message,
            operation_type=correction_type,
            referring_to_task=referring_to_task,
            new_tasks=extracted_tasks,
            before_edges=before_edges,
            after_edges=after_edges
        );

        if not insert_validation.is_valid {
            manager_data.validation_passed = False;
            manager_data.validation_reason = insert_validation.reason;
            manager_data.validation_type = "insert_operation";
        }
    }
    elif correction_type == "reorder" or len(tasks_to_move) > 0 {
        reorder_tasks = tasks_to_move if len(tasks_to_move) > 0 else extracted_tasks;

        reorder_validation = validate_reorder_operation(
            user_message=user_message,
            tasks_to_move=reorder_tasks,
            before_edges=before_edges,
            after_edges=after_edges
        );

        if not reorder_validation.is_valid {
            manager_data.validation_passed = False;
            manager_data.validation_reason = reorder_validation.reason;
            manager_data.validation_type = "reorder_operation";
        }
    }
    else {
        conversation_context = intent_analysis.get("conversation_context", {});
        intent_str = str(conversation_context.get("intent", "")) if conversation_context.get("intent") else "";

        if "ASK_QUESTION" in intent_str or "THINK_ALOUD" in intent_str {
            return;
        }

        # Validation 1: Task Extraction (pass before_nodes for rename detection)
        task_validation = validate_task_extraction(
            user_message=user_message,
            extracted_tasks=extracted_tasks,
            existing_nodes=before_nodes
        );

        if not task_validation.is_valid {
            if task_validation.incorrect_task and len(task_validation.incorrect_task) > 0 {
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
            manager_data.validation_passed = False;
            manager_data.validation_reason = graph_validation.reason;
            manager_data.validation_type = "graph_structure";
        }
    }
}