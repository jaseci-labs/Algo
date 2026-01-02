# Proactive Agent Enhancement Guide

## Overview
The Algo agent has been enhanced to be **proactive** rather than reactive. It now actively learns about users, asks clarifying questions, analyzes patterns, and suggests activities.

## Key Changes

### 1. New Data Structure: `user_insights` Node
A new node type tracks user behavior and learning:
- **total_interactions**: Count of interactions with the agent
- **common_sequences**: Identified patterns in task sequences
- **time_patterns**: When users typically do things (future expansion)
- **preferences**: Learned user preferences
- **last_questions_asked**: Tracks questions to avoid repetition
- **unanswered_questions**: Questions user hasn't responded to yet

### 2. Enhanced Supervisor Instructions
The supervisor agent now:
- **Actively asks questions** to understand users better
- **Analyzes patterns** in user routines
- **Suggests activities** based on learned behavior
- **Builds comprehensive understanding** of habits and goals

### 3. New Proactive Tools

#### `analyzeRoutinePattern`
Analyzes the current task graph to identify:
- Common task sequences (e.g., "WakeUp → MakeCoffee → CheckEmails")
- Frequently performed tasks
- Potential optimization opportunities

**Example Usage:**
```
Agent: "I notice you've completed several tasks. Let me analyze your routine pattern..."
[Calls analyzeRoutinePattern with focus="sequences"]
Agent: "You have a clear morning routine: you always check emails after making coffee!"
```

#### `askClarifyingQuestion`
Asks targeted questions to learn more about user habits:
- **Timing**: "What time do you usually wake up?"
- **Duration**: "How long does your morning workout take?"
- **Purpose**: "What's your goal with this routine?"
- **Preference**: "Do you prefer coffee or tea?"
- **Frequency**: "How often do you go to the gym?"

**Example Usage:**
```
Agent: "How long does your morning coffee routine usually take?"
[Tracks question to avoid asking again]
```

#### `suggestNextActivity`
Proactively suggests what to do next based on:
- Past behavior patterns
- Current time of day
- Common sequences from routines

**Example Usage:**
```
User: "I'm done with breakfast, what should I do?"
Agent: [Calls suggestNextActivity]
Agent: "Based on your pattern, you usually go for a run after breakfast. Would you like to do that?"
```

### 4. Pattern Analysis Function
The `analyze_task_patterns()` function:
- Identifies common task sequences
- Counts task frequency
- Provides insights on routine structure

### 5. Insight Tracking Walkers

#### `update_user_insights`
Stores various types of insights:
- Interaction counts
- Questions asked
- Identified patterns
- User preferences

#### `get_user_insights`
Retrieves stored insights to inform proactive suggestions

## How Proactivity Works

### Behavioral Rules
1. **Ask 1-2 clarifying questions per conversation** (don't overwhelm)
2. **Suggest activities when user seems uncertain**
3. **Provide insights about routines** ("You've been consistent!")
4. **Offer optimizations** ("You could save time by...")
5. **Track unanswered questions** and revisit them

### Progressive Learning
As interactions increase, the agent becomes more knowledgeable:

**Interaction 1-2:** Basic task tracking
```
User: "I'm making coffee"
Agent: "Got it, added MakeCoffee to your routine!"
```

**Interaction 3-5:** Starting to ask questions
```
User: "I'm checking emails"
Agent: "Added CheckEmails. By the way, what time do you usually start your day?"
```

**Interaction 6+:** Pattern analysis and suggestions
```
User: "What should I do next?"
Agent: "I've noticed you usually go for a run after breakfast. Would you like to do that? It's typically around this time in your routine."
```

### Context-Aware Responses
The agent now receives:
- **Current task graph** (what user is doing today)
- **User insights** (patterns, preferences, questions asked)
- **Interaction count** (how well agent knows the user)

This enables responses like:
- "I notice you always do X before Y. Is there a reason for that order?"
- "You've completed your morning routine 5 minutes faster than usual!"
- "Based on yesterday, you usually meditate after lunch. Shall I remind you?"

## Example Conversation Flow

```
User: "Hey Algo, I just woke up"
Agent: "Good morning! I've noted you're starting your day. What's the first thing you'd like to do?"

User: "Making some coffee"
Agent: "Added MakeCoffee to your routine! Quick question - how long does your coffee routine usually take?"

User: "About 10 minutes"
Agent: [Stores preference: coffee_duration=10] "Got it, thanks! That helps me understand your schedule better."

User: "Now I'm checking emails"
Agent: "Added CheckEmails. I'm starting to see a pattern - you seem to check emails right after coffee. Is that intentional?"

User: "Yes, it helps me plan my day"
Agent: [Stores pattern: MakeCoffee→CheckEmails] "That makes sense! Would you like me to suggest what typically comes next in your routine?"

User: "Sure"
Agent: "Based on what I've learned, people often do a morning workout or meditation after reviewing emails. Which would you prefer?"
```

## Technical Implementation

### Walker Flow
1. **User says something** → Voice agent processes
2. **call_supervisor walker** → Loads user insights + graph data
3. **Supervisor analyzes** → Checks interaction count and patterns
4. **Proactive decision** → Should I ask a question? Suggest something?
5. **Tool execution** → Calls appropriate proactive tool
6. **Insight tracking** → Updates user_insights node
7. **Natural response** → Returns conversational answer

### Data Persistence
All insights are stored per-user in the `user_insights` node:
- Survives session resets
- Builds long-term understanding
- Enables day-to-day learning

## Benefits

1. **Deeper Understanding**: Agent learns user habits over time
2. **Personalized Experience**: Suggestions based on actual behavior
3. **Anticipatory**: Suggests activities before being asked
4. **Efficient**: Optimizes routines based on patterns
5. **Engaging**: Natural conversation that shows genuine interest

## Future Enhancements

Possible additions:
- **Time-based patterns**: Learn when user does specific tasks
- **Context switching**: Detect when user changes routines (weekend vs weekday)
- **Goal tracking**: Help user achieve specific objectives
- **Habit reinforcement**: Celebrate consistency and streaks
- **Anomaly detection**: Notice when user breaks their pattern
- **Predictive suggestions**: "You usually go to the gym now, want me to check your gym's schedule?"

## Usage Tips

### For Users
- Answer the agent's questions to help it learn faster
- Be consistent with task naming (the agent will match patterns)
- Give feedback on suggestions ("Yes, that's perfect!" or "Not today")

### For Developers
- Monitor `user_insights.total_interactions` to adjust proactivity level
- Use `last_questions_asked` to avoid repetition
- Combine pattern analysis with calendar/email data for richer insights
- Consider adding webhook integrations for external habit tracking

## Conclusion

The agent is now a **learning companion** that grows smarter with each interaction. It doesn't just respond to what you say—it actively works to understand you better and provide genuinely helpful, anticipatory assistance.
