# TranscriptPanel Component
# Transcript panel showing conversation with message input

import from ..MessageInput { MessageInput }

def:pub TranscriptPanel(
    transcriptItems: any,
    transcriptEndRef: any,
    userText: str,
    setUserText: any,
    onSend: any
) -> any {
    return <div className="flex-1 bg-surface rounded-xl flex flex-col min-h-0 shadow-sm">
        <div className="flex items-center justify-between px-6 py-3 border-b border-border font-semibold text-text-primary">
            Transcript
        </div>

        <div className="flex-1 overflow-y-auto p-4 flex flex-col gap-4">
            {transcriptItems}
            <div ref={transcriptEndRef} />
        </div>

        <MessageInput
            userText={userText}
            setUserText={setUserText}
            onSend={onSend}
        />
    </div>;
}
