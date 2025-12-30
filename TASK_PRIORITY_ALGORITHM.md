# Task Priority Algorithm - Brainstorming Document

> **Goal**: Design an intelligent priority system that learns how the user thinks and adapts to their working style.

---

## 🎯 Core Philosophy

The AI should act as a **personalized thinking partner**, not just a task manager. It should:
- Understand the user's mental model of importance
- Learn from their behavior patterns
- Adapt priorities dynamically based on context
- Reduce cognitive load by making smart decisions

---

## 📊 Priority Scoring Algorithm

### Multi-Factor Weighted Score

```
Priority Score = Σ (Factor_weight × Factor_score)
```

### Factors to Consider

| Factor | Weight Range | Description |
|--------|-------------|-------------|
| **Urgency** | 0.0 - 1.0 | Time until deadline |
| **Importance** | 0.0 - 1.0 | Impact if not completed |
| **User Preference** | 0.0 - 1.0 | Learned from past behavior |
| **Dependencies** | 0.0 - 1.0 | Blocks other tasks? |
| **Effort Estimate** | 0.0 - 1.0 | Quick wins vs deep work |
| **Context Match** | 0.0 - 1.0 | Right time/place/energy? |
| **Source Priority** | 0.0 - 1.0 | Who assigned it? (boss vs self) |

---

## 🧮 Proposed Algorithm: Adaptive Priority Engine (APE)

### 1. Urgency Score (Eisenhower-inspired)

```python
def calculate_urgency(deadline, current_time):
    if deadline is None:
        return 0.3  # Default for no deadline
    
    hours_remaining = (deadline - current_time).total_hours()
    
    if hours_remaining <= 0:
        return 1.0  # OVERDUE - Maximum urgency
    elif hours_remaining <= 24:
        return 0.95  # Due today
    elif hours_remaining <= 48:
        return 0.8   # Due tomorrow
    elif hours_remaining <= 168:  # 1 week
        return 0.6
    elif hours_remaining <= 720:  # 1 month
        return 0.4
    else:
        return 0.2
```

### 2. Importance Score

Importance is subjective and should be **learned from user behavior**:

```python
def calculate_importance(task):
    base_score = 0.5
    
    # Source-based importance
    if task.source == "manager" or task.source == "calendar_event":
        base_score += 0.3
    elif task.source == "github_issue":
        base_score += 0.2
    elif task.source == "google_meet_action_item":
        base_score += 0.25
    
    # Keyword-based importance (learned over time)
    important_keywords = ["urgent", "critical", "blocker", "deadline", "asap"]
    if any(kw in task.description.lower() for kw in important_keywords):
        base_score += 0.2
    
    # User-defined importance (explicit rating 1-5)
    if task.user_importance:
        base_score = task.user_importance / 5.0
    
    return min(base_score, 1.0)
```

### 3. User Preference Score (Learning Component)

This is where the AI **learns how the user thinks**:

```python
def calculate_user_preference(task, user_profile):
    """
    Learn from:
    1. Which tasks user completes first
    2. Which tasks user procrastinates on
    3. Time of day preferences
    4. Task type preferences
    """
    
    # Historical completion patterns
    similar_tasks = find_similar_completed_tasks(task, user_profile)
    
    if similar_tasks:
        # Average priority at which similar tasks were completed
        avg_completion_priority = mean([t.completion_order for t in similar_tasks])
        preference_score = 1.0 - (avg_completion_priority / total_tasks)
    else:
        preference_score = 0.5  # Neutral for new task types
    
    # Time-of-day matching
    current_hour = now().hour
    if user_profile.peak_hours and current_hour in user_profile.peak_hours:
        if task.requires_deep_focus:
            preference_score += 0.15
    
    return preference_score
```

### 4. Context Match Score

```python
def calculate_context_match(task, current_context):
    score = 0.5
    
    # Energy level matching
    if current_context.energy_level == "high" and task.effort == "high":
        score += 0.2
    elif current_context.energy_level == "low" and task.effort == "low":
        score += 0.2  # Good for quick wins when tired
    
    # Location matching
    if task.requires_location and task.location == current_context.location:
        score += 0.15
    
    # Tool/resource availability
    if task.required_tools and all(t in current_context.available_tools for t in task.required_tools):
        score += 0.1
    
    return score
```

---

## 🔄 Dynamic Weight Adjustment

Weights should **adapt based on user behavior**:

