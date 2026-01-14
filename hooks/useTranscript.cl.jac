# useTranscript Hook
# Custom hook for managing transcript state and operations

import from react { useState }

def:pub useTranscript() -> any {
        [transcript, setTranscript] = useState([]);
    
    # Add a new message to transcript (for system messages)
    def addMessage(role: str, content: str) -> None {
        itemId = "msg-" + String(Date.now());
        newItem = {"itemId": itemId, "role": role, "content": content, "timestamp": Date.now()};
        setTranscript(lambda prev: any -> any { return prev.concat([newItem]); });
    }
    
    # Add a transcript item by itemId (for realtime messages)
    def addTranscriptItem(itemId: str, role: str, content: str) -> None {
        newItem = {"itemId": itemId, "role": role, "content": content, "timestamp": Date.now()};
        setTranscript(lambda prev: any -> any {
            exists = prev.some(lambda item: any -> bool { return item.itemId == itemId; });
            if exists {
                return prev;
            }
            return prev.concat([newItem]);
        });
    }
    
    # Update a transcript item by itemId
    def updateTranscriptItem(itemId: str, content: str) -> None {
        setTranscript(lambda prev: any -> any {
            return prev.map(lambda item: any -> any {
                if item.itemId == itemId {
                    return {"itemId": item.itemId, "role": item.role, "content": content, "timestamp": item.timestamp};
                }
                return item;
            });
        });
    }
    
    # Append text to a transcript item by itemId (for streaming)
    def appendTranscriptItem(itemId: str, deltaText: str) -> None {
        setTranscript(lambda prev: any -> any {
            return prev.map(lambda item: any -> any {
                if item.itemId == itemId {
                    currentContent = item.content or "";
                    newContent = currentContent + deltaText;
                    if currentContent == "..." or currentContent == "" {
                        newContent = deltaText;
                    }
                    return {"itemId": item.itemId, "role": item.role, "content": newContent, "timestamp": item.timestamp};
                }
                return item;
            });
        });
    }
    
    # Clear transcript
    def clearTranscript() -> None {
        setTranscript([]);
    }
    
    return {
        "transcript": transcript,
        "addMessage": addMessage,
        "addTranscriptItem": addTranscriptItem,
        "updateTranscriptItem": updateTranscriptItem,
        "appendTranscriptItem": appendTranscriptItem,
        "clearTranscript": clearTranscript
    };
}
