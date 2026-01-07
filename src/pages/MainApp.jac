# MainApp Component (UI Only)
# Pure presentation component - all business logic extracted to useMainApp hook

cl import from react { Fragment }

cl import from ..components.TranscriptItem { TranscriptItem }
cl import from ..components.Header { Header }
cl import from ..components.MessageInput { MessageInput }
cl import from ..components.ControlBar { ControlBar }
cl import from ..components.GraphViewer { GraphViewer }

cl import from ..hooks.useMainApp { useMainApp }
cl import from ..utils.mergeCls { cn }

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
        return <div className="flex flex-col h-screen bg-background text-text-primary font-sans">
            <Header />
            
            <div className="flex-1 flex gap-2 p-2 overflow-hidden">
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
        return <div className="flex-1 bg-surface rounded-xl flex flex-col min-h-0 shadow-sm">
            <div className="flex items-center justify-between px-6 py-3 border-b border-border font-semibold text-text-primary">
                {"Transcript"}
            </div>
            
            <div className="flex-1 overflow-y-auto p-4 flex flex-col gap-4">
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
        return <div className="flex-1 bg-surface rounded-xl flex flex-col min-h-0 shadow-sm">
            <div className="flex items-center justify-between px-6 py-3 border-b border-border font-semibold text-text-primary">
                {"Task Graph"}
                <span className="text-xs text-text-secondary font-normal">
                    {"Real-time visualization"}
                </span>
            </div>
            
            <div className="flex-1 overflow-auto bg-surface-hover relative">
                <GraphViewer dotCode={graphDotCode} />
                
                <ClearGraphButton onClick={onClearGraph} />
            </div>
        </div>;
    }
    
    # Clear Graph Button
    def ClearGraphButton(onClick: any) -> any {
        return <button
            onClick={onClick}
            className="absolute bottom-4 right-4 px-4 py-2 bg-error text-error-foreground border-none rounded-lg cursor-pointer text-sm font-medium shadow-md transition-all hover:opacity-90 hover:-translate-y-0.5 active:translate-y-0"
        >
            {"Clear Graph"}
        </button>;
    }
}
