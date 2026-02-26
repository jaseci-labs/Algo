import  from "lucide-react" { MessageSquare, BarChart3, XIcon }
import from .MessageInput { MessageInput }
import from "react" { Fragment }


# Transcript Panel - left side showing conversation
def:pub TranscriptPanel(
    transcriptItems: any,
    transcriptEndRef: any,
    userText: str,
    setUserText: any,
    onSend: any,
    suggestions: list,
    onSelectSuggestion: any,
    sessionStatus: str,
    onToggleConnection: any,
    onShowControlBar: any,
    onHideControlBar: any,
    onToggleGraphPanel: any,
    isGraphPanelVisible: bool,
) -> any {
    return <div className="glass-panel flex flex-col h-full relative">
        <div className="flex items-center gap-2 px-5 py-4 border-b border-border/30 text-sm font-semibold text-foreground">
            <MessageSquare className="w-5 h-5 text-primary" />
            {"Transcript"}
        </div>

        <div className="flex-1 overflow-y-auto p-4 flex flex-col gap-4">
            {transcriptItems}
            <div ref={transcriptEndRef} />
        </div>

        <MessageInput
             userText={userText}
            setUserText={setUserText}
            onSend={onSend}
            suggestions={suggestions}
            onSelectSuggestion={onSelectSuggestion}
            sessionStatus={sessionStatus}
            onToggleConnection={onToggleConnection}
            onShowControlBar={onShowControlBar}
            onHideControlBar={onHideControlBar}
        />
        <GraphPanelButton onClick={onToggleGraphPanel} isVisible={isGraphPanelVisible} />
    </div>;
}

def GraphPanelButton(onClick: any, isVisible: bool) -> any {

    return <div  className="absolute md:hidden flex justify-center items-center bottom-[6rem] left-[0.75rem] p-2 rounded-full border-2 border-white hover:bg-primary/10 cursor-pointer z-20">
    {
        (<BarChart3 onClick={onClick} className="w-4 h-4 text-primary" />) if not isVisible else
        (<Fragment/>)
    }
    </div>;
}
