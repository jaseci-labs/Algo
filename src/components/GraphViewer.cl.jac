# GraphViewer Component - Renders GraphViz DOT code
import from react { useState, useEffect, useRef }
import from "@hpcc-js/wasm/graphviz" { Graphviz }
import from ..utils.mergeCls { cn }

def:pub GraphViewer(props: any) -> any {
    dotCode = props.dotCode;
    [svgContent, setSvgContent] = useState("");
    [isLoading, setIsLoading] = useState(True);
    [renderKey, setRenderKey] = useState(0);
    prevDotCodeRef = useRef("");
    
    # Render DOT code to SVG whenever it changes
    useEffect(
        lambda -> None {
            console.log("GraphViewer useEffect triggered");
            console.log("Current dotCode:", dotCode);
            console.log("Previous dotCode:", prevDotCodeRef.current);
            
            # Check if dotCode actually changed
            if dotCode == prevDotCodeRef.current {
                console.log("DotCode unchanged, skipping render");
                return;
            }
            
            prevDotCodeRef.current = dotCode;
            
            async def renderGraph() -> None {
                if dotCode and dotCode.length > 0 {
                    try {
                        console.log("Rendering new graph...");
                        setIsLoading(True);
                        graphviz = await Graphviz.load();
                        svg = graphviz.dot(dotCode);
                        console.log("Graph rendered, SVG length:", svg.length);
                        setSvgContent(svg);
                        setRenderKey(renderKey + 1);
                        setIsLoading(False);
                    } except Exception as e {
                        console.error("Error rendering graph:", e);
                        setIsLoading(False);
                    }
                } else {
                    console.log("No dotCode to render");
                    setIsLoading(False);
                }
            }
            
            renderGraph();
        },
        [dotCode]
    );
    
    # Empty state
    if not dotCode or dotCode.length == 0 {
        return <div className="flex items-center justify-center h-full text-text-secondary text-sm text-center p-8">
            <div>
                <div className="text-4xl mb-2">{"🌳"}</div>
                <div>{"Your task graph will appear here"}</div>
            </div>
        </div>;
    }
    
    # Loading state
    if isLoading {
        return <div className="flex items-center justify-center h-full text-text-secondary">
            <div className="flex items-center gap-2">
                <div className="w-5 h-5 border-2 border-text-secondary/30 border-t-text-secondary rounded-full animate-spin" />
                <span>{"Loading graph..."}</span>
            </div>
        </div>;
    }
    
    # Rendered graph
    return <div 
        key={renderKey}
        className="p-8 h-full overflow-y-auto bg-surface-hover flex justify-center items-start"
    >
        <div dangerouslySetInnerHTML={{"__html": svgContent}}></div>
    </div>;
}