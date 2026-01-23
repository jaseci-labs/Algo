import from "@jac-client/utils" { jacLogin, jacSignup, useNavigate }

def:pub useAuth() -> any {
    navigate = useNavigate();

    # Reactive state using has variables
    # Shared State
    has username: str = "";
    has password: str = "";
    has error: str = "";
    has loading: bool = False;

    # Register-Specific State
    has confirmPassword: str = "";

    # Shared Input Handlers

    def handleUsernameChange(e: any) -> None {
        username = e.target.value;
    }

    def handlePasswordChange(e: any) -> None {
        password = e.target.value;
    }

    def handleConfirmPasswordChange(e: any) -> None {
        confirmPassword = e.target.value;
    }

    # Login Handler
    async def handleLogin(e: any) -> None {
        e.preventDefault();
        error = "";

        # Validation
        if not username or not password {
            error = "Please fill in all fields";
            return;
        }

        loading = True;

        try {
            success = await jacLogin(username, password);
            if success {
                navigate("/");
            } else {
                error = "Invalid username or password";
            }
        } except Exception as ex {
            console.error("Login error:", ex);
            if ex.message {
                error = ex.message;
            } else {
                error = "An error occurred during login";
            }
        } finally {
            loading = False;
        }
    }

    # Register Handler
    async def handleRegister(e: any) -> None {
        e.preventDefault();
        error = "";

        # Validation
        if not username or not password or not confirmPassword {
            error = "Please fill in all fields";
            return;
        }

        if password != confirmPassword {
            error = "Passwords do not match";
            return;
        }

        if password.length < 6 {
            error = "Password must be at least 6 characters";
            return;
        }

        loading = True;

        try {
            result = await jacSignup(username, password);
            if result["success"] {
                # Auto-login after successful registration
                navigate("/");
            } else {
                # Extract message from error object
                errorData = result["error"];
                if errorData and errorData.message {
                    error = errorData.message;
                } else {
                    error = "Registration failed";
                }
            }
        } except Exception as ex {
            console.error("Registration error:", ex);
            if ex.message {
                error = ex.message;
            } else {
                error = "An error occurred during registration";
            }
        } finally {
            loading = False;
        }
    }

    # Return Hook Interface
    return {
        "username": username,
        "password": password,
        "error": error,
        "loading": loading,

        "confirmPassword": confirmPassword,

        "handleUsernameChange": handleUsernameChange,
        "handlePasswordChange": handlePasswordChange,
        "handleConfirmPasswordChange": handleConfirmPasswordChange,

        "handleLogin": handleLogin,
        "handleRegister": handleRegister
    };
}