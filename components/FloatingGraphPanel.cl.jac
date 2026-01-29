import  from ".GraphPanel" { GraphPanel }
import from "react" { Fragment }
import from "lucide-react" { BarChart3, XIcon }

def:pub FloatingGraphPanel(
    graphEdges: list,
    onClearGraph: any,
    onToggleGraphPanel: any,
    isGraphPanelVisible: bool,
) -> any {
    return <div>
        <div className="floating-panel fixed inset-0 z-10" ></div>
         <div className=" absolute inset-0 flex md:hidden items-center justify-center z-20">
            <div className="w-full max-w-lg md:max-w-2xl h-[85vh] glass-panel shadow-xl border border-border/30 overflow-hidden relative animate-fadeIn">
                <GraphPanel
                    graphEdges={graphEdges}
                    onClearGraph={onClearGraph}
                />
            </div>
        </div>
        <GraphPanelButton onClick={onToggleGraphPanel} isVisible={isGraphPanelVisible} />
    </div>;
}

def GraphPanelButton(onClick: any, isVisible: bool) -> any {

    return <div  className="absolute md:hidden flex justify-center items-center bottom-2 left-2 p-2 rounded-full border-2 border-white h cursor-pointer z-20">
    {
        (<BarChart3 onClick={onClick} className="w-6 h-6 text-primary" />) if not isVisible else
        (<XIcon onClick={onClick} className="w-6 h-6 text-primary" />)
    }
    </div>;
}