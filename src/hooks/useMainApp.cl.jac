# useMainApp Hook
# Custom hook containing all business logic for MainApp component
# Separates state management, API calls, and event handlers from UI

cl import from react { useState, useEffect, useRef }
cl import from "@openai/agents/realtime" { RealtimeAgent, RealtimeSession, tool }
cl import from "@jac-client/utils" { useNavigate }

cl import from ..constants.index { CHAT_AGENT_INSTRUCTIONS }

# ============================================
# Utility Functions
# ============================================

cl {
    # Extract username from JWT token stored in localStorage
    def:pub getUsernameFromToken() -> str {
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
        return username;
    }

    # Extract text content from OpenAI message content array
    def extractMessageText(content: any) -> str {
        if not content or not content.length {
            return "";
        }
        text = "";
        for c in content {
            if c and c.type == "input_text" {
                text = text + (c.text or "");
            } elif c and c.type == "audio" {
                text = text + (c.transcript or "");
            } elif c and c.type == "text" {
                text = text + (c.text or "");
            }
        }
        return text;
    }
}

# ============================================
# Main Hook
# ============================================

cl {
    def:pub useMainApp() -> any {
        navigate = useNavigate();
        
        # ========== State ==========
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
        
        # ========== Computed Values ==========
        isConnected = sessionStatus == "CONNECTED";
        isConnecting = sessionStatus == "CONNECTING";
        
        # ========== Transcript Helpers ==========
        
        # Add a new message to transcript (for system messages)
        def addMessage(role: str, content: str) -> None {
            itemId = "msg-" + String(Date.now());
            newItem = {"itemId": itemId, "role": role, "content": content, "timestamp": Date.now()};
            setTranscript(lambda prev: any -> any { return prev.concat([newItem]); });
        }
        
        # Add a transcript item by itemId (for realtime messages)
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
        
        # Update a transcript item by itemId
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
        
        # Append text to a transcript item by itemId (for streaming)
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
        
        # ========== Graph Operations ==========
        
        # Fetch and update graph state from backend
        async def refreshGraphState(username: str) -> None {
            try {
                graph_response = root spawn get_task_graph(username=username);
                console.log("Fetched updated graph:", graph_response);

                if graph_response and graph_response.reports and graph_response.reports.length > 0 {
                    graph_data = graph_response.reports[0];
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
                }
            } except Exception as graph_error {
                console.error("Failed to fetch updated graph:", graph_error);
            }
        }
        
        # Clear the task graph
        async def handleClearGraph() -> None {
            try {
                username = getUsernameFromToken();
                
                clearResponse = root spawn clear_graph(username=username);
                clearResult = clearResponse.reports[0] if clearResponse.reports else {};
                console.log("Clear graph response:", clearResult);
                
                if clearResult and clearResult.success {
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
        
        # ========== API Calls ==========
        
        # Fetch ephemeral key from backend for OpenAI Realtime API
        async def fetchEphemeralKey() -> any {
            try {
                response = root spawn get_session_token();
                data = response.reports[0];
                console.log("Session response:", data);
                
                if data and "error" in data {
                    console.error("Error fetching session:", data);
                    return None;
                }
                
                if data and "key" in data {
                    return data.key;
                }
                
                return None;
            } except Exception as e {
                console.error("Error fetching ephemeral key:", e);
                return None;
            }
        }
        
        # Execute supervisor tool - called by the Chat Agent
        async def executeSupervisorTool(input: any, details: any) -> any {
            context = input.relevantContextFromLastUserMessage or "";
            history = details.context.history or [];

            filteredHistory = history.filter(lambda log: any -> bool { return log.type == "message"; });

            console.log("Calling supervisor with context:", context);
            
            username = getUsernameFromToken();
            console.log("Using username:", username);

            result = root spawn call_supervisor(
                conversation_history=filteredHistory,
                context_from_user=context,
                username=username
            );

            response_data = result.reports[result.reports.length - 1] if result.reports and result.reports.length > 0 else {};
            console.log("Supervisor response_data:", response_data);

            if response_data and "error" in response_data {
                console.error("Supervisor error:", response_data);
                return {"error": "Something went wrong."};
            }

            # Fetch updated graph state after supervisor completes
            await refreshGraphState(username);

            # Extract response
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
        
        # Create the supervisor tool for the Chat Agent
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
        
        # ========== Connection Management ==========
        
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
                
                supervisorTool = createSupervisorTool();
                
                chatAgentConfig = {
                    "name": "chatAgent",
                    "voice": "sage",
                    "instructions": CHAT_AGENT_INSTRUCTIONS,
                    "tools": [supervisorTool]
                };
                chatAgent = Reflect.construct(RealtimeAgent, [chatAgentConfig]);

                console.log("Chat Agent created with supervisor tool");

                session = Reflect.construct(RealtimeSession, [chatAgent]);
                
                console.log("Session created, setting up event listeners...");
                
                # Set up session event listeners
                setupSessionEventListeners(session);
                
                console.log("Connecting to OpenAI...");
                
                await session.connect({"apiKey": api_key});
                
                console.log("Successfully connected to OpenAI Realtime API with multi-agent setup!");
                sessionRef.current = session;
                setSessionStatus("CONNECTED");

                # Load user's existing graph when they connect
                username = getUsernameFromToken();
                console.log("Loading graph for username:", username);
                await refreshGraphState(username);

                addMessage("system", "Connected! Algo is ready. Say 'hi' to start!");
                
            } except Exception as e {
                console.error("Connection error:", e);
                if e and e.message {
                    console.error("Error message:", e.message);
                }
                setSessionStatus("DISCONNECTED");
            }
        }
        
        # Set up event listeners for the realtime session
        def setupSessionEventListeners(session: any) -> None {
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
                    
                    if role == "user" and not text {
                        text = "[Transcribing...]";
                    }
                    
                    if role == "assistant" and not text {
                        text = "...";
                    }
                    
                    if role and itemId {
                        addTranscriptItem(itemId, role, text);
                    }
                } elif item.type == "function_call" {
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
                        
                        if text and itemId {
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
                    itemId = event.item_id or "";
                    transcriptText = event.transcript or "[inaudible]";
                    if transcriptText == "\n" {
                        transcriptText = "[inaudible]";
                    }
                    console.log("[transcription completed]", itemId, transcriptText);
                    updateTranscriptItem(itemId, transcriptText);
                } elif eventType == "response.output_audio_transcript.delta" {
                    itemId = event.item_id or "";
                    deltaText = event.delta or "";
                    console.log("[transcript delta]", itemId, deltaText);
                    addTranscriptItem(itemId, "assistant", "");
                    appendTranscriptItem(itemId, deltaText);
                } elif eventType == "response.output_audio_transcript.done" {
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
        }
        
        # Disconnect from OpenAI Realtime API
        def disconnectFromRealtime() -> None {
            if sessionRef.current {
                console.log("Disconnecting session...");
                sessionRef.current.close();
                sessionRef.current = None;
            }
            setSessionStatus("DISCONNECTED");
            setIsPTTUserSpeaking(False);
        }
        
        # Toggle connection state
        def onToggleConnection() -> None {
            if sessionStatus == "CONNECTED" or sessionStatus == "CONNECTING" {
                disconnectFromRealtime();
            } else {
                connectToRealtime();
            }
        }
        
        # ========== Microphone Controls ==========
        
        # Toggle mic mute state
        def toggleMicMute() -> None {
            setIsMicMuted(lambda prev: bool -> bool { return not prev; });
        }
        
        # ========== Push-to-Talk Handlers ==========
        
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
        
        # ========== Message Handling ==========
        
        # Send text message (text-only chat or via voice session)
        async def handleSendTextMessage() -> None {
            message = userText.trim();
            if not message {
                return;
            }
            
            setUserText("");
            addMessage("user", message);
            
            username = getUsernameFromToken();
            
            # If connected to realtime session, send via voice
            if sessionRef.current and sessionStatus == "CONNECTED" {
                try {
                    sessionRef.current.sendMessage(message);
                    return;
                } except Exception as e {
                    console.error("Failed to send via realtime, falling back to text:", e);
                }
            }
            
            # Text-only mode: call supervisor directly
            try {
                assistantItemId = "assistant-" + String(Date.now());
                addTranscriptItem(assistantItemId, "assistant", "Thinking...");
                
                console.log("Calling supervisor with message:", message, "username:", username);
                response = root spawn call_supervisor(context_from_user=message, conversation_history=[], username=username);
                console.log("Supervisor response:", response);
                
                if response and response.reports and response.reports.length > 0 {
                    result = response.reports[0];
                    console.log("Result:", result);
                    if result and result.response {
                        updateTranscriptItem(assistantItemId, result.response);
                    } elif result and result.error {
                        updateTranscriptItem(assistantItemId, "Error: " + result.error);
                    } else {
                        updateTranscriptItem(assistantItemId, "Sorry, I couldn't process that request.");
                    }
                    
                    await refreshGraphState(username);
                } else {
                    updateTranscriptItem(assistantItemId, "Sorry, something went wrong.");
                }
            } except Exception as e {
                console.error("Text chat error:", e);
                addMessage("system", "Error: Failed to get response");
            }
        }
        
        # ========== Routine Management ==========
        
        # Save current routine and restart session
        async def handleSaveAndRestart() -> None {
            if sessionStatus != "CONNECTED" {
                return;
            }
            
            try {
                username = getUsernameFromToken();
                
                saveResponse = root spawn save_routine(routine_name="daily_routine", username=username);
                saveResult = saveResponse.reports[0] if saveResponse.reports else {};
                console.log("Save routine response:", saveResult);
                
                if saveResult and saveResult.success {
                    addMessage("system", "✓ Routine saved! Restarting session...");
                    
                    setTranscript([]);
                    
                    setTimeout(lambda -> None {
                        addMessage("assistant", "Welcome back! I remember your routine. How can I help you today?");
                    }, 500);
                } else {
                    errorMsg = saveResult.error if saveResult and saveResult.error else "Unknown error";
                    addMessage("error", f"Failed to save routine: {errorMsg}");
                }
            } except Exception as e {
                console.error("Save and restart error:", e);
                addMessage("error", "Error during save and restart");
            }
        }
        
        # ========== Effects ==========
        
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
        
        # Handle mic mute/unmute
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
        
        # Audio playback toggle
        useEffect(
            lambda -> None {
                if audioElementRef.current {
                    audioElementRef.current.muted = not isAudioPlaybackEnabled;
                }
            },
            [isAudioPlaybackEnabled]
        );
        
        # ========== Return Hook Interface ==========
        return {
            # State
            "sessionStatus": sessionStatus,
            "isPTTActive": isPTTActive,
            "setIsPTTActive": setIsPTTActive,
            "isPTTUserSpeaking": isPTTUserSpeaking,
            "isAudioPlaybackEnabled": isAudioPlaybackEnabled,
            "setIsAudioPlaybackEnabled": setIsAudioPlaybackEnabled,
            "isMicMuted": isMicMuted,
            "userText": userText,
            "setUserText": setUserText,
            "transcript": transcript,
            "graphDotCode": graphDotCode,
            "graphEdges": graphEdges,
            "lastTask": lastTask,
            
            # Refs
            "transcriptEndRef": transcriptEndRef,
            
            # Computed
            "isConnected": isConnected,
            "isConnecting": isConnecting,
            
            # Handlers
            "onToggleConnection": onToggleConnection,
            "toggleMicMute": toggleMicMute,
            "handleTalkButtonDown": handleTalkButtonDown,
            "handleTalkButtonUp": handleTalkButtonUp,
            "handleSendTextMessage": handleSendTextMessage,
            "handleClearGraph": handleClearGraph,
            "handleSaveAndRestart": handleSaveAndRestart
        };
    }
}
