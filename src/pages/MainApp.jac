# MainApp Component (UI Only)
# Pure presentation component - all business logic extracted to useMainApp hook

cl import from react { Fragment }

cl import from ..components.TranscriptItem { TranscriptItem }
cl import from ..components.Header { Header }
cl import from ..components.MessageInput { MessageInput }
cl import from ..components.ControlBar { ControlBar }
cl import from ..components.GraphViewer { GraphViewer }

cl import from ..hooks.useMainApp { useMainApp }

# ============================================
# Main Application Component
# ============================================

cl {
    def:pub MainApp() -> any {
        # Get all state and handlers from the hook
        hook = useMainApp();
        
        # Destructure hook values for cleaner access
        sessionStatus = hook.sessionStatus;
        isPTTActive = hook.isPTTActive;
        setIsPTTActive = hook.setIsPTTActive;
        isPTTUserSpeaking = hook.isPTTUserSpeaking;
        isAudioPlaybackEnabled = hook.isAudioPlaybackEnabled;
        setIsAudioPlaybackEnabled = hook.setIsAudioPlaybackEnabled;
        isMicMuted = hook.isMicMuted;
        userText = hook.userText;
        setUserText = hook.setUserText;
        transcript = hook.transcript;
        graphDotCode = hook.graphDotCode;
        transcriptEndRef = hook.transcriptEndRef;
        
        # Handlers
        onToggleConnection = hook.onToggleConnection;
        toggleMicMute = hook.toggleMicMute;
        handleTalkButtonDown = hook.handleTalkButtonDown;
        handleTalkButtonUp = hook.handleTalkButtonUp;
        handleSendTextMessage = hook.handleSendTextMessage;
        handleClearGraph = hook.handleClearGraph;
        handleSaveAndRestart = hook.handleSaveAndRestart;
        
        # Build transcript items
        transcriptItems = [];
        idx = 0;
        for item in transcript {
            transcriptItems.push(<TranscriptItem key={idx} item={item} />);
            idx = idx + 1;
        }
        
        # ========== Render ==========
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
                <TranscriptPanel 
                    transcriptItems={transcriptItems}
                    transcriptEndRef={transcriptEndRef}
                    userText={userText}
                    setUserText={setUserText}
                    onSend={handleSendTextMessage}
                />
                
                <GraphPanel 
                    graphDotCode={graphDotCode}
                    onClearGraph={handleClearGraph}
                />
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
}

# ============================================
# Sub-Components (Presentational)
# ============================================

cl {
    # Transcript Panel - left side showing conversation
    def TranscriptPanel(
        transcriptItems: any,
        transcriptEndRef: any,
        userText: str,
        setUserText: any,
        onSend: any
    ) -> any {
        return <div style={{
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
                onSend={onSend}
            />
        </div>;
    }
    
    # Graph Panel - right side showing task visualization
    def GraphPanel(graphDotCode: str, onClearGraph: any) -> any {
        return <div style={{
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
                
                <ClearGraphButton onClick={onClearGraph} />
            </div>
        </div>;
    }
    
    # Clear Graph Button
    def ClearGraphButton(onClick: any) -> any {
        return <button
            onClick={onClick}
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
        </button>;
    }
}
