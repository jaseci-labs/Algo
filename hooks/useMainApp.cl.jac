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
    getUsernameFromToken
}

def:pub useMainApp() -> any {
    navigate = useNavigate();

    # ========== Local State ==========
    # Reactive state using has variables
    has userText: str = "";
    has suggestions: list = [];

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
    graphDotCode = graphHook.graphDotCode;
    graphEdges = graphHook.graphEdges;
    displayEdges = graphHook.displayEdges;
    # Don't cache lastTask - always read from graphHook to get fresh value
    isGraphProcessing = graphHook.isProcessing;
    graphProcessingMessage = graphHook.processingMessage;
    refreshGraphState = graphHook.refreshGraphState;
    addPendingNodes = graphHook.addPendingNodes;
    handleClearGraph = graphHook.handleClearGraph;
    
    # Create a setter function wrapper for suggestions to pass to child hooks
    def updateSuggestions(newSuggestions: list) -> None {
        suggestions = newSuggestions;
    }

    # Realtime session management (pass updateSuggestions, addPendingNodes, lastTask getter)
    # Pass a function that returns fresh lastTask value instead of stale value
    def getLastTask() -> str {
        return graphHook.lastTask;
    }
    sessionHook = useRealtimeSession(transcriptHelpers, refreshGraphState, updateSuggestions, addPendingNodes, getLastTask);
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
        suggestions = [];  # Clear suggestions when sending
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
            console.log("[useMainApp] callManager result:", result);
            if result.success {
                # Add pending nodes for incremental update
                # IMPORTANT: Read lastTask fresh from graphHook to avoid closure stale values
                currentLastTask = graphHook.lastTask;
                console.log("[useMainApp] currentLastTask from graphHook:", currentLastTask);
                if result.task_names and Array.isArray(result.task_names) and result.task_names.length > 0 {
                    console.log("[useMainApp] Adding pending nodes (text mode):", result.task_names, "fromTask:", currentLastTask);
                    addPendingNodes(result.task_names, currentLastTask);
                } else {
                    console.log("[useMainApp] No task_names in result:", result);
                }

                # Pass thinking data if available
                thinkingData = None;
                if result.thinking {
                    thinkingData = result.thinking;
                }
                updateTranscriptItem(assistantItemId, result.response, thinkingData);

                # Delay graph refresh to show "adding..." state
                # The pending state will be cleared in refreshGraphState after 500ms
                setTimeout(lambda -> None {
                    refreshGraphState(username);
                }, 800);

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
        suggestions = [];  # Clear suggestions immediately
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
                # Add pending nodes for incremental update
                currentLastTask = graphHook.lastTask;
                if result.task_names and Array.isArray(result.task_names) and result.task_names.length > 0 {
                    console.log("[useMainApp] Adding pending nodes (suggestion):", result.task_names, "fromTask:", currentLastTask);
                    addPendingNodes(result.task_names, currentLastTask);
                }

                # Pass thinking data if available
                thinkingData = None;
                if result.thinking {
                    thinkingData = result.thinking;
                }
                updateTranscriptItem(assistantItemId, result.response, thinkingData);

                # Delay graph refresh to show "adding..." state
                setTimeout(lambda -> None {
                    refreshGraphState(username);
                }, 800);

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
        "displayEdges": displayEdges,
        "lastTask": graphHook.lastTask,  # Read fresh from graphHook
        "suggestions": suggestions,

        # Graph processing state
        "isGraphProcessing": isGraphProcessing,
        "graphProcessingMessage": graphProcessingMessage,

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