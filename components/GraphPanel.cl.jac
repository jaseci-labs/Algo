import from react { Fragment }
import from "lucide-react" { BarChart3, Trash2 }
import from .GraphViewer { GraphViewer }

# Graph Panel - right side showing task visualization
def:pub GraphPanel(graphEdges: list, onClearGraph: any, isGraphProcessing: bool = False, graphProcessingMessage: str = "") -> any {
    return <div className="glass-panel flex flex-col h-full">
        <div className="flex items-center justify-between px-5 py-4 border-b border-border/30">
            <div className="flex items-center gap-2">
                <BarChart3 className="w-4 h-4 text-primary" />
                <h2 className="text-sm font-semibold text-foreground">{"Task Graph"}</h2>
            </div>
            <span className="text-xs text-muted-foreground">
                {"Real-time visualization"}
            </span>
        </div>

        <div className="flex-1 overflow-hidden bg-background relative rounded-[0.75rem]">
            <GraphViewer graphEdges={graphEdges} />

            # Processing indicator - Material Design style animated loader
            {
                (<div className="absolute inset-0 z-10 flex items-center justify-center bg-background/90 backdrop-blur-md">
                    <div className="flex flex-col items-center gap-6 p-8">
                        <div className="relative w-20 h-20">
                            <div className="absolute inset-0 rounded-full border-2 border-primary/20 animate-ping" style={{"animation-duration": "1.5s"}}></div>
                            <div className="absolute inset-2 rounded-full border-2 border-primary/30 animate-ping" style={{"animation-duration": "1.5s", "animation-delay": "0.3s"}}></div>
                            <div className="absolute inset-4 rounded-full border-2 border-primary/40 animate-ping" style={{"animation-duration": "1.5s", "animation-delay": "0.6s"}}></div>

                            <div className="absolute inset-0 flex items-center justify-center">
                                <div className="w-16 h-16 rounded-full border-4 border-transparent border-t-primary border-r-primary/80 animate-spin" style={{"animation-duration": "1s"}}></div>
                                <div className="absolute w-12 h-12 rounded-full border-3 border-transparent border-b-primary/60 border-l-primary/40 animate-spin" style={{"animation-duration": "0.8s", "animation-direction": "reverse"}}></div>
                            </div>

                            <div className="absolute inset-0 flex items-center justify-center">
                                <div className="w-3 h-3 rounded-full bg-primary animate-pulse"></div>
                            </div>
                        </div>

                        <div className="flex flex-col items-center gap-2">
                            <div className="text-sm font-semibold text-foreground animate-pulse">{"Processing"}</div>
                            <div className="text-xs text-muted-foreground flex items-center gap-1">
                                <span>{graphProcessingMessage}</span>
                                <span className="flex gap-1 ml-1">
                                    <span className="w-1 h-1 rounded-full bg-primary animate-bounce" style={{"animation-delay": "0s"}}></span>
                                    <span className="w-1 h-1 rounded-full bg-primary animate-bounce" style={{"animation-delay": "0.1s"}}></span>
                                    <span className="w-1 h-1 rounded-full bg-primary animate-bounce" style={{"animation-delay": "0.2s"}}></span>
                                </span>
                            </div>
                        </div>
                    </div>
                </div>) if isGraphProcessing else (<Fragment />)
            }

            <ClearGraphButton onClick={onClearGraph} />
        </div>
    </div>;
}

# Clear Graph Button
def ClearGraphButton(onClick: any) -> any {
    return <button
        onClick={onClick}
        className="absolute bottom-4 right-4 flex items-center gap-2 px-3 py-2 bg-destructive/10 text-destructive rounded-lg text-xs font-medium hover:bg-destructive/20 transition-colors"
    >
        <Trash2 className="w-3.5 h-3.5" />
        {"Clear Graph"}
    </button>;
}