# useAudioControls Hook
# Custom hook for managing audio, microphone, and push-to-talk controls

cl import from react { useState, useEffect, useRef }

cl {
    def:pub useAudioControls(sessionRef: any, sessionStatus: str) -> any {
        # Audio element ref
        audioElementRef = useRef(None);
        
        # UI state
        [isPTTActive, setIsPTTActive] = useState(False);
        [isPTTUserSpeaking, setIsPTTUserSpeaking] = useState(False);
        [isAudioPlaybackEnabled, setIsAudioPlaybackEnabled] = useState(True);
        [isMicMuted, setIsMicMuted] = useState(False);
        
        # Toggle mic mute state
        def toggleMicMute() -> None {
            setIsMicMuted(lambda prev: bool -> bool { return not prev; });
        }
        
        # Push-to-Talk: Button down handler
        def handleTalkButtonDown() -> None {
            if sessionStatus != "CONNECTED" {
                return;
            }
            setIsPTTUserSpeaking(True);
            
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
            setIsPTTUserSpeaking(False);
        }
        
        # Reset PTT state (called on disconnect)
        def resetPTTState() -> None {
            setIsPTTUserSpeaking(False);
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
            "setIsPTTActive": setIsPTTActive,
            "isPTTUserSpeaking": isPTTUserSpeaking,
            "isAudioPlaybackEnabled": isAudioPlaybackEnabled,
            "setIsAudioPlaybackEnabled": setIsAudioPlaybackEnabled,
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
}
