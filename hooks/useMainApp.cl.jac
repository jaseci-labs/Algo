# useMainApp Hook
# Main orchestrator hook that composes all sub-hooks
# Provides a unified interface for the MainApp component

import from react { useRef }
import from "@jac/runtime" { useNavigate }

# Import sub-hooks
import from .useTranscript { useTranscript }
import from .useGraph { useGraph }
import from .useRealtimeSession { useRealtimeSession }
import from .useAudioControls { useAudioControls }

# Import services
import from ..api.api {
    callManager,
    getQuickResponse,
    getPendingUpdates,
    saveRoutine,
    getUsernameFromToken
}

def:pub useMainApp() -> any {
    navigate = useNavigate();

    # ========== Local State ==========
    # Reactive state using has variables
    has userText: str = "";
    has suggestions: list = [];

    # Ref for auto-scroll and graph update polling
    transcriptEndRef = useRef(None);
    graphUpdatePollRef = useRef(None);
    lastGraphUpdateIdRef = useRef(0);
    
    # ========== Compose Sub-Hooks ==========
    
    # Transcript management
    transcriptHook = useTranscript();
    transcript = transcriptHook.transcript;
    addMessage = transcriptHook.addMessage;
    addTranscriptItem = transcriptHook.addTranscriptItem;
    updateTranscriptItem = transcriptHook.updateTranscriptItem;
    appendTranscriptItem = transcriptHook.appendTranscriptItem;
    clearTranscript = transcriptHook.clearTranscript;
    
    # Create transcript helpers object for other hooks
    transcriptHelpers = {
        "addMessage": addMessage,
        "addTranscriptItem": addTranscriptItem,
        "updateTranscriptItem": updateTranscriptItem,
        "appendTranscriptItem": appendTranscriptItem
    };
    
    # Graph state management
    graphHook = useGraph(addMessage);
    graphDotCode = graphHook.graphDotCode;
    graphEdges = graphHook.graphEdges;
    lastTask = graphHook.lastTask;
    refreshGraphState = graphHook.refreshGraphState;
    handleClearGraph = graphHook.handleClearGraph;

    # Create a setter function wrapper for suggestions to pass to child hooks
    def updateSuggestions(newSuggestions: list) -> None {
        suggestions = newSuggestions;
    }

    # Realtime session management (pass updateSuggestions and poll function)
    sessionHook = useRealtimeSession(transcriptHelpers, refreshGraphState, updateSuggestions, startGraphUpdatePoll);
    sessionStatus = sessionHook.sessionStatus;
    sessionRef = sessionHook.sessionRef;
    isConnected = sessionHook.isConnected;
    isConnecting = sessionHook.isConnecting;
    sendRealtimeMessage = sessionHook.sendRealtimeMessage;
    
    # Audio controls
    audioHook = useAudioControls(sessionRef, sessionStatus);
    isPTTActive = audioHook.isPTTActive;
    setIsPTTActive = audioHook.setIsPTTActive;
    isPTTUserSpeaking = audioHook.isPTTUserSpeaking;
    isAudioPlaybackEnabled = audioHook.isAudioPlaybackEnabled;
    setIsAudioPlaybackEnabled = audioHook.setIsAudioPlaybackEnabled;
    isMicMuted = audioHook.isMicMuted;
    toggleMicMute = audioHook.toggleMicMute;
    handleTalkButtonDown = audioHook.handleTalkButtonDown;
    handleTalkButtonUp = audioHook.handleTalkButtonUp;
    resetPTTState = audioHook.resetPTTState;
    
    # ========== Enhanced State Setters ==========

    # Wrap userText change to clear suggestions when user starts typing
    def handleUserTextChange(newText: str) -> None {
        userText = newText;
        # Clear suggestions if user is typing (not empty)
        if newText and suggestions.length > 0 {
            suggestions = [];
        }
    }

    # Start polling for graph updates after quick response
    def startGraphUpdatePoll() -> None {
        # Clear any existing interval
        if graphUpdatePollRef.current {
            clearInterval(graphUpdatePollRef.current);
        }

        # Increment update ID
        lastGraphUpdateIdRef.current = lastGraphUpdateIdRef.current + 1;
        currentUpdateId = lastGraphUpdateIdRef.current;
        username = getUsernameFromToken();

        # Poll every 1 second, max 10 attempts
        attempts = 0;
        graphUpdatePollRef.current = setInterval(lambda -> None {
            attempts = attempts + 1;
            if attempts > 10 {
                clearInterval(graphUpdatePollRef.current);
                graphUpdatePollRef.current = None;
                return;
            }

            # Check if this poll is still valid (not superseded by newer update)
            if currentUpdateId != lastGraphUpdateIdRef.current {
                clearInterval(graphUpdatePollRef.current);
                return;
            }

            # Async refresh
            async def doCheck() -> None {
                result = await getPendingUpdates(username);
                if result.success and not result.update_in_progress {
                    clearInterval(graphUpdatePollRef.current);
                    graphUpdatePollRef.current = None;
                    await refreshGraphState(username);
                }
            }
            doCheck();
        }, 1000);
    }

    # ========== Connection Handlers ==========
    
    def onToggleConnection() -> None {
        sessionHook.onToggleConnection(resetPTTState);
    }
    
    # ========== Message Handling ==========
    
    # Send text message (text-only chat or via voice session)
    async def handleSendTextMessage() -> None {
        message = userText.trim();
        if not message {
            return;
        }

        userText = "";
        suggestions = [];  # Clear suggestions when sending
        addMessage("user", message);

        username = getUsernameFromToken();

        # If connected to realtime session, send via voice
        if sendRealtimeMessage(message) {
            return;
        }

        # Text-only mode: use fast response
        try {
            assistantItemId = "assistant-" + String(Date.now());
            addTranscriptItem(assistantItemId, "assistant", "Thinking...");

            result = await getQuickResponse(message, [], username);
            if result.success {
                thinkingData = result.thinking if result.thinking else {};
                updateTranscriptItem(assistantItemId, result.response, thinkingData);
                # Start polling for graph update
                startGraphUpdatePoll();
            } else {
                updateTranscriptItem(assistantItemId, "Error: " + (result.error or "Unknown error"));
                suggestions = [];
            }
        } catch {
            console.error("Text chat error");
            addMessage("system", "Error: Failed to get response");
            suggestions = [];
        }
    }
    
    # Handle suggestion click - auto-send the suggestion
    async def handleSuggestionClick(suggestionText: str) -> None {
        userText = suggestionText;
        suggestions = [];  # Clear suggestions immediately
        addMessage("user", suggestionText);

        username = getUsernameFromToken();

        # If connected to realtime session, send via voice
        if sendRealtimeMessage(suggestionText) {
            return;
        }

        # Text-only mode: use fast response
        try {
            assistantItemId = "assistant-" + String(Date.now());
            addTranscriptItem(assistantItemId, "assistant", "Thinking...");

            result = await getQuickResponse(suggestionText, [], username);
            if result.success {
                thinkingData = result.thinking if result.thinking else {};
                updateTranscriptItem(assistantItemId, result.response, thinkingData);

                # Smart polling for graph updates
                maxAttempts = 20;
                attempt = 0;
                while attempt < maxAttempts {
                    await std.sleep(500);
                    await refreshGraphState(username);

                    updatesResult = await getPendingUpdates(username);
                    if updatesResult.success {
                        if updatesResult.suggestions and Array.isArray(updatesResult.suggestions) {
                            suggestions = updatesResult.suggestions;
                        }
                        if not updatesResult.update_in_progress {
                            break;
                        }
                    }
                    attempt = attempt + 1;
                }
            } else {
                updateTranscriptItem(assistantItemId, "Error: " + (result.error or "Unknown error"));
                suggestions = [];
            }
        } except Exception as e {
            console.error("Suggestion click error:", e);
            addMessage("system", "Error: Failed to get response");
            suggestions = [];
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

            result = await saveRoutine("daily_routine", username);

            if result.success {
                addMessage("system", "Routine saved! Restarting session...");
                
                clearTranscript();
                
                setTimeout(lambda -> None {
                    addMessage("assistant", "Welcome back! I remember your routine. How can I help you today?");
                }, 500);
            } else {
                addMessage("error", "Failed to save routine: " + (result.error or "Unknown error"));
            }
        } except Exception as e {
            console.error("Save and restart error:", e);
            addMessage("error", "Error during save and restart");
        }
    }
    
    # ========== Effects ==========

    # Auto-scroll to bottom when transcript changes - using new can with [dep] entry syntax
    can with [transcript] entry {
        if transcriptEndRef.current {
            transcriptEndRef.current.scrollIntoView({"behavior": "smooth"});
        }
    }
    
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
        "setUserText": handleUserTextChange,  # Use wrapped version
        "transcript": transcript,
        "graphDotCode": graphDotCode,
        "graphEdges": graphEdges,
        "lastTask": lastTask,
        "suggestions": suggestions,

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
        "handleSuggestionClick": handleSuggestionClick,
        "handleClearGraph": handleClearGraph,
        "handleSaveAndRestart": handleSaveAndRestart
    };
}