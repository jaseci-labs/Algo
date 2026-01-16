# useMainApp Hook
# Main orchestrator hook that composes all sub-hooks
# Provides a unified interface for the MainApp component

import from react { useState, useEffect, useRef }
import from "@jac-client/utils" { useNavigate }

# Import sub-hooks
import from .useTranscript { useTranscript }
import from .useGraph { useGraph }
import from .useRealtimeSession { useRealtimeSession }
import from .useAudioControls { useAudioControls }

# Import services
import from ..service.mainAppService {
    callSupervisor,
    saveRoutine,
    getUsernameFromToken
}

def:pub useMainApp() -> any {
    navigate = useNavigate();
    
    # ========== Local State ==========
    
    # User input state
    [userText, setUserText] = useState("");
    
    # Suggestions state
    [suggestions, setSuggestions] = useState([]);
    
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
    lastTask = graphHook.lastTask;
    refreshGraphState = graphHook.refreshGraphState;
    handleClearGraph = graphHook.handleClearGraph;
    
    # Realtime session management (pass setSuggestions)
    sessionHook = useRealtimeSession(transcriptHelpers, refreshGraphState, setSuggestions);
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
    
    # Wrap setUserText to clear suggestions when user starts typing
    def handleUserTextChange(newText: str) -> None {
        setUserText(newText);
        # Clear suggestions if user is typing (not empty)
        if newText and suggestions.length > 0 {
            setSuggestions([]);
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
        
        setUserText("");
        setSuggestions([]);  # Clear suggestions when sending
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
            
            console.log("Calling supervisor with message:", message, "username:", username);
            result = await callSupervisor(message, [], username);
            console.log("Supervisor result:", result);
            console.log("Supervisor result.thinking:", result.thinking);
            
            if result.success {
                # Pass thinking data if available
                thinkingData = None;
                if result.thinking {
                    console.log("Found thinking data:", result.thinking);
                    thinkingData = result.thinking;
                }
                console.log("Updating transcript with thinking:", thinkingData);
                updateTranscriptItem(assistantItemId, result.response, thinkingData);
                await refreshGraphState(username);
                
                # Update suggestions if available
                if result.suggestions and Array.isArray(result.suggestions) {
                    setSuggestions(result.suggestions);
                } else {
                    setSuggestions([]);
                }
            } else {
                updateTranscriptItem(assistantItemId, "Error: " + (result.error or "Unknown error"));
                setSuggestions([]);
            }
        } except Exception as e {
            console.error("Text chat error:", e);
            addMessage("system", "Error: Failed to get response");
            setSuggestions([]);
        }
    }
    
    # Handle suggestion click - auto-send the suggestion
    async def handleSuggestionClick(suggestionText: str) -> None {
        setUserText(suggestionText);
        setSuggestions([]);  # Clear suggestions immediately
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
            
            result = await callSupervisor(suggestionText, [], username);
            console.log("Suggestion result:", result);
            console.log("Suggestion result.thinking:", result.thinking);
            
            if result.success {
                # Pass thinking data if available
                thinkingData = None;
                if result.thinking {
                    console.log("Found thinking data from suggestion:", result.thinking);
                    thinkingData = result.thinking;
                }
                console.log("Updating transcript with thinking:", thinkingData);
                updateTranscriptItem(assistantItemId, result.response, thinkingData);
                await refreshGraphState(username);
                
                # Update suggestions if available
                if result.suggestions and Array.isArray(result.suggestions) {
                    setSuggestions(result.suggestions);
                } else {
                    setSuggestions([]);
                }
            } else {
                updateTranscriptItem(assistantItemId, "Error: " + (result.error or "Unknown error"));
                setSuggestions([]);
            }
        } except Exception as e {
            console.error("Suggestion click error:", e);
            addMessage("system", "Error: Failed to get response");
            setSuggestions([]);
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
            console.log("Save routine response:", result);
            
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
    
    # Auto-scroll to bottom when transcript changes
    useEffect(
        lambda -> None {
            if transcriptEndRef.current {
                transcriptEndRef.current.scrollIntoView({"behavior": "smooth"});
            }
        },
        [transcript]
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
        "setUserText": handleUserTextChange,  # Use wrapped version
        "transcript": transcript,
        "graphDotCode": graphDotCode,
        "graphEdges": graphEdges,
        "lastTask": lastTask,
        "suggestions": suggestions,
        "setSuggestions": setSuggestions,
        
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