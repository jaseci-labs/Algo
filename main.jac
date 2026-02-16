import from service.mainAppService {
    get_session_token,
    init_user_graph,
    update_task_graph,
    get_task_graph,
    clear_graph,
    save_routine,
    load_past_routines,
    reset_session,
    rebuild_graph,
    rename_task,
    call_manager,
    get_activity_report,
    get_trend_analysis,
    analyze_behavioral_patterns,
    calculate_productivity_metrics,
    generate_insights,
    log_activity_event,
    discover_patterns,
    get_temporal_insights,
    get_comparative_insights,
    create_goal,
    get_goals,
    update_goal_progress,
    check_achievements,
    get_achievements,
    get_proactive_insights,
    mark_insight_viewed,
    mark_insight_acted_upon,
    dismiss_insight,
}

cl import from .index { app as ClientApp }


cl {
    def:pub app() -> any {
        return <ClientApp />;
    }
}