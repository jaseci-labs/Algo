import from react { useState, useEffect, useRef }
import from "@jac-client/utils" { Router, Routes, Route }

import from .pages.MainApp { MainApp }
import from .pages.HomePage { HomePage }
import from .pages.LoginPage { LoginPage }
import from .pages.RegisterPage { RegisterPage }

import from .utils.ProtectedRoute { ProtectedRoute }

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
