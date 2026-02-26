# StartNode Component
# Circular cyan glowing node for graph entry point

import from react { memo, useMemo }
import from "@xyflow/react" { Handle, Position }

def StartNodeComponent(props: any) -> any {
    data = props.data;

    # Memoize the handle props to prevent unnecessary re-renders
    handleProps = useMemo(
        lambda -> dict {
            return {
                "type": "source",
                "position": Position.Bottom,
                "className": "handle-hidden"
            };
        },
        []
    );

    return <div className="start-node">
        <div className="start-node-inner">
            {data.label}
        </div>
        <Handle
            type={handleProps["type"]}
            position={handleProps["position"]}
            className={handleProps["className"]}
        />
    </div>;
}

glob:pub StartNode = memo(StartNodeComponent);
