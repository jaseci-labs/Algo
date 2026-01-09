# MobileControlBar Component
# Simplified control bar for mobile with essential controls

import from ..controls.ConnectButton { ConnectButton }
import from ..controls.MicButton { MicButton }

def:pub MobileControlBar(layoutProps: any) -> any {
    # Computed value for connected state
    isConnected = layoutProps.sessionStatus == "CONNECTED";

    return <div className="p-4 flex flex-row items-center justify-center gap-4 border-t border-border bg-surface">
        <ConnectButton
            sessionStatus={layoutProps.sessionStatus}
            onToggleConnection={layoutProps.onToggleConnection}
        />

        <MicButton
            isMicMuted={layoutProps.isMicMuted}
            onToggleMicMute={layoutProps.toggleMicMute}
            isConnected={isConnected}
        />
    </div>;
}
