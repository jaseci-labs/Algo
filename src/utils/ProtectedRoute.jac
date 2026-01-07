import from "@jac-client/utils" { jacIsLoggedIn, Navigate }

# Protected Route Component
def ProtectedRoute(props: any) -> any {
    if not jacIsLoggedIn() {
        return <Navigate to="/login" />;
    }
    return props.children;
}