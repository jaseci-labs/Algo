# useRealtimeSession Hook
# Custom hook for managing OpenAI Realtime API connection and session

import from react { useRef }
import from "@openai/agents/realtime" { RealtimeAgent, RealtimeSession, tool }

import from ..constants.constants { CHAT_AGENT_INSTRUCTIONS }
import from ..api.api {
    getSessionToken,
    callManager,
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
# @param refreshGraphState - Function to refresh graph state (for initial load)
# @param updateGraphFromState - Function to update graph from callManager response
# @param setSuggestions - Function to update suggestions state in parent
def:pub useRealtimeSession(transcriptHelpers: any, refreshGraphState: any, updateGraphFromState: any, setSuggestions: any) -> any {
    # Reactive state using has variables
    has sessionStatus: str = "DISCONNECTED";

    sessionRef = useRef(None);

    # Track accumulated response text per item (for handling empty transcript in done event)
    responseAccumulatedText = useRef({});

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

            username = getUsernameFromToken();
            result = await callManager(context, filteredHistory, username);

            if not result.success {
                console.error("Supervisor error:", result.error);
                return {"error": "Something went wrong."};
            }

            # Update graph directly from response
            if result.graphState {
                updateGraphFromState(result.graphState);
            }

            # Update suggestions if available
            if result.suggestions and Array.isArray(result.suggestions) {
                setSuggestions(result.suggestions);
            } else {
                setSuggestions([]);
            }

            # Get response from service result
            next_resp = result.response or "I apologize, I couldn't get a response.";
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
                if not item {
                    return;
                }

                itemType = item.type or "";
                itemId = item.itemId or item.item_id or "";

                if itemType == "message" {
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
                } elif itemType == "function_call" {
                    toolName = item.name or "tool";
                    addTranscriptItem(itemId, "tool", "🔧 Calling: " + toolName + "...");
                }
            });
            
            # Listen for history_updated events (message updates)
            session.on("history_updated", lambda items: any -> None {
                if not items or not items.length {
                    return;
                }

                for item in items {
                    if not item {
                        continue;
                    }

                    itemType = item.type or "";
                    itemId = item.itemId or item.item_id or "";

                    if itemType == "message" {
                        role = item.role or "";
                        content = item.content or [];

                        text = extractMessageText(content);

                        if text and itemId {
                            addTranscriptItem(itemId, role, text);
                            updateTranscriptItem(itemId, text);
                        }
                    } elif itemType == "function_call" {
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
                itemId = event.item_id or "";
                eventType = event.type or "";
                transcriptText = event.transcript or "";
                deltaText = event.delta or "";

                if eventType == "conversation.item.input_audio_transcription.completed" {
                    if itemId {
                        finalText = transcriptText or "[inaudible]";
                        if finalText == "\n" {
                            finalText = "[inaudible]";
                        }
                        updateTranscriptItem(itemId, finalText);
                    }
                } elif eventType == "response.output_audio_transcript.delta" {
                    if itemId and deltaText {
                        # Initialize item on first delta
                        if not responseAccumulatedText.current[itemId] {
                            responseAccumulatedText.current[itemId] = "";
                            addTranscriptItem(itemId, "assistant", "");
                        }
                        # Accumulate and append delta
                        responseAccumulatedText.current[itemId] = responseAccumulatedText.current[itemId] + deltaText;
                        appendTranscriptItem(itemId, deltaText);
                    }
                } elif eventType == "response.output_audio_transcript.done" {
                    if itemId {
                        # Use transcript from event, or fall back to accumulated
                        finalText = transcriptText or responseAccumulatedText.current[itemId] or "";
                        if finalText {
                            updateTranscriptItem(itemId, finalText);
                        }
                    }
                }
            });
            
            # Listen for tool calls
            session.on("agent_tool_start", lambda details: any, agent: any, functionCall: any -> None {
                toolName = functionCall.name or "unknown";
                addMessage("tool", f"🔧 Calling: {toolName}...");
            });

            session.on("agent_tool_end", lambda details: any, agent: any, functionCall: any, result: any -> None {
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

                supervisorTool = createSupervisorTool();

                chatAgentConfig = {
                    "name": "chatAgent",
                    "voice": "sage",
                    "instructions": CHAT_AGENT_INSTRUCTIONS,
                    "tools": [supervisorTool]
                };
                chatAgent = Reflect.construct(RealtimeAgent, [chatAgentConfig]);

                session = Reflect.construct(RealtimeSession, [chatAgent]);

                # Set up session event listeners
                setupSessionEventListeners(session);

                await session.connect({"apiKey": api_key});

                sessionRef.current = session;
                sessionStatus = "CONNECTED";

                # Load user's existing graph when they connect
                username = getUsernameFromToken();
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