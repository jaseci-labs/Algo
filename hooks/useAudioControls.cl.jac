# useAudioControls Hook
# Custom hook for managing audio, microphone, and push-to-talk controls

import from react { useEffect, useRef }

def:pub useAudioControls(sessionRef: any, sessionStatus: str) -> any {
    # Audio element ref
    audioElementRef = useRef(None);

    # Reactive state using has variables
    has isPTTActive: bool = False;
    has isPTTUserSpeaking: bool = False;
    has isAudioPlaybackEnabled: bool = True;
    has isMicMuted: bool = False;

    # Toggle mic mute state
    def toggleMicMute() -> None {
        isMicMuted = not isMicMuted;
    }

    # Push-to-Talk: Button down handler
    def handleTalkButtonDown() -> None {
        if sessionStatus != "CONNECTED" {
            return;
        }
        isPTTUserSpeaking = True;

        if sessionRef.current {
            try {
                sessionRef.current.interrupt();
            } except Exception as e {
                console.error("PTT error:", e);
            }
        }
    }

    # Push-to-Talk: Button up handler
    def handleTalkButtonUp() -> None {
        if sessionStatus != "CONNECTED" or not isPTTUserSpeaking {
            return;
        }
        isPTTUserSpeaking = False;
    }

    # Reset PTT state (called on disconnect)
    def resetPTTState() -> None {
        isPTTUserSpeaking = False;
    }

    # Setter wrapper functions for parent components
    def updatePTTActive(value: bool) -> None {
        isPTTActive = value;
    }

    def updateAudioPlaybackEnabled(value: bool) -> None {
        isAudioPlaybackEnabled = value;
    }

    # Create audio element on mount
    useEffect(
        lambda -> None {
            el = document.createElement('audio');
            el.autoplay = True;
            el.style.display = 'none';
            document.body.appendChild(el);
            audioElementRef.current = el;
        },
        []
    );
    
    # Handle mic mute/unmute
    useEffect(
        lambda -> None {
            if sessionRef.current {
                try {
                    console.log("Setting mic mute state to:", isMicMuted);
                    sessionRef.current.mute(isMicMuted);
                } except Exception as e {
                    console.error("Error toggling mic:", e);
                }
            }
        },
        [isMicMuted, sessionStatus]
    );
    
    # Audio playback toggle
    useEffect(
        lambda -> None {
            if audioElementRef.current {
                audioElementRef.current.muted = not isAudioPlaybackEnabled;
            }
        },
        [isAudioPlaybackEnabled]
    );
    
    return {
        # State
        "isPTTActive": isPTTActive,
        "setIsPTTActive": updatePTTActive,
        "isPTTUserSpeaking": isPTTUserSpeaking,
        "isAudioPlaybackEnabled": isAudioPlaybackEnabled,
        "setIsAudioPlaybackEnabled": updateAudioPlaybackEnabled,
        "isMicMuted": isMicMuted,

        # Refs
        "audioElementRef": audioElementRef,

        # Handlers
        "toggleMicMute": toggleMicMute,
        "handleTalkButtonDown": handleTalkButtonDown,
        "handleTalkButtonUp": handleTalkButtonUp,
        "resetPTTState": resetPTTState
    };
}
