import from react { useState }
import from "@jac-client/utils" { jacLogin, jacSignup, useNavigate }

def:pub useAuth() -> any {
    navigate = useNavigate();
    
    # Shared State 
    [username, setUsername] = useState("");
    [password, setPassword] = useState("");
    [error, setError] = useState("");
    [loading, setLoading] = useState(False);
    
    # Register-Specific State
    [confirmPassword, setConfirmPassword] = useState("");
    
    # Shared Input Handlers 
    
    def handleUsernameChange(e: any) -> None {
        setUsername(e.target.value);
    }

    def handlePasswordChange(e: any) -> None {
        setPassword(e.target.value);
    }

    def handleConfirmPasswordChange(e: any) -> None {
        setConfirmPassword(e.target.value);
    }
    
    # Login Handler
    async def handleLogin(e: any) -> None {
        e.preventDefault();
        setError("");
        
        # Validation
        if not username or not password {
            setError("Please fill in all fields");
            return;
        }
        
        setLoading(True);
        
        try {
            success = await jacLogin(username, password);
            if success {
                navigate("/");
            } else {
                setError("Invalid username or password");
            }
        } except Exception as ex {
            console.error("Login error:", ex);
            setError("An error occurred during login");
        } finally {
            setLoading(False);
        }
    }
    
    # Register Handler
    async def handleRegister(e: any) -> None {
        e.preventDefault();
        setError("");
        
        # Validation
        if not username or not password or not confirmPassword {
            setError("Please fill in all fields");
            return;
        }
        
        if password != confirmPassword {
            setError("Passwords do not match");
            return;
        }
        
        if password.length < 6 {
            setError("Password must be at least 6 characters");
            return;
        }
        
        setLoading(True);
        
        try {
            result = await jacSignup(username, password);
            if result["success"] {
                # Auto-login after successful registration
                navigate("/");
            } else {
                errorMsg = result["error"] if result["error"] else "Registration failed";
                setError(errorMsg);
            }
        } except Exception as ex {
            console.error("Registration error:", ex);
            setError("An error occurred during registration");
        } finally {
            setLoading(False);
        }
    }
    
    # Return Hook Interface 
    return {
        "username": username,
        "setUsername": setUsername,
        "password": password,
        "setPassword": setPassword,
        "error": error,
        "setError": setError,
        "loading": loading,
        "setLoading": setLoading,
        
        "confirmPassword": confirmPassword,
        "setConfirmPassword": setConfirmPassword,
        
        "handleUsernameChange": handleUsernameChange,
        "handlePasswordChange": handlePasswordChange,
        "handleConfirmPasswordChange": handleConfirmPasswordChange,
        
        "handleLogin": handleLogin,
        "handleRegister": handleRegister
    };
}