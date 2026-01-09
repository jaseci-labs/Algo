# MobileLayout Component
# Mobile layout with tabbed interface for Transcript and Graph

import from react { useState }
import from ..Header { Header }
import from ..panels.TranscriptPanel { TranscriptPanel }
import from ..panels.GraphPanel { GraphPanel }
import from .MobileControlBar { MobileControlBar }
import from ...utils.mergeCls { cn }

def:pub MobileLayout(layoutProps: any) -> any {
    # Tab state (default to transcript)
    [activeTab, setActiveTab] = useState("transcript");

    # Tab button styling function
    def getTabButtonClass(tabId: str) -> str {
        isActive = activeTab == tabId;
        return cn(
            "flex-1 py-3 text-center font-medium transition-colors border-b-2",
            (
                "border-primary text-primary" if isActive else
                "border-transparent text-text-secondary"
            )
        );
    }

    return <div className="flex flex-col h-screen">
        <Header />

        <div className="flex border-b border-border bg-surface">
            <button
                className={getTabButtonClass("transcript")}
                onClick={lambda -> None { setActiveTab("transcript"); }}
            >
                {"Transcript"}
            </button>
            <button
                className={getTabButtonClass("graph")}
                onClick={lambda -> None { setActiveTab("graph"); }}
            >
                {"Graph"}
            </button>
        </div>

        <div className="flex-1 overflow-hidden">
            

            {
                (<TranscriptPanel
                    transcriptItems={layoutProps.transcriptItems}
                    transcriptEndRef={layoutProps.transcriptEndRef}
                    userText={layoutProps.userText}
                    setUserText={layoutProps.setUserText}
                    onSend={layoutProps.handleSendTextMessage} />)
                if activeTab == "transcript" else
                (<GraphPanel
                    graphDotCode={layoutProps.graphDotCode}
                    onClearGraph={layoutProps.handleClearGraph}/>)
            }

        </div>

        <MobileControlBar layoutProps={layoutProps} />
    </div>;
}
