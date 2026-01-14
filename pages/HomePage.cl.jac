import from "@jac-client/utils" { jacIsLoggedIn, Navigate }

def:pub HomePage() -> any {
    if jacIsLoggedIn() {
        return <Navigate to="/app" />;
    }
    return <Navigate to="/login" />;
}