```python
class AdaptiveWeights:
    def __init__(self):
        self.weights = {
            "urgency": 0.25,
            "importance": 0.25,
            "user_preference": 0.20,
            "dependencies": 0.10,
            "effort": 0.10,
            "context": 0.10
        }
    
    def learn_from_completion(self, task, completion_data):
        """
        If user consistently overrides urgency to do important tasks,
        increase importance weight and decrease urgency weight.
        """
        expected_order = self.get_expected_priority_order()
        actual_order = completion_data.actual_completion_order
        
        # Analyze which factors led to user's actual choices
        for completed_task in actual_order:
            if completed_task != expected_order[0]:
                # User overrode our suggestion
                # Analyze why and adjust weights
                self.adjust_weights(expected_order[0], completed_task)
```

---

## 💾 Data Storage Schema

### Task Object

```json
{
  "id": "uuid",
  "title": "string",
  "description": "string",
  "created_at": "datetime",
  "updated_at": "datetime",
  
  "deadline": "datetime | null",
  "source": {
    "type": "github_issue | google_calendar | google_meet | gmail | manual",
    "external_id": "string",
    "link": "url"
  },
  
  "priority": {
    "computed_score": 0.85,
    "user_override": null,
    "factors": {
      "urgency": 0.9,
      "importance": 0.8,
      "user_preference": 0.7,
      "dependencies": 0.5,
      "effort": 0.6,
      "context_match": 0.8
    }
  },
  
  "status": "not_started | in_progress | completed | deferred | cancelled",
  "completion": {
    "completed_at": "datetime | null",
    "time_spent_minutes": 45,
    "completion_order": 3,
    "was_on_time": true
  },
  
  "metadata": {
    "estimated_effort": "low | medium | high",
    "actual_effort": "low | medium | high",
    "requires_deep_focus": true,
    "tags": ["work", "coding", "meeting-followup"],
    "project": "project_id",
    "blocking_tasks": ["task_id_1", "task_id_2"],
    "blocked_by": ["task_id_3"]
  },
  
  "learning_data": {
    "times_deferred": 2,
    "times_priority_changed": 1,
    "user_feedback": "positive | negative | neutral"
  }
}
```

### User Profile (Learning Storage)

```json
{
  "user_id": "uuid",
  
  "work_patterns": {
    "peak_productivity_hours": [9, 10, 11, 14, 15],
    "preferred_task_order": "urgent_first | important_first | quick_wins_first | mixed",
    "average_tasks_per_day": 8,
    "completion_rate": 0.75
  },
  
  "preferences": {
    "weight_overrides": {
      "urgency": 0.30,
      "importance": 0.35
    },
    "notification_preferences": {
      "daily_brief_time": "08:00",
      "reminder_before_deadline_hours": 24
    }
  },
  
  "learning_history": {
    "total_tasks_completed": 342,
    "average_priority_deviation": 0.15,
    "common_defer_patterns": [
      {"task_type": "documentation", "avg_defer_count": 2.3},
      {"task_type": "code_review", "avg_defer_count": 0.5}
    ],
    "completion_time_accuracy": 0.72
  },
  
  "source_trust_scores": {
    "manager_email": 0.95,
    "github_issue": 0.80,
    "self_created": 0.70,
    "google_meet_summary": 0.85
  }
}
```

### Completion History (For Learning)

```json
{
  "date": "2025-12-30",
  "tasks_presented": ["task_1", "task_2", "task_3"],
  "presentation_order": ["task_1", "task_2", "task_3"],
  "actual_completion_order": ["task_2", "task_1", "task_3"],
  "deferred_tasks": ["task_4"],
  "incomplete_tasks": ["task_5"],
  
  "context_snapshot": {
    "calendar_events": 3,
    "meetings_hours": 2.5,
    "energy_reported": "medium"
  },
  
  "feedback": {
    "priority_helpful": true,
    "override_reasons": ["task_2 had urgent stakeholder request"]
  }
}
```

---

## 🧠 Learning Mechanisms

### 1. Completion Order Learning

```python
def learn_from_daily_completion(date, presented_order, actual_order):
    """
    Compare AI's suggested order vs user's actual completion order.
    Use this to adjust future predictions.
    """
    for i, (expected, actual) in enumerate(zip(presented_order, actual_order)):
        if expected != actual:
            # Record the deviation
            deviation = {
                "expected_task": expected,
                "actual_task": actual,
                "position": i,
                "expected_factors": get_task_factors(expected),
                "actual_factors": get_task_factors(actual)
            }
            
            # Analyze what factor caused the override
            analyze_and_update_weights(deviation)
```

### 2. Procrastination Pattern Detection

