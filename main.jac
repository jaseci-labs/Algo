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
    call_manager
}

cl import from .index { app as ClientApp }


cl {
    def:pub app() -> any {
        return <ClientApp />;
    }
}