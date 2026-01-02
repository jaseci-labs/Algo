# Algo - In-Depth Architecture & Technical Documentation

## Table of Contents
1. [Overview](#overview)
2. [Core Architecture](#core-architecture)
3. [Technology Stack](#technology-stack)
4. [Data Flow & System Design](#data-flow--system-design)
5. [Frontend Implementation](#frontend-implementation)
6. [Backend Implementation](#backend-implementation)
7. [Key Features Deep Dive](#key-features-deep-dive)
8. [Code-Level Analysis](#code-level-analysis)
9. [Future Improvements](#future-improvements)

---

## Overview

**Algo** is a voice-enabled personal AI assistant that tracks user activities in real-time and builds a visual task graph representing their daily routines. It combines OpenAI's Realtime API for voice interaction with a custom backend intelligence layer for task tracking, calendar integration, email management, and GitHub monitoring.

### What Makes Algo Unique

1. **Real-time Task Graph Generation**: Automatically builds a directed graph of user activities as they speak
2. **Multi-Agent Architecture**: Uses two AI agents working in tandem (voice agent + supervisor)
3. **Per-User Data Isolation**: Each user has their own isolated graph data and saved routines
4. **Voice-First Interface**: Designed for natural conversation with push-to-talk and continuous mode
5. **Routine Learning**: Saves and learns from past user routines to make intelligent suggestions

---

## Core Architecture

### High-Level System Design

```
┌─────────────────────────────────────────────────────────────┐
│                    Frontend (React + Jac)                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Voice UI   │  │  Transcript  │  │ Graph Viewer │      │
│  │  (Controls)  │  │   Display    │  │  (GraphViz)  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              ↕
              ┌──────────────────────────────┐
              │   OpenAI Realtime API        │
              │   (Voice Agent - gpt-4)      │
              └──────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│                   Jac Backend Server                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  call_       │  │  update_task │  │  get_task_   │      │
│  │  supervisor  │  │    _graph    │  │    graph     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              ↕
              ┌──────────────────────────────┐
              │  OpenAI Responses API        │
              │  (Supervisor - gpt-4.1)      │
              └──────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│                    Graph Database                            │
│        (Per-User Nodes: user_graph_data)                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  User A      │  │  User B      │  │  User C      │      │
│  │  Graph Data  │  │  Graph Data  │  │  Graph Data  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Multi-Agent Architecture

Algo uses a **hierarchical multi-agent system**:

1. **Chat Agent (Junior Agent)**
   - Model: OpenAI Realtime API (gpt-4 with voice)
   - Role: Handles voice interaction, immediate responses
   - Tools: Single tool - `getNextResponseFromSupervisor`
   - Located in: [app.cl.jac:25-67](src/app.cl.jac#L25-L67)

2. **Supervisor Agent (Backend Intelligence)**
   - Model: OpenAI Responses API (gpt-4.1 text)
   - Role: Processes complex requests, updates task graph, handles integrations
   - Tools: `updateTaskGraph`, `getCalendarEvents`, `getEmails`, `getGitHubIssues`
   - Located in: [app.jac:40-86](src/app.jac#L40-L86)

**Why This Design?**

The separation allows:
- Fast voice responses without heavy computation
- Complex backend processing without interrupting conversation
- Tool access without exposing APIs to the voice layer
- Better cost optimization (realtime for voice, responses for intelligence)

---

## Technology Stack

### Frontend
- **Jac Language**: Jaseci's language that transpiles to React
- **React 18.2**: UI framework
- **React Router 6.22**: Navigation and protected routes
- **@openai/agents**: OpenAI's multi-agent SDK
- **@hpcc-js/wasm**: GraphViz rendering in browser
- **Vite 6.4**: Build tool and dev server

### Backend
- **Jac Language**: Full backend implementation
- **Walker Pattern**: Jaseci's graph traversal paradigm
- **Node-Based Storage**: Per-user graph data nodes
- **OpenAI APIs**: Realtime API + Responses API

### Infrastructure
- **Development**: `jac serve` - development server
- **Production**: `jac scale` - scalable deployment with auth
- **Authentication**: JWT-based (prepared for jac-scale)

---

## Data Flow & System Design

### 1. Voice Interaction Flow

```
User speaks → Microphone captures audio → OpenAI Realtime API transcribes
    ↓
Chat Agent receives transcript → Identifies need for backend
    ↓
Calls getNextResponseFromSupervisor tool → Passes context to backend
    ↓
Backend walker call_supervisor invoked → Processes with GPT-4.1
    ↓
Supervisor calls updateTaskGraph → Updates user's graph node
    ↓
Response flows back → Chat Agent speaks response → User hears
    ↓
Graph visualization updates in real-time
```

**Code Path:**
1. User speaks: [app.cl.jac:674-686](src/app.cl.jac#L674-L686) - `handleTalkButtonDown()`
2. Supervisor tool execution: [app.cl.jac:188-277](src/app.cl.jac#L188-L277) - `executeSupervisorTool()`
3. Backend walker: [app.jac:728-901](src/app.jac#L728-L901) - `call_supervisor` walker
4. Graph update: [app.jac:347-424](src/app.jac#L347-L424) - `update_task_graph` walker

### 2. Text Chat Flow

For non-voice interactions:

```
User types message → handleSendTextMessage() invoked
    ↓
Frontend directly calls call_supervisor walker
    ↓
Supervisor processes and updates graph
    ↓
Response displayed in transcript + graph updates
```

**Code Reference:** [app.cl.jac:582-671](src/app.cl.jac#L582-L671)

### 3. Graph State Management

The task graph uses a **per-user node architecture**:

```javascript
node user_graph_data {
    has username: str = "anonymous";
    has nodes: list = ["Start"];      // Task names (e.g., ["Start", "WakeUp", "MakeCoffee"])
    has edges: list = [];             // Connections (e.g., [{"from": "Start", "to": "WakeUp"}])
    has last_task: str = "Start";     // Most recent task
    has saved_routines: dict = {};    // Saved routine snapshots
}
```

**Key Operations:**

1. **Initialize User Graph** ([app.jac:332-344](src/app.jac#L332-L344))
   - Creates `user_graph_data` node on first use
   - Attached to user's root node

2. **Update Graph** ([app.jac:378-424](src/app.jac#L378-L424))
   - Adds new task node
   - Creates edge from previous task
   - Updates last_task pointer
   - Generates DOT code for visualization

3. **Get Graph** ([app.jac:428-471](src/app.jac#L428-L471))
   - Retrieves current graph state
   - Generates fresh DOT code
   - Returns to frontend for rendering

4. **Clear Graph** ([app.jac:474-515](src/app.jac#L474-L515))
   - Resets to initial state
   - Preserves saved routines

5. **Save Routine** ([app.jac:518-576](src/app.jac#L518-L576))
   - Snapshots current graph
   - Stores in saved_routines dict
   - Timestamped for historical reference

---

## Frontend Implementation

### Component Architecture

```
app.cl.jac (Main App)
├── Header.jac (App header with logout)
├── MainApp (Main voice interface)
│   ├── TranscriptItem.jac (Message display)
│   ├── GraphViewer.jac (GraphViz rendering)
│   ├── MessageInput.jac (Text input)
│   └── ControlBar.jac (Voice controls)
├── LoginPage.jac (Authentication)
└── RegisterPage.jac (User registration)
```

### Key Frontend Components

#### 1. MainApp Component ([app.cl.jac:70-933](src/app.cl.jac#L70-L933))

**State Management:**
```javascript
// Connection state
[sessionStatus, setSessionStatus] = useState("DISCONNECTED");
sessionRef = useRef(None);

// UI state
[isPTTActive, setIsPTTActive] = useState(False);
[isMicMuted, setIsMicMuted] = useState(False);

// Message state
[transcript, setTranscript] = useState([]);

// Graph state
[graphDotCode, setGraphDotCode] = useState("");
[graphEdges, setGraphEdges] = useState([]);
[lastTask, setLastTask] = useState("Start");
```

**Critical Functions:**

- **connectToRealtime()** ([app.cl.jac:300-539](src/app.cl.jac#L300-L539))
  - Fetches ephemeral OpenAI key from backend
  - Creates Chat Agent with supervisor tool
  - Sets up event listeners for transcription, audio, tool calls
  - Loads user's existing graph on connection

- **executeSupervisorTool()** ([app.cl.jac:188-277](src/app.cl.jac#L188-L277))
  - Extracts username from JWT token
  - Calls backend `call_supervisor` walker
  - Fetches updated graph after supervisor completes
  - Returns response to Chat Agent

- **handleSendTextMessage()** ([app.cl.jac:582-671](src/app.cl.jac#L582-L671))
  - Handles text-only chat mode
  - Falls back to direct supervisor call if not connected
  - Updates graph visualization

#### 2. GraphViewer Component ([GraphViewer.jac:1-97](src/components/GraphViewer.jac#L1-L97))

**Rendering Pipeline:**
```javascript
DOT code → Graphviz.load() → graphviz.dot(dotCode) → SVG → dangerouslySetInnerHTML
```

**Features:**
- Lazy loads GraphViz WASM module
- Tracks previous DOT code to prevent unnecessary re-renders
- Handles empty state with placeholder UI
- Loading states for smooth UX

**Styling:**
- Start node: Green circle
- Task nodes: Blue rounded rectangles
- Edges: Optional labels (e.g., "then", "after")

#### 3. Event Handling

The frontend listens to multiple OpenAI Realtime API events:

1. **history_added** ([app.cl.jac:368-400](src/app.cl.jac#L368-L400))
   - New messages added to conversation
   - User/assistant messages
   - Function call notifications

2. **history_updated** ([app.cl.jac:403-436](src/app.cl.jac#L403-L436))
   - Message content updates
   - Transcription completions
   - Tool call status changes

3. **transport_event** ([app.cl.jac:439-467](src/app.cl.jac#L439-L467))
   - Real-time transcription deltas
   - Audio transcription completion
   - Streaming assistant responses

---

## Backend Implementation

### Walker Pattern

Jac uses **walkers** - specialized objects that traverse graph structures. Each walker has abilities that activate on specific node types.

**Example: update_task_graph Walker**

```jac
walker update_task_graph {
    has task_name: str;
    has previous_task: str = "Start";
    has edge_label: str = "";
    has username: str = "anonymous";

    can navigate_to_graph with `root entry;      # Ability 1: Find user's graph
    can update_graph with user_graph_data entry; # Ability 2: Update the graph
}
```

**Execution Flow:**
1. Walker spawned: `here spawn update_task_graph(task_name="MakeCoffee", ...)`
2. Starts at root node → `navigate_to_graph` ability fires
3. Navigates to user's `user_graph_data` node
4. `update_graph` ability fires
5. Graph updated, DOT code generated, report returned

### Key Backend Walkers

#### 1. get_session_token ([app.jac:229-275](src/app.jac#L229-L275))

**Purpose:** Fetch ephemeral OpenAI Realtime API key

**Implementation:**
```python
url = "https://api.openai.com/v1/realtime/client_secrets"
request_data = dumps({
    "session": {
        "type": "realtime",
        "model": "gpt-realtime"
    }
})
# POST request with OPENAI_API_KEY
# Returns ephemeral key with limited scope
```

**Security:** The ephemeral key has limited permissions and expiration, never exposing the main API key to frontend.

#### 2. call_supervisor ([app.jac:728-901](src/app.jac#L728-L901))

**Purpose:** Main backend intelligence - processes user requests through GPT-4.1

**Implementation Details:**

1. **Context Building**
   - Loads user's current graph state ([app.jac:748-761](src/app.jac#L748-L761))
   - Constructs prompt with conversation history
   - Includes current nodes, edges, and last task

2. **API Call Structure**
   ```json
   {
     "model": "gpt-4.1",
     "input": [
       {"type": "message", "role": "system", "content": "..."},
       {"type": "message", "role": "user", "content": "..."}
     ],
     "tools": [...],
     "parallel_tool_calls": false
   }
   ```

3. **Iterative Tool Execution** ([app.jac:807-878](src/app.jac#L807-L878))
   - Maximum 5 iterations
   - Processes function calls one at a time
   - Appends tool results back to input
   - Continues until no more function calls

4. **Tool Dispatching**
   - `updateTaskGraph`: Spawns `update_task_graph` walker
   - Other tools: Calls `execute_local_tool()` function

**Example Execution:**

```
User: "I'm making coffee"
    ↓
Supervisor receives context: "making coffee"
    ↓
GPT-4.1 calls: updateTaskGraph(taskName="MakeCoffee", previousTask="Start")
    ↓
Walker updates graph: ["Start", "MakeCoffee"], [{"from": "Start", "to": "MakeCoffee"}]
    ↓
Supervisor responds: "Got it! I've noted you're making coffee."
```

#### 3. update_task_graph ([app.jac:347-424](src/app.jac#L347-L424))

**Critical Logic:**

1. **User Isolation** ([app.jac:359-376](src/app.jac#L359-L376))
   ```jac
   all_graphs = [-->](`?user_graph_data);
   for graph in all_graphs {
       if hasattr(graph, 'username') and graph.username == self.username {
           user_graph = graph;
           break;
       }
   }
   ```

2. **Node Addition** ([app.jac:385-387](src/app.jac#L385-L387))
   - Checks if task already exists
   - Appends to nodes list if new

3. **Edge Creation** ([app.jac:390-408](src/app.jac#L390-L408))
   - Checks for duplicate connections
   - Creates edge from previous to current task
   - Adds optional label

4. **DOT Code Generation** ([app.jac:284-324](src/app.jac#L284-L324))
   ```jac
   def generate_dot_code(node_list: list, edge_list: list) -> str {
       lines = ["digraph TaskGraph {"];
       lines.append("  rankdir=TB;");  // Top-to-bottom layout

       // Style nodes
       for task_node in node_list {
           if task_node == "Start" {
               lines.append("  " + task_node + " [shape=circle, ...]");
           } else {
               lines.append("  " + task_node + " [style=\"rounded,filled\", ...]");
           }
       }

       // Add edges
       for conn in edge_list {
           lines.append("  " + from_task + " -> " + to_task + ";");
       }

       return "\n".join(lines);
   }
   ```

---

## Key Features Deep Dive

### 1. Real-Time Task Graph Generation

**How It Works:**

1. User mentions an activity: "I'm making coffee"
2. Chat Agent identifies action keyword
3. Calls `getNextResponseFromSupervisor` with context
4. Supervisor uses GPT-4.1 to:
   - Extract task name (MakeCoffee)
   - Determine previous task (last_task from graph)
   - Call `updateTaskGraph` tool
5. Backend walker updates graph structure
6. Frontend fetches updated graph
7. GraphViewer re-renders with new DOT code

**Intelligence:** The Supervisor ([app.jac:40-86](src/app.jac#L40-L86)) has detailed instructions on:
- When to update the graph (ANY action/task/activity)
- How to name tasks (CamelCase, 2-4 words)
- How to determine connections (look for "after X" phrases)
- Avoiding duplicates (check existing nodes first)

### 2. Routine Learning & Saving

**Save Routine Flow:**

```javascript
// Frontend: User clicks "Save & Restart"
handleSaveAndRestart() →
    calls save_routine walker →
        stores snapshot in user_graph_data.saved_routines

// Data structure:
{
    "daily_routine": {
        "nodes": ["Start", "WakeUp", "MakeCoffee", "Shower", ...],
        "edges": [{"from": "Start", "to": "WakeUp"}, ...],
        "saved_at": "1735689234.567"
    }
}
```

**Future Usage:** The saved routines can be loaded and provided as context to the Supervisor, enabling:
- "You usually make coffee after waking up"
- "This is different from your normal routine"
- Predicting next tasks
- Suggesting missed activities

### 3. User Isolation & Authentication

**Current Implementation (Development):**
- Manual username field passed with each request
- Walkers filter by username when finding graph nodes
- JWT tokens store username in payload

**Production Implementation (jac-scale):**
- Each authenticated user gets a unique root node (root_id)
- Walkers automatically run on user's root
- No manual username passing needed
- Native isolation at graph database level

**Code References:**
- Username extraction: [app.cl.jac:198-212](src/app.cl.jac#L198-L212)
- Graph filtering: [app.jac:360-373](src/app.jac#L360-L373)

### 4. Push-to-Talk vs. Continuous Mode

**Implementation:**

1. **PTT Mode** ([app.cl.jac:674-694](src/app.cl.jac#L674-L694))
   - User holds button to speak
   - `handleTalkButtonDown()`: Sets speaking state, interrupts AI
   - `handleTalkButtonUp()`: Stops recording
   - `sessionRef.current.interrupt()`: Stops AI mid-response

2. **Continuous Mode**
   - Always listening when connected
   - Voice Activity Detection (VAD) handled by OpenAI Realtime API
   - Automatic turn-taking

**UI Control:** [app.cl.jac:918-931](src/app.cl.jac#L918-L931) - ControlBar component

### 5. Microphone Mute & Audio Playback

**Mute Implementation:**
```javascript
useEffect(
    lambda -> None {
        if sessionRef.current {
            sessionRef.current.mute(isMicMuted);
        }
    },
    [isMicMuted, sessionStatus]
);
```

**Audio Playback:**
```javascript
el = document.createElement('audio');
el.autoplay = True;
audioElementRef.current = el;

// Toggle with:
audioElement.muted = not isAudioPlaybackEnabled;
```

---

## Code-Level Analysis

### Critical Code Sections

#### 1. Supervisor Tool Creation ([app.cl.jac:280-297](src/app.cl.jac#L280-L297))

```javascript
def createSupervisorTool() -> any {
    return tool({
        "name": "getNextResponseFromSupervisor",
        "description": "IMPORTANT: Before calling this tool, briefly acknowledge...",
        "parameters": {
            "type": "object",
            "properties": {
                "relevantContextFromLastUserMessage": {
                    "type": "string",
                    "description": "Key information from the user's most recent message."
                }
            },
            "required": ["relevantContextFromLastUserMessage"]
        },
        "execute": executeSupervisorTool
    });
}
```

**Why This Design?**
- Single tool keeps Chat Agent simple
- All complexity delegated to backend
- Context extraction happens at Chat Agent level
- Backend receives focused, relevant information

#### 2. Multi-Round Tool Execution ([app.jac:807-878](src/app.jac#L807-L878))

```python
while iteration < max_iterations {
    # Check for function calls
    function_calls = [];
    for item in output_items {
        if item["type"] == "function_call" {
            function_calls = function_calls + [item];
        }
    }

    if len(function_calls) == 0 {
        break;  # No more tools to execute
    }

    # Execute each tool
    for tool_call in function_calls {
        tool_output = execute_tool(tool_call);

        # Append call + result to input
        request_body["input"] = request_body["input"] + [
            {"type": "function_call", ...},
            {"type": "function_call_output", ...}
        ];
    }

    # Make follow-up request with tool results
    data = make_responses_api_call(request_body, api_key);
    iteration += 1;
}
```

**Why 5 Iterations?**
- Prevents infinite loops
- Allows chaining multiple tools (e.g., updateTaskGraph → getCalendarEvents)
- Most requests complete in 1-2 iterations

#### 3. Graph State Synchronization ([app.cl.jac:232-263](src/app.cl.jac#L232-L263))

After every supervisor call, the frontend immediately fetches the updated graph:

```javascript
try {
    graph_response = root spawn get_task_graph(username=username);

    if graph_response && graph_response.reports && graph_response.reports.length > 0 {
        graph_data = graph_response.reports[0];

        // Force state update by creating new references
        if graph_data.dotCode != None {
            newDotCode = String(graph_data.dotCode);
            setGraphDotCode(newDotCode);
        }
        if graph_data.edges != None {
            newEdges = Array.from(graph_data.edges);
            setGraphEdges(newEdges);
        }
        if graph_data.lastTask {
            setLastTask(graph_data.lastTask);
        }
    }
}
```

**React Immutability:** Creating new string/array references ensures React detects changes and re-renders.

### Performance Optimizations

1. **GraphViewer Memoization** ([GraphViewer.jac:19-23](src/components/GraphViewer.jac#L19-L23))
   - Tracks previous DOT code with useRef
   - Skips rendering if unchanged
   - Prevents unnecessary GraphViz recomputation

2. **Auto-Scroll Optimization** ([app.cl.jac:107-114](src/app.cl.jac#L107-L114))
   - useEffect with transcript dependency
   - Smooth scroll behavior
   - Only scrolls when new messages added

3. **Parallel Tool Execution Prevention**
   ```json
   "parallel_tool_calls": false
   ```
   - Sequential tool execution ensures graph consistency
   - Prevents race conditions in graph updates

---

## Future Improvements

### 1. Enhanced Routine Intelligence

**Current State:**
- Routines are saved but not actively used
- No predictive suggestions

**Proposed Enhancement:**
```jac
# Load past routines and provide as context
past_routines_context = load_past_routines_walker(username);

# Supervisor prompt addition:
"""
Based on past routines:
- After "WakeUp", user typically does "MakeCoffee" (90% of the time)
- Morning routine usually: WakeUp → MakeCoffee → Shower → Breakfast
- Suggest next logical step if user asks "what should I do next?"
"""
```

**Implementation:**
- Analyze saved routines for patterns
- Calculate frequency of task sequences
- Build Markov chain model of transitions
- Provide contextual suggestions

**Code Location:** [app.jac:743-745](src/app.jac#L743-L745) (currently commented out)

### 2. Real Integration with Calendar, Email, GitHub

**Current State:**
- Tool definitions exist ([app.jac:113-173](src/app.jac#L113-L173))
- Return sample/mock data ([app.jac:657-687](src/app.jac#L657-L687))

**Proposed Enhancement:**

**Calendar Integration:**
```jac
def execute_local_tool(tool_name: str, tool_args: object) -> dict {
    if tool_name == "getCalendarEvents" {
        # Google Calendar API
        calendar_api_key = getenv("GOOGLE_CALENDAR_API_KEY");
        date_filter = tool_args["date"];

        events = fetch_google_calendar(
            api_key=calendar_api_key,
            date=parse_date(date_filter)
        );

        return {"events": events, "query": date_filter};
    }
}
```

**Email Integration:**
```jac
# Gmail API or IMAP
def get_emails_impl(filter_type: str, count: int) -> list {
    gmail = Gmail(credentials=getenv("GMAIL_CREDENTIALS"));

    query = "is:unread" if filter_type == "unread" else "";
    messages = gmail.users().messages().list(
        userId="me",
        q=query,
        maxResults=count
    ).execute();

    return parse_messages(messages);
}
```

**GitHub Integration:**
```jac
# GitHub REST API
def get_github_issues_impl(repo: str, filter_type: str) -> list {
    token = getenv("GITHUB_TOKEN");
    url = f"https://api.github.com/repos/{repo}/issues";

    response = api_request(url, headers={"Authorization": f"token {token}"});
    issues = filter_by_state(response, filter_type);

    return issues;
}
```

### 3. Persistent Storage with Database

**Current State:**
- Data stored in in-memory graph nodes
- Lost on server restart

**Proposed Enhancement:**

**Option A: PostgreSQL Backend**
```jac
import from psycopg2 { connect }

node user_graph_data {
    has username: str;
    has nodes: list;
    has edges: list;
    has last_task: str;

    # Save to DB on update
    def persist(self) -> None {
        conn = connect(getenv("DATABASE_URL"));
        cursor = conn.cursor();

        cursor.execute("""
            INSERT INTO user_graphs (username, nodes, edges, last_task)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (username) DO UPDATE
            SET nodes = %s, edges = %s, last_task = %s
        """, (self.username, json.dumps(self.nodes), ...));

        conn.commit();
    }
}
```

**Option B: Redis for Speed**
```jac
import from redis { Redis }

redis_client = Redis(host='localhost', port=6379);

def save_user_graph(username: str, graph_data: dict) -> None {
    key = f"user_graph:{username}";
    redis_client.setex(key, 86400, json.dumps(graph_data));  # 24hr TTL
}
```

**Option C: Native Jac-Scale Persistence**
```jac
# jac-scale provides built-in persistence
# Nodes automatically persisted to backend store
# No additional code needed
```

### 4. Advanced Graph Visualization

**Current State:**
- Simple DOT rendering
- Static visualization

**Proposed Enhancements:**

**Interactive Graph:**
```javascript
import from "vis-network" { Network, DataSet }

def:pub InteractiveGraphViewer(props: any) -> any {
    nodes = DataSet(props.nodes);  # Convert to vis.js format
    edges = DataSet(props.edges);

    [network, setNetwork] = useState(None);

    useEffect(lambda -> None {
        container = document.getElementById('graph-container');
        data = {"nodes": nodes, "edges": edges};
        options = {
            "nodes": {"shape": "box", "color": "#3b82f6"},
            "edges": {"arrows": "to"},
            "physics": {"enabled": True}
        };

        network_instance = Network(container, data, options);
        setNetwork(network_instance);

        # Click handlers
        network_instance.on("selectNode", lambda params -> None {
            node_id = params.nodes[0];
            showTaskDetails(node_id);
        });
    }, [nodes, edges]);

    return <div id="graph-container" style={{"height": "600px"}} />;
}
```

**Timeline View:**
```javascript
# Show tasks chronologically with timestamps
def:pub TimelineView(props: any) -> any {
    tasks = props.tasks;  # [{"name": "WakeUp", "timestamp": 1735689234}, ...]

    return <div class="timeline">
        {tasks.map(task =>
            <div class="timeline-item">
                <span class="time">{formatTime(task.timestamp)}</span>
                <span class="task">{task.name}</span>
            </div>
        )}
    </div>;
}
```

**Heatmap Analysis:**
```javascript
# Show frequent task transitions
# MakeCoffee → Shower: 23 times
# WakeUp → CheckEmails: 15 times
```

### 5. Multi-Modal Input

**Current State:**
- Voice and text input

**Proposed Enhancement:**

**Image Recognition:**
```jac
# User shows what they're doing via camera
def analyze_activity_from_image(image_data: str) -> str {
    # OpenAI Vision API
    response = openai.chat.completions.create(
        model="gpt-4-vision",
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": "What activity is this person doing?"},
                {"type": "image_url", "image_url": {"url": image_data}}
            ]
        }]
    );

    activity = response.choices[0].message.content;
    return activity;  # "Making coffee", "Working on laptop", etc.
}
```

**Screen Recording:**
```jac
# Analyze what user is doing on their computer
def analyze_screen_activity(screenshot: str) -> str {
    # Detect apps being used
    # Infer tasks: "Coding in VSCode", "Checking emails in Gmail"
}
```

### 6. Natural Language Query Interface

**Proposed Feature:**
```
User: "Show me what I did yesterday"
    ↓
Query historical graphs → Render previous day's routine

User: "How often do I exercise?"
    ↓
Analyze all graphs → Count "Exercise" nodes → Calculate frequency

User: "What's my average morning routine?"
    ↓
Extract all morning tasks → Find most common sequence → Display pattern
```

**Implementation:**
```jac
walker query_historical_graphs {
    has query: str;
    has username: str;

    can analyze with `root entry {
        # Load all saved routines
        routines = get_all_routines(self.username);

        # Parse natural language query
        intent = parse_query_intent(self.query);

        if intent == "show_yesterday" {
            return get_graph_for_date(yesterday());
        } elif intent == "frequency" {
            task = extract_task_from_query(self.query);
            return calculate_task_frequency(routines, task);
        } elif intent == "pattern" {
            return find_common_pattern(routines);
        }
    }
}
```

### 7. Collaborative Routines

**Proposed Feature:**
- Share routines with friends/family
- Compare routines for optimization
- Team task coordination

```jac
node shared_routine {
    has owner: str;
    has shared_with: list;  # ["user1", "user2"]
    has routine_data: dict;
    has permissions: dict;  # {"user1": "view", "user2": "edit"}
}

walker share_routine {
    has routine_name: str;
    has share_with: str;
    has permission: str = "view";

    can share with user_graph_data entry {
        routine = here.saved_routines[self.routine_name];

        # Create shared routine node
        shared = here ++> shared_routine(
            owner=here.username,
            shared_with=[self.share_with],
            routine_data=routine,
            permissions={self.share_with: self.permission}
        );

        report {"success": True, "shared_id": shared.id};
    }
}
```

### 8. Smart Notifications & Reminders

**Proposed Feature:**
```jac
# Detect when user deviates from routine
walker monitor_routine_adherence {
    has username: str;
    has current_time: str;

    can check with user_graph_data entry {
        current_task = here.last_task;
        typical_routine = here.saved_routines["daily_routine"];

        # Check if user is on track
        expected_task = predict_task_at_time(typical_routine, current_time);

        if current_task != expected_task {
            send_reminder(f"You usually do {expected_task} at this time");
        }
    }
}
```

**Integration with Calendar:**
```jac
# Automatically update graph from calendar events
walker sync_calendar_to_graph {
    can sync with user_graph_data entry {
        events = get_calendar_events("today");

        for event in events {
            task_name = event["summary"];
            start_time = event["start"];

            # Auto-add to graph at scheduled time
            schedule_task_addition(task_name, start_time);
        }
    }
}
```

### 9. Advanced Analytics Dashboard

**Proposed UI:**
```javascript
def:pub AnalyticsDashboard() -> any {
    [stats, setStats] = useState({});

    useEffect(lambda -> None {
        response = root spawn get_analytics();
        setStats(response.reports[0]);
    }, []);

    return <div class="dashboard">
        <div class="stat-card">
            <h3>Total Tasks Today</h3>
            <p class="number">{stats.total_tasks}</p>
        </div>

        <div class="stat-card">
            <h3>Most Common Task</h3>
            <p>{stats.most_common_task}</p>
        </div>

        <div class="stat-card">
            <h3>Productivity Score</h3>
            <p class="number">{stats.productivity_score}%</p>
        </div>

        <div class="chart">
            <h3>Task Distribution</h3>
            <PieChart data={stats.task_distribution} />
        </div>

        <div class="chart">
            <h3>Activity Timeline</h3>
            <LineChart data={stats.timeline} />
        </div>
    </div>;
}
```

### 10. Voice Commands & Shortcuts

**Proposed Feature:**
```
"Show my routine" → Display current graph
"What did I do yesterday?" → Load historical graph
"Clear my tasks" → Reset graph
"Save this routine as 'Morning Routine'" → Save with custom name
"Load my evening routine" → Load specific saved routine
"Skip to lunch" → Jump to specific task in routine
```

**Implementation:**
```jac
# Add to Chat Agent instructions
glob CHAT_AGENT_COMMANDS = {
    "show my routine": "get_task_graph",
    "clear my tasks": "clear_graph",
    "save this routine": "save_routine",
    "what did I do yesterday": "query_historical"
};

# Chat Agent detects command and routes appropriately
```

---

## Technical Challenges & Solutions

### Challenge 1: Walker Spawn Result Handling

**Problem:**
```jac
# This doesn't work as expected:
result = here spawn get_task_graph(username=username);
graph_data = result.reports[0];  # Reports may not be immediately available
```

**Current Solution:**
- Call walker without capturing result
- Frontend separately calls `get_task_graph` after supervisor completes
- Two-step process ensures data consistency

**Future Solution:**
- Use jac-scale's native walker result handling
- Implement async/await pattern in Jac
- Better walker lifecycle management

### Challenge 2: User Isolation in Development

**Problem:**
- `jac serve` doesn't provide per-user root nodes
- Manual username filtering required
- Potential data leakage if not careful

**Current Solution:**
- Pass username with every walker call
- Filter graphs manually in walker implementation
- Decode JWT token in frontend to get username

**Production Solution:**
- Use `jac-scale` for deployment
- Automatic per-user root nodes
- Native authentication integration

### Challenge 3: Real-Time Graph Updates

**Problem:**
- Graph updates happen in backend
- Frontend needs immediate notification
- Polling is inefficient

**Current Solution:**
- Frontend fetches graph after every supervisor call
- Synchronous update flow

**Future Solution:**
- WebSocket connection for push updates
- Server-Sent Events (SSE) for graph changes
- Optimistic UI updates with rollback on error

### Challenge 4: DOT Code Size Limitations

**Problem:**
- Large graphs generate huge DOT strings
- Slow rendering
- Browser memory issues

**Current Solution:**
- Simple graphs with minimal styling
- Limited node/edge count in practice

**Future Solutions:**
- Implement graph pagination
- Virtual rendering for large graphs
- Use more efficient visualization library (D3.js, vis.js)
- Lazy load graph sections

---

## Security Considerations

### Current Security Measures

1. **API Key Protection**
   - OPENAI_API_KEY stored server-side only
   - Ephemeral keys with limited scope for frontend
   - Keys expire after session

2. **JWT Authentication**
   - Token-based auth for API calls
   - Username extracted from verified token
   - Protected routes in frontend

3. **Input Validation**
   - Task names sanitized (CamelCase, no special chars)
   - Username validation
   - Query parameter escaping

### Recommended Improvements

1. **Rate Limiting**
   ```jac
   walker rate_limiter {
       has max_requests: int = 100;
       has time_window: int = 3600;  # 1 hour

       can check with `root entry {
           user_requests = get_request_count(username);
           if user_requests > self.max_requests {
               report {"error": "Rate limit exceeded"};
               disengage;
           }
       }
   }
   ```

2. **Graph Size Limits**
   ```jac
   # Prevent abuse
   MAX_NODES = 1000;
   MAX_EDGES = 5000;

   if len(here.nodes) > MAX_NODES {
       report {"error": "Graph size limit exceeded"};
       return;
   }
   ```

3. **Content Filtering**
   ```jac
   # Prevent malicious task names
   def validate_task_name(name: str) -> bool {
       if contains_sql_injection(name) {
           return False;
       }
       if contains_xss(name) {
           return False;
       }
       return True;
   }
   ```

---

## Deployment Guide

### Development Setup

1. **Install Dependencies**
   ```bash
   jac add --cl  # Install client-side deps
   ```

2. **Set Environment Variables**
   ```bash
   export OPENAI_API_KEY='sk-...'
   ```

3. **Run Development Server**
   ```bash
   jac serve src/app.jac
   ```

4. **Access Application**
   ```
   http://localhost:8000
   ```

### Production Deployment

1. **Using jac-scale (Recommended)**
   ```bash
   # Build for production
   jac build src/app.jac --output dist/

   # Deploy with jac-scale
   jac-scale deploy dist/ --config production.toml
   ```

2. **Docker Deployment**
   ```dockerfile
   FROM jaseci/jac:latest

   WORKDIR /app
   COPY . .

   RUN jac add --cl

   ENV OPENAI_API_KEY=${OPENAI_API_KEY}

   EXPOSE 8000

   CMD ["jac", "serve", "src/app.jac", "--host", "0.0.0.0"]
   ```

3. **Environment Configuration**
   ```toml
   # production.toml
   [server]
   host = "0.0.0.0"
   port = 8000

   [database]
   url = "postgresql://user:pass@host/db"

   [auth]
   jwt_secret = "your-secret-key"
   token_expiry = 86400
   ```

---

## Conclusion

Algo represents a sophisticated blend of voice AI, graph databases, and real-time visualization. Its multi-agent architecture allows for complex task tracking while maintaining a simple user interface. The per-user isolation model ensures data privacy, and the routine learning system provides a foundation for intelligent personal assistance.

The future improvements outlined above would transform Algo from a task tracker into a comprehensive personal AI assistant with predictive capabilities, multi-modal input, and advanced analytics. The modular architecture makes these enhancements straightforward to implement incrementally.

**Key Strengths:**
- Clean separation of concerns (voice ↔ backend ↔ storage)
- Scalable per-user data model
- Real-time graph visualization
- Extensible tool system

**Areas for Enhancement:**
- Real integration with external APIs
- Persistent storage
- Advanced analytics
- Multi-modal input

Algo demonstrates the power of the Jac language and Jaseci framework for building complex, stateful AI applications with natural graph-based data models.
