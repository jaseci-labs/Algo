# MainApp Component (UI Only)
# Pure presentation component - all business logic extracted to useMainApp hook

import from react { Fragment, useState, useRef, useEffect, useCallback }
import from "lucide-react" { MessageSquare, BarChart3, Trash2 }

import from ..components.TranscriptItem { TranscriptItem }
import from ..components.Header { Header }
import from ..components.MessageInput { MessageInput }
import from ..components.FloatingControlBar { FloatingControlBar }
import from ..components.GraphViewer { GraphViewer }
import from ..components.Layout { Layout }

import from ..hooks.useMainApp { useMainApp }
import from ..hooks.useTheme { useTheme }

import from ..utils.mergeCls { cn }

# ============================================
# Main Application Component
# ============================================

def:pub MainApp() -> any {

    # Theme management
    theme = useTheme();
    isDarkMode = theme.isDarkMode;
    toggleTheme = theme.toggleTheme;

    # Floating control bar visibility state
    [isControlBarVisible, setIsControlBarVisible] = useState(False);
    hideTimerRef = useRef(None);

    # Auto-hide timer logic
    def clearHideTimer() -> None {
        if hideTimerRef.current {
            clearTimeout(hideTimerRef.current);
            hideTimerRef.current = None;
        }
    }

    def startHideTimer() -> None {
        clearHideTimer();
        hideTimerRef.current = setTimeout(
            lambda -> None { setIsControlBarVisible(False); },
            3000
        );
    }

    # Control bar show/hide handlers
    handleShowControlBar = useCallback(
        lambda -> None {
            clearHideTimer();
            setIsControlBarVisible(True);
            startHideTimer();
        },
        []
    );

    handleHideControlBar = useCallback(
        lambda -> None {
            startHideTimer();
        },
        []
    );

    handleControlBarMouseEnter = useCallback(
        lambda -> None {
            clearHideTimer();
        },
        []
    );

    handleControlBarMouseLeave = useCallback(
        lambda -> None {
            startHideTimer();
        },
        []
    );

    # Cleanup timer on unmount
    useEffect(
        lambda -> any {
            return lambda -> None { clearHideTimer(); };
        },
        []
    );
    # Thinking insights toggle state (local to UI) - using new has syntax
    has showThinking: bool = True;

    def toggleThinking() -> None {
        showThinking = not showThinking;
    }

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
    suggestions = hook.suggestions;
    graphEdges = hook.graphEdges;

    # Handlers
    onToggleConnection = hook.onToggleConnection;
    toggleMicMute = hook.toggleMicMute;
    handleTalkButtonDown = hook.handleTalkButtonDown;
    handleTalkButtonUp = hook.handleTalkButtonUp;
    handleSendTextMessage = hook.handleSendTextMessage;
    handleSuggestionClick = hook.handleSuggestionClick;
    handleClearGraph = hook.handleClearGraph;
    handleSaveAndRestart = hook.handleSaveAndRestart;

    # Toggle audio playback handler
    def handleToggleAudioPlayback() -> None {
        setIsAudioPlaybackEnabled(not isAudioPlaybackEnabled);
    }
    # Build transcript items
    transcriptItems = transcript.map(lambda item: any, idx: int -> any {
        return <TranscriptItem key={idx} item={item} showThinking={showThinking} />;
    });
    
    # ========== Render ==========
    return <Layout meta={{"title": "Dashboard | Algo", "description": "Your AI assistant dashboard with voice interface"}}>
        <div className="flex flex-col h-screen bg-background">
            <Header isDarkMode={isDarkMode} onToggleTheme={toggleTheme} />

            <div className="flex-1 flex gap-4 p-4 overflow-hidden">
                <div className="w-1/2">
                    <TranscriptPanel
                    transcriptItems={transcriptItems}
                    suggestions={suggestions}
                    onSelectSuggestion={handleSuggestionClick}

                    transcriptItems={transcriptItems}
                    transcriptEndRef={transcriptEndRef}
                    userText={userText}
                    setUserText={setUserText}
                    onSend={handleSendTextMessage}
                    sessionStatus={sessionStatus}
                    onToggleConnection={onToggleConnection}
                    onShowControlBar={handleShowControlBar}
                    onHideControlBar={handleHideControlBar}
                    />
                </div>

                <div className="w-1/2">
                        <GraphPanel
                        graphEdges={graphEdges}
                        onClearGraph={handleClearGraph}
                    />
                </div>
            </div>
            
            <FloatingControlBar
                isPTTActive={isPTTActive}
                setIsPTTActive={setIsPTTActive}
                setIsAudioPlaybackEnabled={setIsAudioPlaybackEnabled}
                

                isVisible={isControlBarVisible}
                sessionStatus={sessionStatus}
                isMicMuted={isMicMuted}
                onToggleMicMute={toggleMicMute}
                isAudioPlaybackEnabled={isAudioPlaybackEnabled}
                onToggleAudioPlayback={handleToggleAudioPlayback}
                isPTTUserSpeaking={isPTTUserSpeaking}
                onTalkDown={handleTalkButtonDown}
                onTalkUp={handleTalkButtonUp}
                onSaveAndRestart={handleSaveAndRestart}
                onMouseEnter={handleControlBarMouseEnter}
                onMouseLeave={handleControlBarMouseLeave}
            />
        </div>
    </Layout>;
}

# ============================================
# Sub-Components (Presentational)
# ============================================

# Transcript Panel - left side showing conversation
def TranscriptPanel(
    transcriptItems: any,
    transcriptEndRef: any,
    userText: str,
    setUserText: any,
    onSend: any,
    suggestions: list,
    onSelectSuggestion: any,
    sessionStatus: str,
    onToggleConnection: any,
    onShowControlBar: any,
    onHideControlBar: any
) -> any {
    return <div className="glass-panel flex flex-col h-full">
        <div className="flex items-center gap-2 px-5 py-4 border-b border-border/30 text-sm font-semibold text-foreground">
            <MessageSquare className="w-5 h-5 text-primary" />
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
            suggestions={suggestions}
            onSelectSuggestion={onSelectSuggestion}
            sessionStatus={sessionStatus}
            onToggleConnection={onToggleConnection}
            onShowControlBar={onShowControlBar}
            onHideControlBar={onHideControlBar}
        />
    </div>;
}

# Graph Panel - right side showing task visualization
def GraphPanel(graphEdges: str, onClearGraph: any) -> any {
    return <div className="glass-panel flex flex-col h-full">
        <div className="flex items-center justify-between px-5 py-4 border-b border-border/30">
            <div className="flex items-center gap-2">
                <BarChart3 className="w-4 h-4 text-primary" />
                <h2 className="text-sm font-semibold text-foreground">{"Task Graph"}</h2>
            </div>
            <span className="text-xs text-muted-foreground">
                {"Real-time visualization"}
            </span>
        </div>

        <div className="flex-1 overflow-hidden bg-background relative rounded-[0.75rem]">
            <GraphViewer graphEdges={graphEdges} />

            <ClearGraphButton onClick={onClearGraph} />
        </div>
    </div>;
}


# Clear Graph Button
def ClearGraphButton(onClick: any) -> any {
    return <button
        onClick={onClick}
        className="absolute bottom-4 right-4 flex items-center gap-2 px-3 py-2 bg-destructive/10 text-destructive rounded-lg text-xs font-medium hover:bg-destructive/20 transition-colors"
    >
        <Trash2 className="w-3.5 h-3.5" />
        {"Clear Graph"}
    </button>;
}