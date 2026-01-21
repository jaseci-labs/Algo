# useTranscript Hook
# Custom hook for managing transcript state and operations

def:pub useTranscript() -> any {
    # Reactive state using has variables
    has transcript: list = [];

    # Add a new message to transcript (for system messages)
    def addMessage(role: str, content: str) -> None {
        itemId = "msg-" + String(Date.now());
        newItem = {"itemId": itemId, "role": role, "content": content, "timestamp": Date.now()};
        transcript = lambda prev: any -> any { return prev.concat([newItem]); };
    }

    # Add a transcript item by itemId (for realtime messages)
    def addTranscriptItem(itemId: str, role: str, content: str, thinking: any = None) -> None {
        newItem = {"itemId": itemId, "role": role, "content": content, "thinking": thinking, "timestamp": Date.now()};
        transcript = lambda prev: any -> any {
            exists = prev.some(lambda item: any -> bool { return item.itemId == itemId; });
            if exists {
                return prev;
            }
            return prev.concat([newItem]);
        };
    }

    # Update a transcript item by itemId
    def updateTranscriptItem(itemId: str, content: str, thinking: any = None) -> None {
        transcript = lambda prev: any -> any {
            return prev.map(lambda item: any -> any {
                if item.itemId == itemId {
                    updatedItem = {"itemId": item.itemId, "role": item.role, "content": content, "timestamp": item.timestamp};
                    # Add thinking data if provided or preserve existing
                    thinkingValue = thinking if thinking != None else (item.thinking if item.thinking else None);
                    if thinkingValue != None {
                        updatedItem["thinking"] = thinkingValue;
                    }
                    return updatedItem;
                }
                return item;
            });
        };
    }

    # Append text to a transcript item by itemId (for streaming)
    def appendTranscriptItem(itemId: str, deltaText: str) -> None {
        transcript = lambda prev: any -> any {
            return prev.map(lambda item: any -> any {
                if item.itemId == itemId {
                    currentContent = item.content or "";
                    newContent = currentContent + deltaText;
                    if currentContent == "..." or currentContent == "" {
                        newContent = deltaText;
                    }
                    updatedItem = {"itemId": item.itemId, "role": item.role, "content": newContent, "timestamp": item.timestamp};
                    # Preserve thinking data if it exists
                    thinkingValue = item.thinking if item.thinking else None;
                    if thinkingValue != None {
                        updatedItem["thinking"] = thinkingValue;
                    }
                    return updatedItem;
                }
                return item;
            });
        };
    }

    # Clear transcript
    def clearTranscript() -> None {
        transcript = [];
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
