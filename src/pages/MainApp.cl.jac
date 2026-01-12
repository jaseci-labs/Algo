# MainApp Component (UI Only)
# Pure presentation component - all business logic extracted to useMainApp hook

import from react { useState, useRef, useEffect, useCallback }

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
    # Transcript icon
    transcriptIcon = <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="currentColor"
        className="w-5 h-5 text-primary"
    >
        <path fillRule="evenodd" d="M4.848 2.771A49.144 49.144 0 0112 2.25c2.43 0 4.817.178 7.152.52 1.978.292 3.348 2.024 3.348 3.97v6.02c0 1.946-1.37 3.678-3.348 3.97a48.901 48.901 0 01-3.476.383.39.39 0 00-.297.17l-2.755 4.133a.75.75 0 01-1.248 0l-2.755-4.133a.39.39 0 00-.297-.17 48.9 48.9 0 01-3.476-.384c-1.978-.29-3.348-2.024-3.348-3.97V6.741c0-1.946 1.37-3.68 3.348-3.97z" clipRule="evenodd" />
    </svg>;

    return <div className="w-1/2 bg-surface rounded-xl flex flex-col min-h-0 shadow-sm">
        <div className="flex items-center gap-2 px-6 py-3 border-b border-border font-semibold text-text-primary">
            {transcriptIcon}
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
    # Graph icon
    graphIcon = <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="currentColor"
        className="w-5 h-5 text-primary"
    >
        <path d="M18.375 2.25c-1.035 0-1.875.84-1.875 1.875v15.75c0 1.035.84 1.875 1.875 1.875h.75c1.035 0 1.875-.84 1.875-1.875V4.125c0-1.036-.84-1.875-1.875-1.875h-.75zM9.75 8.625c0-1.036.84-1.875 1.875-1.875h.75c1.036 0 1.875.84 1.875 1.875v11.25c0 1.035-.84 1.875-1.875 1.875h-.75a1.875 1.875 0 01-1.875-1.875V8.625zM3 13.125c0-1.036.84-1.875 1.875-1.875h.75c1.036 0 1.875.84 1.875 1.875v6.75c0 1.035-.84 1.875-1.875 1.875h-.75A1.875 1.875 0 013 19.875v-6.75z" />
    </svg>;

    return <div className="w-1/2 bg-surface rounded-xl flex flex-col min-h-0 shadow-sm">
        <div className="flex items-center justify-between px-6 py-3 border-b border-border font-semibold text-text-primary">
            <div className="flex items-center gap-2">
                {graphIcon}
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
    # Trash icon
    trashIcon = <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="currentColor"
        className="w-4 h-4"
    >
        <path fillRule="evenodd" d="M16.5 4.478v.227a48.816 48.816 0 013.878.512.75.75 0 11-.256 1.478l-.209-.035-1.005 13.07a3 3 0 01-2.991 2.77H8.084a3 3 0 01-2.991-2.77L4.087 6.66l-.209.035a.75.75 0 01-.256-1.478A48.567 48.567 0 017.5 4.705v-.227c0-1.564 1.213-2.9 2.816-2.951a52.662 52.662 0 013.369 0c1.603.051 2.815 1.387 2.815 2.951zm-6.136-1.452a51.196 51.196 0 013.273 0C14.39 3.05 15 3.684 15 4.478v.113a49.488 49.488 0 00-6 0v-.113c0-.794.609-1.428 1.364-1.452zm-.355 5.945a.75.75 0 10-1.5.058l.347 9a.75.75 0 101.499-.058l-.346-9zm5.48.058a.75.75 0 10-1.498-.058l-.347 9a.75.75 0 001.5.058l.345-9z" clipRule="evenodd" />
    </svg>;

    return <button
        onClick={onClick}
        className="absolute bottom-4 right-4 px-3 py-2 bg-error/90 text-error-foreground border-none rounded-lg cursor-pointer text-sm font-medium shadow-md transition-all hover:bg-error hover:-translate-y-0.5 active:translate-y-0 flex items-center gap-2"
    >
        {trashIcon}
        {"Clear Graph"}
    </button>;
}
