# useTranscript Hook
# Custom hook for managing transcript state and operations

def:pub useTranscript() -> any {
    # Reactive state using has variables
    has transcript: list = [];

    # Add a new message to transcript (for system messages)
    def addMessage(role: str, content: str) -> None {
        console.log("[useTranscript] addMessage called:", role, content);
        itemId = "msg-" + String(Date.now());
        newItem = {"itemId": itemId, "role": role, "content": content, "timestamp": Date.now()};
        transcript = lambda prev: any -> any { return prev.concat([newItem]); };
        console.log("[useTranscript] addMessage done");
    }

    # Add a transcript item by itemId (for realtime messages)
    def addTranscriptItem(itemId: str, role: str, content: str, thinking: any = None) -> None {
        console.log("[useTranscript] addTranscriptItem called:", itemId, role, content);
        newItem = {"itemId": itemId, "role": role, "content": content, "thinking": thinking, "timestamp": Date.now()};
        transcript = lambda prev: any -> any {
            exists = prev.some(lambda item: any -> bool { return item.itemId == itemId; });
            if exists {
                console.log("[useTranscript] Item already exists, skipping");
                return prev;
            }
            console.log("[useTranscript] Adding new item, prev length:", prev.length);
            result = prev.concat([newItem]);
            console.log("[useTranscript] New length:", result.length);
            return result;
        };
    }

    # Update a transcript item by itemId
    def updateTranscriptItem(itemId: str, content: str, thinking: any = None) -> None {
        console.log("[useTranscript] updateTranscriptItem called:", itemId, content);
        transcript = lambda prev: any -> any {
            return prev.map(lambda item: any -> any {
                if item.itemId == itemId {
                    updatedItem = {"itemId": item.itemId, "role": item.role, "content": content, "timestamp": item.timestamp};
                    # Add thinking data if provided or preserve existing
                    thinkingValue = thinking if thinking != None else (item.thinking if item.thinking else None);
                    if thinkingValue != None {
                        updatedItem["thinking"] = thinkingValue;
                    }
                    console.log("[useTranscript] Updating item to:", updatedItem);
                    return updatedItem;
                }
                return item;
            });
        };
        console.log("[useTranscript] updateTranscriptItem done");
    }

    # Append text to a transcript item by itemId (for streaming)
    def appendTranscriptItem(itemId: str, deltaText: str) -> None {
        console.log("[useTranscript] appendTranscriptItem called:", itemId, deltaText);
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
        console.log("[useTranscript] clearTranscript called");
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
