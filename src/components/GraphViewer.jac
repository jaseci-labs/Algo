# GraphViewer Component - Renders GraphViz DOT code
cl import from "react" { useState, useEffect }
cl import from "@hpcc-js/wasm/graphviz" { Graphviz }

cl def GraphViewer(props: any) -> any {
    dotCode = props.dotCode;
    [svgContent, setSvgContent] = useState("");
    [isLoading, setIsLoading] = useState(True);
    
    # Render DOT code to SVG whenever it changes
    useEffect(
        lambda -> None {
            async def renderGraph() -> None {
                if dotCode and dotCode.length > 0 {
                    try {
                        setIsLoading(True);
                        graphviz = await Graphviz.load();
                        svg = graphviz.dot(dotCode);
                        setSvgContent(svg);
                        setIsLoading(False);
                    } except Exception as e {
                        console.error("Error rendering graph:", e);
                        setIsLoading(False);
                    }
                } else {
                    setIsLoading(False);
                }
            }
            
            renderGraph();
        },
        [dotCode]
    );
    
    if not dotCode or dotCode.length == 0 {
        return <div style={{
            "display": "flex",
            "alignItems": "center",
            "justifyContent": "center",
            "height": "100%",
            "color": "#9ca3af",
            "fontSize": "0.875rem",
            "textAlign": "center",
            "padding": "2rem"
        }}>
            <div>
                <div style={{"fontSize": "2rem", "marginBottom": "0.5rem"}}>{"🌳"}</div>
                <div>{"Your task graph will appear here"}</div>
            </div>
        </div>;
    }
    
    if isLoading {
        return <div style={{
            "display": "flex",
            "alignItems": "center",
            "justifyContent": "center",
            "height": "100%",
            "color": "#9ca3af"
        }}>
            <div>{"Loading graph..."}</div>
        </div>;
    }
    
    return <div style={{
        "padding": "2rem",
        "height": "100%",
        "overflowY": "auto",
        "backgroundColor": "#f9fafb",
        "display": "flex",
        "justifyContent": "center",
        "alignItems": "flex-start"
    }}>
        <div dangerouslySetInnerHTML={{"__html": svgContent}}></div>
    </div>;
}
