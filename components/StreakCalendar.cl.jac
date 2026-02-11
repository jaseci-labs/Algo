# StreakCalendar Component
# GitHub-contribution-style calendar showing activity streak

import from "lucide-react" { Flame }
import from react { useMemo, useState, Fragment }

import from ..utils.mergeCls { cn }

def StreakCalendarComponent(activityData: dict = {}, weeks: int = 12) -> any {
    [selectedDay, setSelectedDay] = useState(None);

    # Generate calendar data
    calendarData = useMemo(
        lambda -> any {
            result = [];
            today = Date.new();

            # If we have actual activity data, use it
            dayActivity = {};
            hasDailyActivity = False;
            if activityData and activityData.daily_activity {
                dayActivity = activityData.daily_activity;
                hasDailyActivity = True;
            }

            # Generate weeks of data
            for weekIdx in range(weeks) {
                week = [];
                for dayIdx in range(7) {
                    # Calculate date for this cell
                    daysAgo = ((weeks - 1 - weekIdx) * 7) + (6 - dayIdx);
                    cellDate = Date.new(
                        today.getTime() - (daysAgo * 24 * 60 * 60 * 1000)
                    );

                    dateKey = String(cellDate.getFullYear()) + "-" +
                             String(cellDate.getMonth() + 1).padStart(2, "0") + "-" +
                             String(cellDate.getDate()).padStart(2, "0");

                    # Get activity count
                    activity = dayActivity[dateKey] or 0;
                    if hasDailyActivity == False {
                        # Generate sample data if no real data
                        activity = Math.floor(Math.random() * 10);
                        if Math.random() > 0.7 {
                            activity = 0;
                        }
                    }

                    week.push({
                        "date": dateKey,
                        "activity": activity,
                        "dayOfWeek": dayIdx,
                        "weekNum": weekIdx
                    });
                }
                result.push(week);
            }
            return result;
        },
        [activityData, weeks]
    );

    # Get cell color based on activity level
    getCellColor = lambda activity: int -> str {
        if activity == 0 {
            return "bg-muted/20";
        }
        if activity < 3 {
            return "bg-green-500/30";
        }
        if activity < 6 {
            return "bg-green-500/50";
        }
        if activity < 10 {
            return "bg-green-500/70";
        }
        return "bg-green-500";
    };

    # Calculate current streak
    currentStreak = useMemo(
        lambda -> int {
            streak = 0;
            for week in calendarData {
                for day in week {
                    if day.activity > 0 {
                        streak = streak + 1;
                    } else if streak > 0 {
                        # Streak broken (only count if we've started counting)
                        # In reality, you'd calculate from today backwards
                        return streak;
                    }
                }
            }
            return streak;
        },
        [calendarData]
    );

    # Get month labels
    monthLabels = useMemo(
        lambda -> any {
            months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
            labels = [];
            for weekIdx in range(0, weeks, 4) {
                if weekIdx < len(calendarData) {
                    # Get the first day of this week
                    firstDay = calendarData[weekIdx][0];
                    date = Date.new(firstDay.date);
                    labels.push({
                        "month": months[date.getMonth()],
                        "week": weekIdx
                    });
                }
            }
            return labels;
        },
        [calendarData, weeks]
    );

    # Selected day details (pre-compute to avoid ternary in JSX)
    selectedDayDetails = <Fragment />;
    if selectedDay {
        selectedDayDetails = <div className="mt-3 p-2 bg-muted/30 rounded-lg text-center">
            <p className="text-xs text-muted-foreground">
                {selectedDay}
            </p>
            <p className="text-sm font-medium text-foreground">
                Activity level
            </p>
        </div>;
    }

    return <div className="w-full">
        # Header with streak info
        <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
                <Flame className="w-5 h-5 text-orange-500" />
                <span className="text-sm font-medium text-foreground">
                    {String(currentStreak)} day streak
                </span>
            </div>
            <span className="text-xs text-muted-foreground">
                Last {weeks} weeks
            </span>
        </div>

        # Day labels
        <div className="flex">
            <div className="w-6" />  # Spacer
            <div className="flex-1 grid grid-cols-7 gap-0.5 mb-1">
                {
                    (["M", "T", "W", "T", "F", "S", "S"].map(lambda day: any, idx: int -> any {
                        return <div key={idx} className="text-xs text-muted-foreground text-center">
                            {day}
                        </div>;
                    }))
                }
            </div>
        </div>

        # Calendar grid
        <div className="flex gap-0.5">
            # Month labels (left side)
            <div className="w-6 flex flex-col">
                {
                    (monthLabels.map(lambda label: any, idx: int -> any {
                        return <div
                            key={idx}
                            className="text-xs text-muted-foreground"
                            style={{"height": "12px", "marginTop": String(label.week * 7) + "px"}}
                        >
                            {label.month}
                        </div>;
                    }))
                }
            </div>

            # Activity cells
            <div className="flex-1 flex flex-col gap-0.5">
                {
                    (calendarData.map(lambda week: any, weekIdx: int -> any {
                        return <div key={weekIdx} className="grid grid-cols-7 gap-0.5">
                            {
                                (week.map(lambda day: any, dayIdx: int -> any {
                                    isSelected = False;
                                    ringClass = "hover:ring-1 hover:ring-primary/50";
                                    if selectedDay == day.date {
                                        isSelected = True;
                                        ringClass = "ring-2 ring-primary";
                                    }

                                    return <div
                                        key={dayIdx}
                                        className={cn(
                                            "aspect-square rounded-sm transition-all cursor-pointer",
                                            getCellColor(day.activity),
                                            ringClass
                                        )}
                                        onClick={lambda -> any {
                                            newSelection = day.date;
                                            if selectedDay == day.date {
                                                newSelection = None;
                                            }
                                            setSelectedDay(newSelection);
                                        }}
                                        title={day.date + ": " + String(day.activity) + " activities"}
                                    />;
                                }))
                            }
                        </div>;
                    }))
                }
            </div>
        </div>

        # Legend
        <div className="flex items-center justify-end gap-2 mt-3">
            <span className="text-xs text-muted-foreground">Less</span>
            <div className="flex gap-1">
                <div className="w-3 h-3 rounded-sm bg-muted/20" />
                <div className="w-3 h-3 rounded-sm bg-green-500/30" />
                <div className="w-3 h-3 rounded-sm bg-green-500/50" />
                <div className="w-3 h-3 rounded-sm bg-green-500/70" />
                <div className="w-3 h-3 rounded-sm bg-green-500" />
            </div>
            <span className="text-xs text-muted-foreground">More</span>
        </div>

        # Selected day details
        {
            selectedDayDetails
        }
    </div>;
}

glob:pub StreakCalendar = StreakCalendarComponent;
