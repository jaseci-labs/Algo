cl import from react { useState, useEffect, useRef }
cl import from "@jac-client/utils" { Router, Routes, Route }

cl import from .pages.MainApp { MainApp }
cl import from .pages.HomePage { HomePage }
cl import from .pages.LoginPage { LoginPage }
cl import from .pages.RegisterPage { RegisterPage }

cl import from .utils.ProtectedRoute { ProtectedRoute }

cl {
    # Main App with Router
    def:pub app() -> any {
        return <Router>
            <Routes>
                <Route path="/" element={<HomePage />} />
                <Route path="/login" element={<LoginPage />} />
                <Route path="/register" element={<RegisterPage />} />
                <Route
                    path="/app"
                    element={
                        <ProtectedRoute>
                            <MainApp />
                        </ProtectedRoute>
                    }
                />
            </Routes>
        </Router>;
    }
}