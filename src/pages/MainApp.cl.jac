# MainApp Component (UI Only)
# Pure presentation component - all business logic extracted to useMainApp hook

import from react { useState, useRef, useEffect, useCallback }
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
    # Get all state and handlers from the hook
    hook = useMainApp();

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
    graphEdges = hook.graphEdges;
    transcriptEndRef = hook.transcriptEndRef;

    # Handlers
    onToggleConnection = hook.onToggleConnection;
    toggleMicMute = hook.toggleMicMute;
    handleTalkButtonDown = hook.handleTalkButtonDown;
    handleTalkButtonUp = hook.handleTalkButtonUp;
    handleSendTextMessage = hook.handleSendTextMessage;
    handleClearGraph = hook.handleClearGraph;
    handleSaveAndRestart = hook.handleSaveAndRestart;

    # Toggle audio playback handler
    def handleToggleAudioPlayback() -> None {
        setIsAudioPlaybackEnabled(not isAudioPlaybackEnabled);
    }

    # Build transcript items
    transcriptItems = [];
    idx = 0;
    for item in transcript {
        transcriptItems.push(<TranscriptItem key={idx} item={item} />);
        idx = idx + 1;
    }

    # ========== Render ==========
    return <Layout meta={{"title": "Dashboard | Algo", "description": "Your AI assistant dashboard with voice interface"}}>
        <div className="flex flex-col h-screen bg-background">
            <Header isDarkMode={isDarkMode} onToggleTheme={toggleTheme} />

            <div className="flex-1 flex gap-2 p-2 overflow-hidden">
                <TranscriptPanel
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

                <GraphPanel
                    graphEdges={graphEdges}
                    onClearGraph={handleClearGraph}
                />
            </div>

            <FloatingControlBar
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
    sessionStatus: str,
    onToggleConnection: any,
    onShowControlBar: any,
    onHideControlBar: any
) -> any {
    return <div className="w-1/2 bg-surface rounded-xl flex flex-col min-h-0 shadow-sm">
        <div className="flex items-center gap-2 px-6 py-3 border-b border-border font-semibold text-text-primary">
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
            sessionStatus={sessionStatus}
            onToggleConnection={onToggleConnection}
            onShowControlBar={onShowControlBar}
            onHideControlBar={onHideControlBar}
        />
    </div>;
}

# Graph Panel - right side showing task visualization
def GraphPanel(graphEdges: str, onClearGraph: any) -> any {
    return <div className="w-1/2 bg-surface rounded-xl flex flex-col min-h-0 shadow-sm">
        <div className="flex items-center justify-between px-6 py-3 border-b border-border font-semibold text-text-primary">
            <div className="flex items-center gap-2">
                <BarChart3 className="w-5 h-5 text-primary" />
                {"Task Graph"}
            </div>
            <span className="text-xs text-text-secondary font-normal">
                {"Real-time visualization"}
            </span>
        </div>

        <div className="flex-1 overflow-hidden bg-graph-bg relative">
            <GraphViewer graphEdges={graphEdges} />

            <ClearGraphButton onClick={onClearGraph} />
        </div>
    </div>;
}

# Clear Graph Button
def ClearGraphButton(onClick: any) -> any {
    return <button
        onClick={onClick}
        className="absolute bottom-4 right-4 px-3 py-2 bg-error/90 text-error-foreground border-none rounded-lg cursor-pointer text-sm font-medium shadow-md transition-all hover:bg-error hover:-translate-y-0.5 active:translate-y-0 flex items-center gap-2"
    >
        <Trash2 className="w-4 h-4" />
        {"Clear Graph"}
    </button>;
}