```python
def detect_procrastination_patterns(user_history):
    """
    Identify tasks the user consistently defers.
    Use this to either:
    1. Lower their priority (user doesn't want to do them)
    2. Raise their priority with reminders (user needs push)
    """
    defer_patterns = {}
    
    for task in user_history.all_tasks:
        if task.times_deferred > 1:
            task_type = classify_task(task)
            if task_type not in defer_patterns:
                defer_patterns[task_type] = []
            defer_patterns[task_type].append(task)
    
    return defer_patterns
```

### 3. Time Estimation Improvement

```python
def improve_time_estimates(task_type, historical_tasks):
    """
    Learn how long tasks actually take vs estimates.
    """
    actual_times = [t.actual_time for t in historical_tasks if t.task_type == task_type]
    estimated_times = [t.estimated_time for t in historical_tasks if t.task_type == task_type]
    
    # Calculate adjustment factor
    if actual_times and estimated_times:
        adjustment_factor = mean(actual_times) / mean(estimated_times)
        return adjustment_factor
    return 1.0
```

---

## 🔔 Integration with Notifications

### Daily Brief Generation

```python
def generate_daily_brief(user, date):
    """
    Morning notification with prioritized task list.
    """
    tasks = get_tasks_for_date(user, date)
    prioritized = sort_by_priority(tasks)
    
    brief = {
        "top_3_priorities": prioritized[:3],
        "total_tasks": len(tasks),
        "estimated_total_time": sum(t.estimated_time for t in tasks),
        "calendar_conflicts": detect_conflicts(tasks, user.calendar),
        "suggestions": generate_suggestions(prioritized)
    }
    
    return brief
```

### Smart Reminders

```python
def should_send_reminder(task, current_context):
    """
    Intelligent reminders based on:
    - Deadline proximity
    - Current availability
    - Task dependencies
    """
    if task.deadline:
        hours_until = (task.deadline - now()).hours
        if hours_until <= task.estimated_time * 2:
            return True, "Deadline approaching"
    
    if task.blocks_other_tasks:
        blocked_urgency = max(t.urgency for t in task.blocked_tasks)
        if blocked_urgency > 0.8:
            return True, "Blocking high-priority tasks"
    
    return False, None
```

---

## 🎯 Priority Override Handling

When user manually overrides priority:

```python
def handle_priority_override(task, old_priority, new_priority, reason=None):
    """
    Learn from explicit user overrides.
    """
    override_record = {
        "task_id": task.id,
        "old_priority": old_priority,
        "new_priority": new_priority,
        "reason": reason,
        "task_factors": task.priority.factors,
        "timestamp": now()
    }
    
    # Store for learning
    save_override(override_record)
    
    # If reason provided, extract learnable patterns
    if reason:
        patterns = extract_patterns_from_reason(reason)
        update_priority_rules(patterns)
```

---

## 📈 Success Metrics

Track these to evaluate algorithm effectiveness:

| Metric | Target | Description |
|--------|--------|-------------|
| **Priority Accuracy** | >80% | How often user follows suggested order |
| **Override Rate** | <20% | How often user changes priority |
| **Completion Rate** | >75% | Tasks completed vs created |
| **On-Time Rate** | >85% | Tasks completed before deadline |
| **User Satisfaction** | >4/5 | Explicit feedback scores |

---

## 🚀 Implementation Phases

### Phase 1: Basic Priority (Rule-Based)
- Simple urgency + importance scoring
- Manual priority setting
- Basic deadline tracking

### Phase 2: Source Integration
- GitHub issues integration
- Google Calendar sync
- Gmail task extraction
- Google Meet summary → action items

### Phase 3: Learning System
- Completion pattern analysis
- Weight adjustment
- Procrastination detection
- Time estimation improvement

### Phase 4: Contextual Intelligence
- Energy level awareness
- Location-based suggestions
- Real-time context switching
- Proactive suggestions ("You have 30 mins before your meeting, want to tackle a quick task?")

---

## 💡 Open Questions to Explore

1. **How to handle conflicting signals?** (Urgent but user always defers this type)
2. **Should AI ever hide low-priority tasks?** (Reduce cognitive load)
3. **How to balance learning speed vs stability?** (Don't overfit to recent behavior)
4. **Privacy considerations** - How much user data to store?
5. **How to handle task dependencies across projects?**

---

## 🔗 Related Integrations

- **Google Calendar**: Extract events, deadlines, meeting prep tasks
- **Gmail**: Extract action items, follow-ups, deadline mentions
- **GitHub Issues**: Import assigned issues, track PR reviews
- **Google Meet**: Process meeting summaries for action items
- **Voice Input**: Natural language task creation with automatic priority inference

---

*Last Updated: December 30, 2025*
*Status: Brainstorming*
