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
import from ..components.GraphPanel { GraphPanel }
import from ..components.TranscriptPanel { TranscriptPanel }
import from ..components.FloatingGraphPanel { FloatingGraphPanel }
import from ..components.AnalyticsPanel { AnalyticsPanel }

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
    [isGraphPanelVisible, setIsGraphPanelVisible] = useState(False);
    [isAnalyticsPanelVisible, setIsAnalyticsPanelVisible] = useState(False);
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

    def handleGraphPanelToggle() -> None {
        setIsGraphPanelVisible(not isGraphPanelVisible);
    }

    def handleAnalyticsPanelToggle() -> None {
        setIsAnalyticsPanelVisible(not isAnalyticsPanelVisible);
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
            <Header isDarkMode={isDarkMode} onToggleTheme={toggleTheme} onToggleAnalytics={handleAnalyticsPanelToggle} />

            <div className="flex-1 flex flex-col md:flex-row gap-4 p-2 md:p-4 overflow-hidden">
                <div className="w-full md:w-1/2  h-screen md:h-auto">
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
                        isGraphPanelVisible={isGraphPanelVisible}
                        onToggleGraphPanel={handleGraphPanelToggle}
                    />
                </div>

                <div className="hidden md:block w-full md:w-1/2">
                    <GraphPanel
                        graphEdges={graphEdges}
                        onClearGraph={handleClearGraph}
                    />
                </div>
            </div>

            {
                (<FloatingGraphPanel
                 graphEdges={graphEdges}
                 onClearGraph={handleClearGraph}
                 isGraphPanelVisible={isGraphPanelVisible}
                onToggleGraphPanel={handleGraphPanelToggle}
            />) if isGraphPanelVisible else (<Fragment />)
            }

            {
                (<div className="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm flex items-center justify-center p-4">
                    <div className="w-full max-w-4xl h-[80vh] glass-panel rounded-xl shadow-2xl">
                        <AnalyticsPanel onClose={handleAnalyticsPanelToggle} />
                    </div>
                </div>) if isAnalyticsPanelVisible else (<Fragment />)
            }

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
