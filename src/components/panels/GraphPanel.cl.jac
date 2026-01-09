# GraphPanel Component
# Graph panel showing task visualization with clear button

import from ..GraphViewer { GraphViewer }

def:pub GraphPanel(
    graphDotCode: str,
    onClearGraph: any
) -> any {
    return <div className="flex-1 bg-surface rounded-xl flex flex-col min-h-0 shadow-sm">
        <div className="flex items-center justify-between px-6 py-3 border-b border-border font-semibold text-text-primary">
            Task Graph
            <span className="text-xs text-text-secondary font-normal">
                Real-time visualization
            </span>
        </div>

        <div className="flex-1 overflow-auto bg-surface-hover relative">
            <GraphViewer dotCode={graphDotCode} />

            <button
                onClick={onClearGraph}
                className="absolute bottom-4 right-4 px-4 py-2 bg-error text-error-foreground border-none rounded-lg cursor-pointer text-sm font-medium shadow-md transition-all hover:opacity-90 hover:-translate-y-0.5 active:translate-y-0"
            >
                Clear Graph
            </button>
        </div>
    </div>;
}
