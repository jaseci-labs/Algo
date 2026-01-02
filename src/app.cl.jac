import from react { useState, useEffect, useRef }
import from "@openai/agents/realtime" { RealtimeAgent, RealtimeSession, tool }
import from "@jac-client/utils" {
    Router,
    Routes,
    Route,
    Navigate,
    jacIsLoggedIn,
    jacLogout,
    useNavigate
}

# Import components
import from .components.TranscriptItem { TranscriptItem }
import from .components.Header { Header }
import from .components.MessageInput { MessageInput }
import from .components.ControlBar { ControlBar }
import from .components.GraphViewer { GraphViewer }

# Import pages
import from .pages.LoginPage { LoginPage }
import from .pages.RegisterPage { RegisterPage }

# Constants
glob CHAT_AGENT_INSTRUCTIONS = """You are Algo, a friendly personal AI assistant with a great memory. You remember everything the user tells you about their day.

# IMPORTANT: Language
- ALWAYS speak in English only
- Even if the user speaks in another language, respond in English
- Keep all responses in clear, simple English

# CRITICAL: When to Call getNextResponseFromSupervisor
You MUST call getNextResponseFromSupervisor IMMEDIATELY when the user mentions ANY of the following:
- Any action they are doing, about to do, or just did (e.g., "I'm making coffee", "going to shower", "just woke up", "heading to work")
- Any task or activity (e.g., "checking emails", "in a meeting", "cooking dinner", "exercising")
- Any routine activity (e.g., "morning routine", "getting ready", "winding down")
- Any plan or intention (e.g., "I'm going to...", "I need to...", "planning to...")
- Calendar, meetings, emails, GitHub, or any data queries

# How to Respond When User Mentions an Action
1. FIRST: Say a brief, natural acknowledgment like "Memorizing that!", "Got it!", "Nice!", or just acknowledge what they said naturally
2. IMMEDIATELY AFTER: Call getNextResponseFromSupervisor with the action/task context
3. THEN: Speak the response from the supervisor naturally

# Examples of Natural Responses
- User: "I just woke up" → "Good morning! Let me remember that..." [call supervisor]
- User: "making breakfast" → "Nice! Memorizing..." [call supervisor]
- User: "I'm going to the gym" → "Awesome! Got it..." [call supervisor]
- User: "checking my emails" → "Sure thing!" [call supervisor]
- User: "done with my meeting" → "Great! Noted." [call supervisor]

# Greeting
- First time: "Hey! I'm Algo, your personal AI assistant. Just tell me what you're up to and I'll remember it for you!"
- Returning: "Welcome back! What are you up to now?"

# Tone
- Be brief and natural - you're a voice assistant
- Keep responses to 1-2 sentences max
- Sound conversational, like a helpful friend
- NEVER say "tracking" or "logged" - use words like "memorizing", "remembering", "got it", "noted"
- Be enthusiastic but not over the top

# Tools
- getNextResponseFromSupervisor: Your ONLY tool - use it for ALL actions, tasks, and data queries
- The supervisor handles memorizing activities and data retrieval
- Always pass the user's full context about what they mentioned
""";

