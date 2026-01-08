import from "@jac-client/utils" { jacIsLoggedIn, Navigate }

def:pub ProtectedRoute(children: any) -> any {
    if not jacIsLoggedIn() {
        return <Navigate to="/login" />;
    }
    return children;
}