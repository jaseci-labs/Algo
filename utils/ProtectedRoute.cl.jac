import from "@jac/runtime" { jacIsLoggedIn, Navigate }

def:pub ProtectedRoute(props: any) -> any {
    if not jacIsLoggedIn() {
        return <Navigate to="/login" />;
    }
    return props.children;
}