# Main Application Component (Voice Agent Interface)
def:pub MainApp() -> any {
    navigate = useNavigate();
    
    # Connection state
    [sessionStatus, setSessionStatus] = useState("DISCONNECTED");
    sessionRef = useRef(None);
    audioElementRef = useRef(None);
    transcriptEndRef = useRef(None);
    
    # UI state
    [isPTTActive, setIsPTTActive] = useState(False);
    [isPTTUserSpeaking, setIsPTTUserSpeaking] = useState(False);
    [isAudioPlaybackEnabled, setIsAudioPlaybackEnabled] = useState(True);
    [isMicMuted, setIsMicMuted] = useState(False);
    
    # Message state
    [userText, setUserText] = useState("");
    [transcript, setTranscript] = useState([]);
    
    # Graph state for task visualization
    [graphDotCode, setGraphDotCode] = useState("");
    [graphEdges, setGraphEdges] = useState([]);
    [lastTask, setLastTask] = useState("Start");
    
    # Create audio element on mount
    useEffect(
        lambda -> None {
            el = document.createElement('audio');
            el.autoplay = True;
            el.style.display = 'none';
            document.body.appendChild(el);
            audioElementRef.current = el;
        },
        []
    );
    
    # Auto-scroll to bottom when transcript changes
    useEffect(
        lambda -> None {
            if transcriptEndRef.current {
                transcriptEndRef.current.scrollIntoView({"behavior": "smooth"});
            }
        },
        [transcript]
    );
    
    # Helper to add message to transcript (for system messages)
    def addMessage(role: str, content: str) -> None {
        itemId = "msg-" + String(Date.now());
        newItem = {"itemId": itemId, "role": role, "content": content, "timestamp": Date.now()};
        setTranscript(lambda prev: any -> any { return prev.concat([newItem]); });
    }
    
    # Helper to add a transcript item by itemId (for realtime messages)
    def addTranscriptItem(itemId: str, role: str, content: str) -> None {
        newItem = {"itemId": itemId, "role": role, "content": content, "timestamp": Date.now()};
        setTranscript(lambda prev: any -> any {
            exists = prev.some(lambda item: any -> bool { return item.itemId == itemId; });
            if exists {
                return prev;
            }
            return prev.concat([newItem]);
        });
    }
    
    # Helper to update a transcript item by itemId
    def updateTranscriptItem(itemId: str, content: str) -> None {
        setTranscript(lambda prev: any -> any {
            return prev.map(lambda item: any -> any {
                if item.itemId == itemId {
                    return {"itemId": item.itemId, "role": item.role, "content": content, "timestamp": item.timestamp};
                }
                return item;
            });
        });
    }
    
    # Helper to append text to a transcript item by itemId
    def appendTranscriptItem(itemId: str, deltaText: str) -> None {
        setTranscript(lambda prev: any -> any {
            return prev.map(lambda item: any -> any {
                if item.itemId == itemId {
                    currentContent = item.content or "";
                    newContent = currentContent + deltaText;
                    if currentContent == "..." or currentContent == "" {
                        newContent = deltaText;
                    }
                    return {"itemId": item.itemId, "role": item.role, "content": newContent, "timestamp": item.timestamp};
                }
                return item;
            });
        });
    }
    
    # Fetch ephemeral key from backend
    async def fetchEphemeralKey() -> any {
        try {
            response = root spawn get_session_token();
            data = response.reports[0];
            console.log("Session response:", data);
            
            if data && "error" in data {
                console.error("Error fetching session:", data);
                return None;
            }
            
            if data && "key" in data {
                return data.key;
            }
            
            return None;
        } except Exception as e {
            console.error("Error fetching ephemeral key:", e);
            return None;
        }
    }
    
    # Execute function for the supervisor tool
    async def executeSupervisorTool(input: any, details: any) -> any {
        context = input.relevantContextFromLastUserMessage or "";
        history = details.context.history or [];

        # Filter to just messages
        filteredHistory = history.filter(lambda  log: any  -> bool{ return log.type == "message"; });

        console.log("Calling supervisor with context:", context);
        
        # Get username from localStorage
        token = localStorage.getItem("jac_token");
        username = "anonymous";
        if token {
            # Try to decode JWT to get username (simple parse, not cryptographic verification)
            try {
                parts = token.split(".");
                if parts.length > 1 {
                    payload = JSON.parse(atob(parts[1]));
                    username = payload.username or "anonymous";
                }
            } except Exception as decode_error {
                console.error("Failed to decode token:", decode_error);
            }
        }
        console.log("Using username:", username);

        # Call backend walker with username
        result = root spawn call_supervisor(
            conversation_history=filteredHistory,
            context_from_user=context,
            username=username
        );

        # Get the LAST report (call_supervisor's report) not the first (spawned walker's report)
        response_data = result.reports[result.reports.length - 1] if result.reports && result.reports.length > 0 else {};
        console.log("Supervisor response_data:", response_data);
        console.log("All reports:", result.reports);

        if response_data && "error" in response_data {
            console.error("Supervisor error:", response_data);
            return {"error": "Something went wrong."};
        }

        # Fetch updated graph state after supervisor completes
        try {
            graph_response = root spawn get_task_graph(username=username);
            console.log("Fetched updated graph:", graph_response);

            if graph_response && graph_response.reports && graph_response.reports.length > 0 {
                graph_data = graph_response.reports[0];
                console.log("Graph data received:", graph_data);
                console.log("DOT code:", graph_data.dotCode);
                console.log("Nodes:", graph_data.nodes);
                console.log("Edges:", graph_data.edges);

                # Force state update by creating new references
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
                console.log("No graph data in response:", graph_response);
            }
        } except Exception as graph_error {
            console.error("Failed to fetch updated graph:", graph_error);
            # Don't fail the whole response if graph fetch fails
        }

        # Extract response - check both ways to access the property
        next_resp = "";
        if "response" in response_data {
            next_resp = response_data["response"];
            console.log("Got response via bracket notation:", next_resp);
        } else {
            console.log("No 'response' key found in response_data!");
            next_resp = "I apologize, I couldn't get a response.";
        }

        console.log("Returning nextResponse:", next_resp);
        return {"nextResponse": next_resp};
    }
    
    # Create the getNextResponseFromSupervisor tool
    def createSupervisorTool() -> any {
        return tool({
            "name": "getNextResponseFromSupervisor",
            "description": "IMPORTANT: Before calling this tool, briefly acknowledge what the user just said you should log (e.g., a routine or next action) and tell them you're memorizing/noting it so there's no silent pause. Then call this tool to record/update and get the next response.",
            "parameters": {
                "type": "object",
                "properties": {
                    "relevantContextFromLastUserMessage": {
                        "type": "string",
                        "description": "Key information from the user's most recent message."
                    }
                },
                "required": ["relevantContextFromLastUserMessage"],
                "additionalProperties": False
            },
            "execute": executeSupervisorTool
        });
    }
    
    # Connect to OpenAI Realtime API with multi-agent setup
    async def connectToRealtime() -> None {
        if sessionStatus != "DISCONNECTED" {
            return;
        }
        
        setSessionStatus("CONNECTING");
        
        try {
            if not window.isSecureContext {
                addMessage("error", "Microphone requires secure context. Access via http://localhost:8000");
                setSessionStatus("DISCONNECTED");
                return;
            }
            
            if not navigator.mediaDevices {
                addMessage("error", "MediaDevices API not available.");
                setSessionStatus("DISCONNECTED");
                return;
            }
            
            api_key = await fetchEphemeralKey();
            
            if not api_key {
                console.error("No ephemeral key received");
                setSessionStatus("DISCONNECTED");
                return;
            }
            
            console.log("Got ephemeral key, creating multi-agent setup...");
            
            # Create the supervisor tool
            supervisorTool = createSupervisorTool();
            
            # Create the Chat Agent (junior agent with supervisor tool)
            chatAgentConfig = {
                "name": "chatAgent",
                "voice": "sage",
                "instructions": CHAT_AGENT_INSTRUCTIONS,
                "tools": [supervisorTool]
            };
            chatAgent = Reflect.construct(RealtimeAgent, [chatAgentConfig]);

            console.log("Chat Agent created with supervisor tool");

            # Create session
            session = Reflect.construct(RealtimeSession, [chatAgent]);
            
            console.log("Session created, setting up event listeners...");
            
            # Helper to extract text from content array
            def extractMessageText(content: any) -> str {
                if not content or not content.length {
                    return "";
                }
                text = "";
                for c in content {
                    if c && c.type == "input_text" {
                        text = text + (c.text or "");
                    } elif c && c.type == "audio" {
                        text = text + (c.transcript or "");
                    } elif c && c.type == "text" {
                        text = text + (c.text or "");
                    }
                }
                return text;
            }
            
            # Listen for history_added events (new messages)
            session.on("history_added", lambda item: any -> None {
                console.log("[history_added]", item);
                if not item {
                    return;
                }
                
                if item.type == "message" {
                    itemId = item.itemId or item.item_id or "";
                    role = item.role or "";
                    content = item.content or [];
                    
                    text = extractMessageText(content);
                    
                    # For user messages without text, show transcribing
                    if role == "user" && not text {
                        text = "[Transcribing...]";
                    }
                    
                    # For assistant messages, add even if empty (will be updated)
                    if role == "assistant" && not text {
                        text = "...";
                    }
                    
                    if role && itemId {
                        addTranscriptItem(itemId, role, text);
                    }
                } elif item.type == "function_call" {
                    # Handle function calls as tool messages
                    itemId = item.itemId or item.item_id or "";
                    toolName = item.name or "tool";
                    addTranscriptItem(itemId, "tool", "🔧 Calling: " + toolName + "...");
                }
            });
            
            # Listen for history_updated events (message updates)
            session.on("history_updated", lambda items: any -> None {
                console.log("[history_updated]", items);
                if not items or not items.length {
                    return;
                }
                
                for item in items {
                    if not item {
                        continue;
                    }
                    
                    if item.type == "message" {
                        itemId = item.itemId or item.item_id or "";
                        role = item.role or "";
                        content = item.content or [];
                        
                        text = extractMessageText(content);
                        
                        if text && itemId {
                            # First ensure the item exists, then update
                            addTranscriptItem(itemId, role, text);
                            updateTranscriptItem(itemId, text);
                        }
                    } elif item.type == "function_call" {
                        itemId = item.itemId or item.item_id or "";
                        toolName = item.name or "tool";
                        status = item.status or "";
                        
                        if status == "completed" {
                            updateTranscriptItem(itemId, "✓ " + toolName + " completed");
                        }
                    }
                }
            });
            
            # Listen for transport events (audio transcription)
            session.on("transport_event", lambda event: any -> None {
                eventType = event.type or "";
                console.log("[transport_event]", eventType, event);
                
                if eventType == "conversation.item.input_audio_transcription.completed" {
                    # User speech transcription completed
                    itemId = event.item_id or "";
                    transcriptText = event.transcript or "[inaudible]";
                    if transcriptText == "\n" {
                        transcriptText = "[inaudible]";
                    }
                    console.log("[transcription completed]", itemId, transcriptText);
                    updateTranscriptItem(itemId, transcriptText);
                } elif eventType == "response.output_audio_transcript.delta" {
                    # Assistant response streaming - ensure item exists first
                    itemId = event.item_id or "";
                    deltaText = event.delta or "";
                    console.log("[transcript delta]", itemId, deltaText);
                    # Add the item first if it doesn't exist, then append
                    addTranscriptItem(itemId, "assistant", "");
                    appendTranscriptItem(itemId, deltaText);
                } elif eventType == "response.output_audio_transcript.done" {
                    # Assistant response complete - set final transcript
                    itemId = event.item_id or "";
                    transcriptText = event.transcript or "";
                    console.log("[transcript done]", itemId, transcriptText);
                    updateTranscriptItem(itemId, transcriptText);
                }
            });
            
            # Listen for tool calls
            session.on("agent_tool_start", lambda details: any, agent: any, functionCall: any -> None {
                console.log("[tool start]", functionCall);
                toolName = functionCall.name or "unknown";
                addMessage("tool", f"🔧 Calling: {toolName}...");
            });
            
            session.on("agent_tool_end", lambda details: any, agent: any, functionCall: any, result: any -> None {
                console.log("[tool end]", functionCall, result);
            });
            
            console.log("Connecting to OpenAI...");
            
            await session.connect({"apiKey": api_key});
            
            console.log("Successfully connected to OpenAI Realtime API with multi-agent setup!");
            sessionRef.current = session;
            setSessionStatus("CONNECTED");

            # Load user's existing graph when they connect
            try {
                # Get username from localStorage
                token = localStorage.getItem("jac_token");
                username = "anonymous";
                if token {
                    try {
                        parts = token.split(".");
                        if parts.length > 1 {
                            payload = JSON.parse(atob(parts[1]));
                            username = payload.username or "anonymous";
                        }
                    } except Exception as decode_error {
                        console.error("Failed to decode token:", decode_error);
                    }
                }
                console.log("Loading graph for username:", username);
                
                graph_response = root spawn get_task_graph(username=username);
                console.log("Loaded user's graph:", graph_response);

                if graph_response && graph_response.reports && graph_response.reports.length > 0 {
                    graph_data = graph_response.reports[0];

                    # Update graph visualization if user has existing data
                    if graph_data.dotCode {
                        console.log("Setting initial DOT code:", graph_data.dotCode);
                        setGraphDotCode(graph_data.dotCode);
                    }
                    if graph_data.edges && graph_data.edges.length > 0 {
                        console.log("Setting initial edges:", graph_data.edges);
                        setGraphEdges(graph_data.edges);
                    }
                    if graph_data.lastTask {
                        setLastTask(graph_data.lastTask);
                    }
                }
            } except Exception as graph_load_error {
                console.error("Failed to load user's graph:", graph_load_error);
                # Don't fail connection if graph loading fails
            }

            addMessage("system", "Connected! Algo is ready. Say 'hi' to start!");
            
        } except Exception as e {
            console.error("Connection error:", e);
            if e && e.message {
                console.error("Error message:", e.message);
            }
            setSessionStatus("DISCONNECTED");
        }
    }
    
    # Disconnect
    def disconnectFromRealtime() -> None {
        if sessionRef.current {
            console.log("Disconnecting session...");
            sessionRef.current.close();
            sessionRef.current = None;
        }
        setSessionStatus("DISCONNECTED");
        setIsPTTUserSpeaking(False);
    }
    
    # Toggle connection
    def onToggleConnection() -> None {
        if sessionStatus == "CONNECTED" or sessionStatus == "CONNECTING" {
            disconnectFromRealtime();
        } else {
            connectToRealtime();
        }
    }

    # Toggle mic mute
    def toggleMicMute() -> None {
        setIsMicMuted(lambda prev: bool -> bool { return not prev; });
    }

    # Effect to handle mic mute/unmute
    useEffect(
        lambda -> None {
            if sessionRef.current {
                try {
                    console.log("Setting mic mute state to:", isMicMuted);
                    sessionRef.current.mute(isMicMuted);
                } except Exception as e {
                    console.error("Error toggling mic:", e);
                }
            }
        },
        [isMicMuted, sessionStatus]
    );

    # Send text message (text-only chat, no voice)
    async def handleSendTextMessage() -> None {
        message = userText.trim();
        if not message {
            return;
        }
        
        # Clear input immediately
        setUserText("");
        
        # Add user message to transcript
        addMessage("user", message);
        
        # Get username from localStorage
        token = localStorage.getItem("jac_token");
        username = "anonymous";
        if token {
            try {
                parts = token.split(".");
                if parts.length > 1 {
                    payload = JSON.parse(atob(parts[1]));
                    username = payload.username or "anonymous";
                }
            } except Exception as decode_error {
                console.error("Failed to decode token:", decode_error);
            }
        }
        
        # If connected to realtime session, send via voice
        if sessionRef.current && sessionStatus == "CONNECTED" {
            try {
                sessionRef.current.sendMessage(message);
                return;
            } except Exception as e {
                console.error("Failed to send via realtime, falling back to text:", e);
            }
        }
        
        # Text-only mode: call supervisor directly
        try {
            # Add placeholder for assistant response
            assistantItemId = "assistant-" + String(Date.now());
            addTranscriptItem(assistantItemId, "assistant", "Thinking...");
            
            # Call supervisor walker directly with username
            console.log("Calling supervisor with message:", message, "username:", username);
            response = root spawn call_supervisor(context_from_user=message, conversation_history=[], username=username);
            console.log("Supervisor response:", response);
            
            if response && response.reports && response.reports.length > 0 {
                result = response.reports[0];
                console.log("Result:", result);
                if result && result.response {
                    updateTranscriptItem(assistantItemId, result.response);
                } elif result && result.error {
                    updateTranscriptItem(assistantItemId, "Error: " + result.error);
                } else {
                    updateTranscriptItem(assistantItemId, "Sorry, I couldn't process that request.");
                }
                
                # Fetch updated graph after supervisor completes
                try {
                    graph_response = root spawn get_task_graph(username=username);
                    console.log("Fetched updated graph:", graph_response);

                    if graph_response && graph_response.reports && graph_response.reports.length > 0 {
                        graph_data = graph_response.reports[0];
                        console.log("Graph data received:", graph_data);

                        if graph_data.dotCode {
                            console.log("Updating graph with DOT code:", graph_data.dotCode);
                            setGraphDotCode(graph_data.dotCode);
                        }
                        if graph_data.edges {
                            setGraphEdges(graph_data.edges);
                        }
                        if graph_data.lastTask {
                            setLastTask(graph_data.lastTask);
                        }
                    }
                } except Exception as graph_error {
                    console.error("Failed to fetch updated graph:", graph_error);
                }
            } else {
                updateTranscriptItem(assistantItemId, "Sorry, something went wrong.");
            }
        } except Exception as e {
            console.error("Text chat error:", e);
            addMessage("system", "Error: Failed to get response");
        }
    }
    
    # PTT handlers
    def handleTalkButtonDown() -> None {
        if sessionStatus != "CONNECTED" {
            return;
        }
        setIsPTTUserSpeaking(True);
        
        if sessionRef.current {
            try {
                sessionRef.current.interrupt();
            } except Exception as e {
                console.error("PTT error:", e);
            }
        }
    }
    
    def handleTalkButtonUp() -> None {
        if sessionStatus != "CONNECTED" or not isPTTUserSpeaking {
            return;
        }
        setIsPTTUserSpeaking(False);
    }
    
    # Audio playback toggle
    useEffect(
        lambda -> None {
            if audioElementRef.current {
                audioElementRef.current.muted = not isAudioPlaybackEnabled;
            }
        },
        [isAudioPlaybackEnabled]
    );
    
    # Clear graph handler
    async def handleClearGraph() -> None {
        try {
            # Get username from localStorage
            token = localStorage.getItem("jac_token");
            username = "anonymous";
            if token {
                try {
                    parts = token.split(".");
                    if parts.length > 1 {
                        payload = JSON.parse(atob(parts[1]));
                        username = payload.username or "anonymous";
                    }
                } except Exception as decode_error {
                    console.error("Failed to decode token:", decode_error);
                }
            }
            
            # Clear the graph
            clearResponse = root spawn clear_graph(username=username);
            clearResult = clearResponse.reports[0] if clearResponse.reports else {};
            console.log("Clear graph response:", clearResult);
            
            if clearResult && clearResult.success {
                # Refresh the graph display
                graphResponse = root spawn get_task_graph(username=username);
                result = graphResponse.reports[0] if graphResponse.reports else {};
                
                setGraphDotCode(result.dotCode or "");
                setGraphEdges(result.edges or []);
                setLastTask(result.lastTask or "Start");
                
                addMessage("system", "Graph cleared! Starting fresh.");
            } else {
                addMessage("error", "Failed to clear graph");
            }
        } except Exception as e {
            console.error("Clear graph error:", e);
            addMessage("error", "Error clearing graph");
        }
    }
    
    # Save and Restart handler
    async def handleSaveAndRestart() -> None {
        if sessionStatus != "CONNECTED" {
            return;
        }
        
        try {
            # Get username from localStorage
            token = localStorage.getItem("jac_token");
            username = "anonymous";
            if token {
                try {
                    parts = token.split(".");
                    if parts.length > 1 {
                        payload = JSON.parse(atob(parts[1]));
                        username = payload.username or "anonymous";
                    }
                } except Exception as decode_error {
                    console.error("Failed to decode token:", decode_error);
                }
            }
            
            # Save the current routine with username
            saveResponse = root spawn save_routine(routine_name="daily_routine", username=username);
            saveResult = saveResponse.reports[0] if saveResponse.reports else {};
            console.log("Save routine response:", saveResult);
            
            if saveResult && saveResult.success {
                addMessage("system", "✓ Routine saved! Restarting session...");
                
                # Clear transcript only (keep graph for context)
                setTranscript([]);
                
                # Add welcome back message after a brief delay
                setTimeout(lambda -> None {
                    addMessage("assistant", "Welcome back! I remember your routine. How can I help you today?");
                }, 500);
            } else {
                errorMsg = saveResult.error if saveResult && saveResult.error else "Unknown error";
                addMessage("error", f"Failed to save routine: {errorMsg}");
            }
        } except Exception as e {
            console.error("Save and restart error:", e);
            addMessage("error", "Error during save and restart");
        }
    }
    
    # Computed values
    isConnected = sessionStatus == "CONNECTED";
    isConnecting = sessionStatus == "CONNECTING";
    
    connectBtnText = "Disconnect" if isConnected else ("Connecting..." if isConnecting else "Connect");
    connectBtnBg = "#dc2626" if isConnected else ("#1f2937" if isConnecting else "#000");
    
    # Build transcript items
    transcriptItems = [];
    idx = 0;
    for item in transcript {
        transcriptItems.push(<TranscriptItem key={idx} item={item} />);
        idx = idx + 1;
    }
    
    return <div style={{
        "display": "flex",
        "flexDirection": "column",
        "height": "100vh",
        "backgroundColor": "#f3f4f6",
        "color": "#1f2937",
        "fontFamily": "system-ui, -apple-system, sans-serif"
    }}>
        <Header />
        
        <div style={{
            "flex": "1",
            "display": "flex",
            "gap": "0.5rem",
            "padding": "0.5rem",
            "overflow": "hidden"
        }}>
            <div style={{
                "flex": "1",
                "backgroundColor": "#fff",
                "borderRadius": "0.75rem",
                "display": "flex",
                "flexDirection": "column",
                "minHeight": "0"
            }}>
                <div style={{
                    "display": "flex",
                    "alignItems": "center",
                    "justifyContent": "space-between",
                    "padding": "0.75rem 1.5rem",
                    "borderBottom": "1px solid #e5e7eb",
                    "fontWeight": "600"
                }}>
                    {"Transcript"}
                </div>
                
                <div style={{
                    "flex": "1",
                    "overflowY": "auto",
                    "padding": "1rem",
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": "1rem"
                }}>
                    {transcriptItems}
                    <div ref={transcriptEndRef} />
                </div>
                
                <MessageInput 
                    userText={userText}
                    setUserText={setUserText}
                    onSend={handleSendTextMessage}
                />
            </div>
            
            <div style={{
                "flex": "1",
                "backgroundColor": "#fff",
                "borderRadius": "0.75rem",
                "display": "flex",
                "flexDirection": "column",
                "minHeight": "0"
            }}>
                <div style={{
                    "display": "flex",
                    "alignItems": "center",
                    "justifyContent": "space-between",
                    "padding": "0.75rem 1.5rem",
                    "borderBottom": "1px solid #e5e7eb",
                    "fontWeight": "600"
                }}>
                    {"Task Graph"}
                    <span style={{"fontSize": "0.75rem", "color": "#9ca3af", "fontWeight": "normal"}}>
                        {"Real-time visualization"}
                    </span>
                </div>
                
                <div style={{
                    "flex": "1",
                    "overflow": "auto",
                    "backgroundColor": "#fafafa",
                    "position": "relative"
                }}>
                    <GraphViewer dotCode={graphDotCode} />
                    
                    <button
                        onClick={handleClearGraph}
                        style={{
                            "position": "absolute",
                            "bottom": "1rem",
                            "right": "1rem",
                            "padding": "0.5rem 1rem",
                            "backgroundColor": "#ef4444",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "0.5rem",
                            "cursor": "pointer",
                            "fontSize": "0.875rem",
                            "fontWeight": "500",
                            "boxShadow": "0 2px 4px rgba(0,0,0,0.1)"
                        }}
                    >
                        {"Clear Graph"}
                    </button>
                </div>
            </div>
        </div>
        
        <ControlBar
            sessionStatus={sessionStatus}
            onToggleConnection={onToggleConnection}
            isPTTActive={isPTTActive}
            setIsPTTActive={setIsPTTActive}
            isPTTUserSpeaking={isPTTUserSpeaking}
            onTalkDown={handleTalkButtonDown}
            onTalkUp={handleTalkButtonUp}
            isAudioPlaybackEnabled={isAudioPlaybackEnabled}
            setIsAudioPlaybackEnabled={setIsAudioPlaybackEnabled}
            isMicMuted={isMicMuted}
            onToggleMicMute={toggleMicMute}
            onSaveAndRestart={handleSaveAndRestart}
        />
    </div>;
}

# Protected Route Component
def ProtectedRoute(props: any) -> any {
    if not jacIsLoggedIn() {
        return <Navigate to="/login" />;
    }
    return props.children;
}

# Home Route - Redirect based on auth status
def HomePage() -> any {
    if jacIsLoggedIn() {
        return <Navigate to="/app" />;
    }
    return <Navigate to="/login" />;
}

# Main App with Router
def:pub app() -> any {
    return <Router>
        <Routes>
            <Route path="/" element={<HomePage />} />
            <Route path="/login" element={<LoginPage />} />
            <Route path="/register" element={<RegisterPage />} />
            <Route
                path="/app"
                element={
                    <ProtectedRoute>
                        <MainApp />
                    </ProtectedRoute>
                }
            />
        </Routes>
    </Router>;
}
