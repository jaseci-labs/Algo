# MainApp Component (UI Only)
# Pure presentation component - all business logic extracted to useMainApp hook
# Uses viewport detection to conditionally render mobile or desktop layouts

# import from ..components.TranscriptItem { TranscriptItem }
import from ..components.Layout { Layout }
# import from ..components.layouts.MobileLayout { MobileLayout }
# import from ..components.layouts.DesktopLayout { DesktopLayout }

# import from ..hooks.useMainApp { useMainApp }
# import from ..hooks.useViewport { useViewport }

# ============================================
# Main Application Component
# ============================================

def:pub MainApp() -> any {
    # Get all state and handlers from the hook
    # hook = useMainApp();

    # # Get viewport information
    # viewport = useViewport();

    # # Destructure hook values for cleaner access
    # sessionStatus = hook.sessionStatus;
    # isPTTActive = hook.isPTTActive;
    # setIsPTTActive = hook.setIsPTTActive;
    # isPTTUserSpeaking = hook.isPTTUserSpeaking;
    # isAudioPlaybackEnabled = hook.isAudioPlaybackEnabled;
    # setIsAudioPlaybackEnabled = hook.setIsAudioPlaybackEnabled;
    # isMicMuted = hook.isMicMuted;
    # userText = hook.userText;
    # setUserText = hook.setUserText;
    # transcript = hook.transcript;
    # graphDotCode = hook.graphDotCode;
    # transcriptEndRef = hook.transcriptEndRef;

    # # Handlers
    # onToggleConnection = hook.onToggleConnection;
    # toggleMicMute = hook.toggleMicMute;
    # handleTalkButtonDown = hook.handleTalkButtonDown;
    # handleTalkButtonUp = hook.handleTalkButtonUp;
    # handleSendTextMessage = hook.handleSendTextMessage;
    # handleClearGraph = hook.handleClearGraph;
    # handleSaveAndRestart = hook.handleSaveAndRestart;

    # # Build transcript items
    # transcriptItems = [];
    # idx = 0;
    # for item in transcript {
    #     transcriptItems.push(<TranscriptItem key={idx} item={item} />);
    #     idx = idx + 1;
    # }

    # Create props object for layouts
    # layoutProps = {
    #     "transcriptItems": transcriptItems,
    #     "transcriptEndRef": transcriptEndRef,
    #     "userText": userText,
    #     "setUserText": setUserText,
    #     "graphDotCode": graphDotCode,
    #     "sessionStatus": sessionStatus,
    #     "onToggleConnection": onToggleConnection,
    #     "isPTTActive": isPTTActive,
    #     "setIsPTTActive": setIsPTTActive,
    #     "isPTTUserSpeaking": isPTTUserSpeaking,
    #     "onTalkDown": handleTalkButtonDown,
    #     "onTalkUp": handleTalkButtonUp,
    #     "isAudioPlaybackEnabled": isAudioPlaybackEnabled,
    #     "setIsAudioPlaybackEnabled": setIsAudioPlaybackEnabled,
    #     "isMicMuted": isMicMuted,
    #     "toggleMicMute": toggleMicMute,
    #     "handleSendTextMessage": handleSendTextMessage,
    #     "handleClearGraph": handleClearGraph,
    #     "handleSaveAndRestart": handleSaveAndRestart
    # };

    # ========== Render appropriate layout based on viewport ==========
    return <Layout meta={{"title": "Dashboard | Algo", "description": "Your AI assistant dashboard with voice interface"}}>
        # {
        #     (<MobileLayout layoutProps={layoutProps} />) if viewport.isMobile else (<DesktopLayout layoutProps={layoutProps} />)
        # }
        <p>Viewport detection is currently disabled for demo purposes.</p>
    </Layout>;
}
