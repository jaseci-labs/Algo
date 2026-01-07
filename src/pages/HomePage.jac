cl import from "@jac-client/utils" { jacIsLoggedIn, Navigate }

cl {
    def:pub HomePage() -> any {
        if jacIsLoggedIn() {
            return <Navigate to="/app" />;
        }
        return <Navigate to="/login" />;
    }
}