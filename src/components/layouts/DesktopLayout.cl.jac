# DesktopLayout Component
# Desktop layout with side-by-side panels and full control bar

import from ..Header { Header }
import from ..panels.TranscriptPanel { TranscriptPanel }
import from ..panels.GraphPanel { GraphPanel }
import from ..ControlBar { ControlBar }

def:pub DesktopLayout(layoutProps: any) -> any {
    return <div className="flex flex-col h-screen">
        <Header />

        <div className="flex-1 flex gap-2 p-2 overflow-hidden">
            <TranscriptPanel
                transcriptItems={layoutProps.transcriptItems}
                transcriptEndRef={layoutProps.transcriptEndRef}
                userText={layoutProps.userText}
                setUserText={layoutProps.setUserText}
                onSend={layoutProps.handleSendTextMessage}
            />

            <GraphPanel
                graphDotCode={layoutProps.graphDotCode}
                onClearGraph={layoutProps.handleClearGraph}
            />
        </div>

        <ControlBar
            sessionStatus={layoutProps.sessionStatus}
            onToggleConnection={layoutProps.onToggleConnection}
            isPTTActive={layoutProps.isPTTActive}
            setIsPTTActive={layoutProps.setIsPTTActive}
            isPTTUserSpeaking={layoutProps.isPTTUserSpeaking}
            onTalkDown={layoutProps.onTalkDown}
            onTalkUp={layoutProps.onTalkUp}
            isAudioPlaybackEnabled={layoutProps.isAudioPlaybackEnabled}
            setIsAudioPlaybackEnabled={layoutProps.setIsAudioPlaybackEnabled}
            isMicMuted={layoutProps.isMicMuted}
            onToggleMicMute={layoutProps.toggleMicMute}
            onSaveAndRestart={layoutProps.handleSaveAndRestart}
        />
    </div>;
}
