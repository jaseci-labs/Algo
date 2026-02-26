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
    saveRoutine,
    getTaskGraph,
    clearTaskGraph,
    getUsernameFromToken
}

def:pub useMainApp() -> any {
    navigate = useNavigate();

    # ========== Local State ==========
    # Reactive state using has variables
    has userText: str = "";
    has suggestions: list = [];
    has graphEdges: list = [];
    has graphDotCode: str = "";
    has lastTask: str = "Start";

    # Ref for auto-scroll
    transcriptEndRef = useRef(None);

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

    # Clear the task graph and update local state
    async def handleClearGraph() -> None {
        try {
            username = getUsernameFromToken();
            result = await clearTaskGraph(username);

            if result.success {
                updateGraphFromState(result.data);
                addMessage("system", "Graph cleared! Starting fresh.");
            } else {
                addMessage("error", "Failed to clear graph");
            }
        } except Exception as e {
            console.error("Clear graph error:", e);
            addMessage("error", "Error clearing graph");
        }
    }

    # Update graph from a graphState object (from callManager response or API call)
    def updateGraphFromState(graphState: any) -> None {
        if graphState {
            graphEdges = Array.from(graphState.edges or []);
            graphDotCode = graphState.dotCode or "";
            lastTask = graphState.lastTask or "Start";
        }
    }

    # Simple wrapper for explicit graph refreshes (e.g., after clear, or on mount)
    async def refreshGraphState(username: str) -> None {
        result = await getTaskGraph(username);
        if result.success and result.data {
            updateGraphFromState(result.data);
        }
    }

    # Create a setter function wrapper for suggestions to pass to child hooks
    def updateSuggestions(newSuggestions: list) -> None {
        suggestions = newSuggestions;
    }

    # Realtime session management (pass updateGraphFromState for voice mode)
    sessionHook = useRealtimeSession(transcriptHelpers, refreshGraphState, updateGraphFromState, updateSuggestions);
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
        suggestions = [];
        addMessage("user", message);

        username = getUsernameFromToken();

        # If connected to realtime session, send via voice
        if sendRealtimeMessage(message) {
            return;
        }

        # Text-only mode: call supervisor directly using service layer
        try {
            assistantItemId = "assistant-" + String(Date.now());
            addTranscriptItem(assistantItemId, "assistant", "Thinking...");

            result = await callManager(message, [], username);
            if result.success {
                # Pass thinking data if available
                thinkingData = None;
                if result.thinking {
                    thinkingData = result.thinking;
                }
                updateTranscriptItem(assistantItemId, result.response, thinkingData);

                # Update graph directly from response (no separate API call)
                if result.graphState {
                    updateGraphFromState(result.graphState);
                }

                # Update suggestions if available
                if result.suggestions and Array.isArray(result.suggestions) {
                    suggestions = result.suggestions;
                } else {
                    suggestions = [];
                }
            } else {
                updateTranscriptItem(assistantItemId, "Error: " + (result.error or "Unknown error"));
                suggestions = [];
            }
        } except Exception as e {
            console.error("Text chat error:", e);
            addMessage("system", "Error: Failed to get response");
            suggestions = [];
        }
    }

    # Handle suggestion click - auto-send the suggestion
    async def handleSuggestionClick(suggestionText: str) -> None {
        userText = suggestionText;
        suggestions = [];
        addMessage("user", suggestionText);

        username = getUsernameFromToken();

        # If connected to realtime session, send via voice
        if sendRealtimeMessage(suggestionText) {
            return;
        }

        # Text-only mode: call supervisor
        try {
            assistantItemId = "assistant-" + String(Date.now());
            addTranscriptItem(assistantItemId, "assistant", "Thinking...");

            result = await callManager(suggestionText, [], username);
            if result.success {
                # Pass thinking data if available
                thinkingData = None;
                if result.thinking {
                    thinkingData = result.thinking;
                }
                updateTranscriptItem(assistantItemId, result.response, thinkingData);

                # Update graph directly from response
                if result.graphState {
                    updateGraphFromState(result.graphState);
                }

                # Update suggestions if available
                if result.suggestions and Array.isArray(result.suggestions) {
                    suggestions = result.suggestions;
                } else {
                    suggestions = [];
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

        username = getUsernameFromToken();
        result = await saveRoutine("daily_routine", username);

        if result.success {
            addMessage("system", "Routine saved! Starting fresh session...");
            handleClearGraph();
        } else {
            addMessage("error", "Failed to save routine: " + (result.error or "Unknown error"));
        }
    }

    # ========== Effects ==========

    # Auto-scroll to bottom when transcript changes
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
        "setUserText": handleUserTextChange,
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
