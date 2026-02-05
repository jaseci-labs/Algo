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
    generate_insights
}

cl import from .index { app as ClientApp }


cl {
    def:pub app() -> any {
        return <ClientApp />;
    }
}