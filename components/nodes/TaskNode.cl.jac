# TaskNode Component
# Dark rounded rectangular node for task display

import from react { memo }
import from "@xyflow/react" { Handle, Position }

def TaskNodeComponent(props: any) -> any {
    data = props.data;

    return <div className="task-node">
        <Handle
            type="target"
            position={Position.Top}
            className="handle-hidden"
        />
        <div className="task-node-label">
            {data.label}
        </div>
        <Handle
            type="source"
            position={Position.Bottom}
            className="handle-hidden"
        />
    </div>;
}

glob:pub TaskNode = memo(TaskNodeComponent);