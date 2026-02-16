# TemporalHeatmap Component
# Displays activity heatmap by hour and day

import from react { useMemo }

import from ..utils.mergeCls { cn }

def TemporalHeatmapComponent(data: dict = {}) -> any {
    # Days of week
    days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    hours = ["6a", "8a", "10a", "12p", "2p", "4p", "6p", "8p", "10p"];

    # Generate heatmap data
    heatmapData = useMemo(
        lambda -> any {
            result = [];

            # If we have actual data, use it; otherwise generate mock data
            hasData = False;
            if data and data.hourly_activity {
                hasData = True;
                hourlyData = data.hourly_activity;
                for dayIdx in range(7) {
                    row = [];
                    for hourIdx in range(9) {
                        hourValue = (hourIdx * 2) + 6;  # 6, 8, 10, 12, 14, 16, 18, 20, 22
                        key = String(dayIdx) + "-" + String(hourValue);
                        activity = hourlyData[key] or 0;
                        row.push({"day": dayIdx, "hour": hourValue, "activity": activity});
                    }
                    result.push(row);
                }
            } else {
                # Generate some sample data for visualization
                for dayIdx in range(7) {
                    row = [];
                    for hourIdx in range(9) {
                        hourValue = (hourIdx * 2) + 6;
                        # Simulated: higher activity during weekday mornings/evenings
                        baseActivity = Math.random() * 50;
                        if dayIdx < 5 and (hourValue == 9 or hourValue == 18) {
                            baseActivity = baseActivity + 50;
                        }
                        row.push({"day": dayIdx, "hour": hourValue, "activity": baseActivity});
                    }
                    result.push(row);
                }
            }
            return result;
        },
        [data]
    );

    # Get cell color based on activity level
    getCellColor = lambda activity: int -> str {
        if activity == 0 {
            return "bg-muted/20";
        }
        if activity < 25 {
            return "bg-primary/20";
        }
        if activity < 50 {
            return "bg-primary/40";
        }
        if activity < 75 {
            return "bg-primary/60";
        }
        return "bg-primary/80";
    };

    return <div className="w-full">
        # Hour labels
        <div className="flex">
            <div className="w-8" />  # Spacer for day labels
            <div className="flex-1 grid grid-cols-9 gap-1">
                {
                    (hours.map(lambda hour: any, idx: int -> any {
                        return <div key={idx} className="text-xs text-muted-foreground text-center">
                            {hour}
                        </div>;
                    }))
                }
            </div>
        </div>

        # Heatmap grid
        <div className="flex flex-col gap-1">
            {
                (heatmapData.map(lambda row: any, rowIdx: int -> any {
                    return <div key={rowIdx} className="flex items-center gap-1">
                        # Day label
                        <div className="w-8 text-xs text-muted-foreground text-right">
                            {days[rowIdx]}
                        </div>
                        # Activity cells
                        <div className="flex-1 grid grid-cols-9 gap-1">
                            {
                                (row.map(lambda cell: any, cellIdx: int -> any {
                                    dayLabel = days[cell.day];
                                    activityRounded = Math.round(cell.activity, 0);
                                    return <div
                                        key={cellIdx}
                                        className={cn(
                                            "aspect-square rounded-sm transition-all hover:ring-1 hover:ring-primary/50 cursor-pointer",
                                            getCellColor(cell.activity)
                                        )}
                                        title={dayLabel + " at " + String(cell.hour) + ":00 - " + String(activityRounded) + " activities"}
                                    />;
                                }))
                            }
                        </div>
                    </div>;
                }))
            }
        </div>

        # Legend
        <div className="flex items-center justify-center gap-2 mt-3">
            <span className="text-xs text-muted-foreground">Less</span>
            <div className="flex gap-1">
                <div className="w-4 h-4 rounded-sm bg-muted/20" />
                <div className="w-4 h-4 rounded-sm bg-primary/20" />
                <div className="w-4 h-4 rounded-sm bg-primary/40" />
                <div className="w-4 h-4 rounded-sm bg-primary/60" />
                <div className="w-4 h-4 rounded-sm bg-primary/80" />
            </div>
            <span className="text-xs text-muted-foreground">More</span>
        </div>
    </div>;
}

glob:pub TemporalHeatmap = TemporalHeatmapComponent;
