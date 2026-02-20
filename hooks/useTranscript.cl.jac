# useTranscript Hook
# Custom hook for managing transcript state and operations

import from react { useRef }

def:pub useTranscript() -> any {
    # Reactive state using has variables
    has transcript: list = [];

    # Ref to always access current transcript value (avoids closure stale values)
    # This ref is updated in a can with block whenever transcript changes
    transcriptRef = useRef([]);

    # Sync ref with state whenever transcript changes
    can with [transcript] entry {
        transcriptRef.current = transcript;
    }

    # Add a new message to transcript (for system messages)
    def addMessage(role: str, content: str) -> None {
        console.log("[useTranscript] addMessage called:", role, content);
        # Use ref to always get current value, avoiding closure stale values
        current = transcriptRef.current;
        itemId = "msg-" + String(Date.now());
        newItem = {"itemId": itemId, "role": role, "content": content, "timestamp": Date.now()};
        # Create new array with new item
        updated = current.concat([newItem]);
        transcript = updated;
        console.log("[useTranscript] addMessage: new transcript length:", updated.length);
    }

    # Add a transcript item by itemId (for realtime messages)
    def addTranscriptItem(itemId: str, role: str, content: str, thinking: any = None) -> None {
        console.log("[useTranscript] addTranscriptItem called:", itemId, role, content);
        # Use ref to always get current value
        current = transcriptRef.current;
        # Check if exists
        exists = current.some(lambda item: any -> bool { return item.itemId == itemId; });
        if not exists {
            newItem = {"itemId": itemId, "role": role, "content": content, "thinking": thinking, "timestamp": Date.now()};
            updated = current.concat([newItem]);
            transcript = updated;
            console.log("[useTranscript] addTranscriptItem: added new item, new length:", updated.length);
        } else {
            console.log("[useTranscript] addTranscriptItem: item already exists, skipping");
        }
    }

    # Update a transcript item by itemId
    def updateTranscriptItem(itemId: str, content: str, thinking: any = None) -> None {
        console.log("[useTranscript] updateTranscriptItem called:", itemId, content);
        # Use ref to always get current value
        current = transcriptRef.current;
        updatedTranscript = current.map(lambda item: any -> any {
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
        transcript = updatedTranscript;
        console.log("[useTranscript] Transcript updated, new length:", updatedTranscript.length);
    }

    # Append text to a transcript item by itemId (for streaming)
    def appendTranscriptItem(itemId: str, deltaText: str) -> None {
        console.log("[useTranscript] appendTranscriptItem called:", itemId, deltaText);
        # Use ref to always get current value
        current = transcriptRef.current;
        updatedTranscript = current.map(lambda item: any -> any {
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
        transcript = updatedTranscript;
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
