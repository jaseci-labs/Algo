cl import from "@jac-client/utils" { jacIsLoggedIn, Navigate }

# Home Route - Redirect based on auth status
def HomePage() -> any {
    if jacIsLoggedIn() {
        return <Navigate to="/app" />;
    }
    return <Navigate to="/login" />;
}
