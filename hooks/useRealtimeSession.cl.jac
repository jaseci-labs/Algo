# useRealtimeSession Hook
# Custom hook for managing OpenAI Realtime API connection and session

import from react { useRef }
import from "@openai/agents/realtime" { RealtimeAgent, RealtimeSession, tool }

import from ..constants.constants { CHAT_AGENT_INSTRUCTIONS }
import from ..api.api {
    getSessionToken,
    callSupervisor,
    getUsernameFromToken
}

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

# Hook for managing OpenAI Realtime session
# @param transcriptHelpers - Object containing transcript manipulation functions
# @param refreshGraphState - Function to refresh graph state after supervisor calls
# @param setSuggestions - Function to update suggestions state in parent
def:pub useRealtimeSession(transcriptHelpers: any, refreshGraphState: any, setSuggestions: any) -> any {
    # Reactive state using has variables
    has sessionStatus: str = "DISCONNECTED";

    sessionRef = useRef(None);

    # Computed values
    isConnected = sessionStatus == "CONNECTED";
    isConnecting = sessionStatus == "CONNECTING";
        
        # Destructure transcript helpers
        addMessage = transcriptHelpers.addMessage;
        addTranscriptItem = transcriptHelpers.addTranscriptItem;
        updateTranscriptItem = transcriptHelpers.updateTranscriptItem;
        appendTranscriptItem = transcriptHelpers.appendTranscriptItem;
        
        # ========== API Calls ==========
        
        # Fetch ephemeral key from backend for OpenAI Realtime API
        async def fetchEphemeralKey() -> any {
            try {
                result = await getSessionToken();
                console.log("Session response:", result);
                
                if result.success {
                    return result.key;
                }
                
                console.error("Error fetching session:", result.error);
                return None;
            } except Exception as e {
                console.error("Error fetching ephemeral key:", e);
                return None;
            }
        }
        
        # ========== Supervisor Tool ==========
        
        # Execute supervisor tool - called by the Chat Agent
        async def executeSupervisorTool(input: any, details: any) -> any {
            context = input.relevantContextFromLastUserMessage or "";
            history = details.context.history or [];

            filteredHistory = history.filter(lambda log: any -> bool { return log.type == "message"; });

            console.log("Calling supervisor with context:", context);
            
            username = getUsernameFromToken();
            console.log("Using username:", username);

            result = await callSupervisor(context, filteredHistory, username);
            console.log("Supervisor result:", result);

            if not result.success {
                console.error("Supervisor error:", result.error);
                return {"error": "Something went wrong."};
            }

            # Fetch updated graph state after supervisor completes
            await refreshGraphState(username);
            
            # Update suggestions if available
            if result.suggestions and Array.isArray(result.suggestions) {
                setSuggestions(result.suggestions);
            } else {
                setSuggestions([]);
            }

            # Get response from service result
            next_resp = result.response or "I apologize, I couldn't get a response.";
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
        
        # ========== Session Event Listeners ==========
        
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
        
        # ========== Connection Management ==========
        
        # Connect to OpenAI Realtime API with multi-agent setup
        async def connectToRealtime() -> None {
            if sessionStatus != "DISCONNECTED" {
                return;
            }
            
            sessionStatus = "CONNECTING";
            
            try {
                if not window.isSecureContext {
                    addMessage("error", "Microphone requires secure context. Access via http://localhost:8000");
                    sessionStatus = "DISCONNECTED";
                    return;
                }
                
                if not navigator.mediaDevices {
                    addMessage("error", "MediaDevices API not available.");
                    sessionStatus = "DISCONNECTED";
                    return;
                }
                
                api_key = await fetchEphemeralKey();
                
                if not api_key {
                    console.error("No ephemeral key received");
                    sessionStatus = "DISCONNECTED";
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
                sessionStatus = "CONNECTED";

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
                sessionStatus = "DISCONNECTED";
            }
        }
        
        # Disconnect from OpenAI Realtime API
        def disconnectFromRealtime(resetPTTState: any) -> None {
            if sessionRef.current {
                console.log("Disconnecting session...");
                sessionRef.current.close();
                sessionRef.current = None;
            }
            sessionStatus = "DISCONNECTED";
            if resetPTTState {
                resetPTTState();
            }
        }
        
        # Toggle connection state
        def onToggleConnection(resetPTTState: any) -> None {
            if sessionStatus == "CONNECTED" or sessionStatus == "CONNECTING" {
                disconnectFromRealtime(resetPTTState);
            } else {
                connectToRealtime();
            }
        }
        
        # Send message via realtime session
        def sendRealtimeMessage(message: str) -> bool {
            if sessionRef.current and sessionStatus == "CONNECTED" {
                try {
                    sessionRef.current.sendMessage(message);
                    return True;
                } except Exception as e {
                    console.error("Failed to send via realtime:", e);
                    return False;
                }
            }
            return False;
        }
        
        return {
            # State
            "sessionStatus": sessionStatus,
            "sessionRef": sessionRef,
            
            # Computed
            "isConnected": isConnected,
            "isConnecting": isConnecting,
            
            # Handlers
            "connectToRealtime": connectToRealtime,
            "disconnectFromRealtime": disconnectFromRealtime,
        "onToggleConnection": onToggleConnection,
        "sendRealtimeMessage": sendRealtimeMessage
    };
}