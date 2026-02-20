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

            # Processing indicator
            {
                (<div className="absolute top-4 left-4 z-10 flex items-center gap-2 px-3 py-2 bg-primary/95 backdrop-blur-sm rounded-lg shadow-lg">
                    <div className="w-3 h-3 border-2 border-primary-foreground/30 border-t-primary-foreground rounded-full animate-spin" />
                    <span className="text-xs font-medium text-primary-foreground">{graphProcessingMessage}</span>
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