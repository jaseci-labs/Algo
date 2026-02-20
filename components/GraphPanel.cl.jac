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

            # Processing indicator - more visually engaging
            {
                (<div className="absolute inset-0 z-10 flex items-center justify-center bg-background/80 backdrop-blur-sm animate-fade-in">
                    <div className="flex flex-col items-center gap-4 p-6">
                        <div className="relative">
                            <div className="absolute inset-0 rounded-full bg-primary/20 animate-ping"></div>
                            <div className="absolute inset-0 rounded-full bg-primary/30 animate-ping" style={{"animation-delay": "0.2s"}}></div>
                            <div className="absolute inset-0 rounded-full bg-primary/40 animate-ping" style={{"animation-delay": "0.4s"}}></div>
                            <div className="relative w-16 h-16 rounded-full bg-gradient-to-br from-primary to-primary/70 flex items-center justify-center shadow-lg">
                                <div className="w-12 h-12 border-3 border-primary-foreground/30 border-t-primary-foreground rounded-full animate-spin" />
                            </div>
                        </div>
                        <div className="text-center">
                            <div className="text-sm font-semibold text-foreground mb-1">{"Updating your graph"}</div>
                            <div className="text-xs text-muted-foreground">{graphProcessingMessage}</div>
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