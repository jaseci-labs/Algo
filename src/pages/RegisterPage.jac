cl import from react { useState }
cl import from "@jac-client/utils" { jacSignup, useNavigate, Link }

cl def:pub RegisterPage() -> any {
    [username, setUsername] = useState("");
    [password, setPassword] = useState("");
    [confirmPassword, setConfirmPassword] = useState("");
    [error, setError] = useState("");
    [loading, setLoading] = useState(False);
    navigate = useNavigate();

    async def handleRegister(e: any) -> None {
        e.preventDefault();
        setError("");
        
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

    def handleUsernameChange(e: any) -> None {
        setUsername(e.target.value);
    }

    def handlePasswordChange(e: any) -> None {
        setPassword(e.target.value);
    }

    def handleConfirmPasswordChange(e: any) -> None {
        setConfirmPassword(e.target.value);
    }

    errorDisplay = None;
    if error {
        errorDisplay = <div style={{
            "padding": "12px",
            "marginBottom": "16px",
            "backgroundColor": "#fee2e2",
            "border": "1px solid #fca5a5",
            "borderRadius": "8px",
            "color": "#991b1b",
            "fontSize": "14px"
        }}>
            {error}
        </div>;
    }

    # Compute conditional values outside JSX
    inputBgColor = "#ffffff";
    inputBorderColor = "#e5e7eb";
    if loading {
        inputBgColor = "#f9fafb";
        inputBorderColor = "#d1d5db";
    }

    buttonBg = "#000000";
    buttonOpacity = "1";
    if loading {
        buttonBg = "#404040";
        buttonOpacity = "0.7";
    }

    buttonCursor = "pointer";
    if loading {
        buttonCursor = "not-allowed";
    }

    buttonText = "Sign up";
    if loading {
        buttonText = "Creating account...";
    }

    return <div style={{
        "minHeight": "100vh",
        "display": "flex",
        "alignItems": "center",
        "justifyContent": "center",
        "background": "#ffffff",
        "padding": "20px",
        "position": "relative",
        "overflow": "hidden"
    }}>
        <div style={{
            "position": "absolute",
            "top": "0",
            "left": "0",
            "right": "0",
            "bottom": "0",
            "background": "radial-gradient(circle at 20% 50%, rgba(0, 0, 0, 0.05) 0%, transparent 50%), radial-gradient(circle at 80% 80%, rgba(0, 0, 0, 0.05) 0%, transparent 50%)",
            "pointerEvents": "none"
        }} />

        <div style={{
            "background": "#ffffff",
            "padding": "48px",
            "borderRadius": "24px",
            "width": "100%",
            "maxWidth": "440px",
            "boxShadow": "0 0 0 1px rgba(0, 0, 0, 0.05), 0 20px 60px rgba(0, 0, 0, 0.08)",
            "position": "relative",
            "zIndex": "1"
        }}>
            <div style={{
                "textAlign": "center",
                "marginBottom": "40px"
            }}>
                <h1 style={{
                    "fontSize": "36px",
                    "fontWeight": "700",
                    "color": "#000000",
                    "marginBottom": "8px",
                    "letterSpacing": "-0.02em"
                }}>
                    Algo
                </h1>
                <p style={{
                    "color": "#737373",
                    "fontSize": "15px",
                    "fontWeight": "400"
                }}>
                    Create your account
                </p>
            </div>

            <form onSubmit={handleRegister}>
                <div style={{"marginBottom": "20px"}}>
                    <label style={{
                        "display": "block",
                        "marginBottom": "10px",
                        "fontSize": "13px",
                        "fontWeight": "600",
                        "color": "#000000",
                        "letterSpacing": "0.01em"
                    }}>
                        Username
                    </label>
                    <input
                        type="text"
                        value={username}
                        onChange={handleUsernameChange}
                        placeholder="Choose a username"
                        disabled={loading}
                        style={{
                            "width": "100%",
                            "padding": "14px 16px",
                            "border": "1.5px solid " + inputBorderColor,
                            "borderRadius": "12px",
                            "fontSize": "15px",
                            "transition": "all 0.2s ease",
                            "boxSizing": "border-box",
                            "backgroundColor": inputBgColor,
                            "color": "#000000",
                            "outline": "none",
                            "fontFamily": "inherit"
                        }}
                    />
                </div>

                <div style={{"marginBottom": "20px"}}>
                    <label style={{
                        "display": "block",
                        "marginBottom": "10px",
                        "fontSize": "13px",
                        "fontWeight": "600",
                        "color": "#000000",
                        "letterSpacing": "0.01em"
                    }}>
                        Password
                    </label>
                    <input
                        type="password"
                        value={password}
                        onChange={handlePasswordChange}
                        placeholder="Choose a password (min 6 characters)"
                        disabled={loading}
                        style={{
                            "width": "100%",
                            "padding": "14px 16px",
                            "border": "1.5px solid " + inputBorderColor,
                            "borderRadius": "12px",
                            "fontSize": "15px",
                            "transition": "all 0.2s ease",
                            "boxSizing": "border-box",
                            "backgroundColor": inputBgColor,
                            "color": "#000000",
                            "outline": "none",
                            "fontFamily": "inherit"
                        }}
                    />
                </div>

                <div style={{"marginBottom": "32px"}}>
                    <label style={{
                        "display": "block",
                        "marginBottom": "10px",
                        "fontSize": "13px",
                        "fontWeight": "600",
                        "color": "#000000",
                        "letterSpacing": "0.01em"
                    }}>
                        Confirm Password
                    </label>
                    <input
                        type="password"
                        value={confirmPassword}
                        onChange={handleConfirmPasswordChange}
                        placeholder="Re-enter your password"
                        disabled={loading}
                        style={{
                            "width": "100%",
                            "padding": "14px 16px",
                            "border": "1.5px solid " + inputBorderColor,
                            "borderRadius": "12px",
                            "fontSize": "15px",
                            "transition": "all 0.2s ease",
                            "boxSizing": "border-box",
                            "backgroundColor": inputBgColor,
                            "color": "#000000",
                            "outline": "none",
                            "fontFamily": "inherit"
                        }}
                    />
                </div>

                {errorDisplay}

                <button
                    type="submit"
                    disabled={loading}
                    style={{
                        "width": "100%",
                        "padding": "16px",
                        "background": buttonBg,
                        "color": "#ffffff",
                        "border": "none",
                        "borderRadius": "12px",
                        "fontSize": "15px",
                        "fontWeight": "600",
                        "cursor": buttonCursor,
                        "transition": "all 0.15s ease",
                        "display": "flex",
                        "alignItems": "center",
                        "justifyContent": "center",
                        "gap": "8px",
                        "opacity": buttonOpacity,
                        "letterSpacing": "0.02em"
                    }}
                >
                    {buttonText}
                </button>
            </form>

            <div style={{
                "marginTop": "32px",
                "textAlign": "center",
                "fontSize": "14px",
                "color": "#737373"
            }}>
                Already have an account?
                <Link
                    to="/login"
                    style={{
                        "marginLeft": "6px",
                        "color": "#000000",
                        "textDecoration": "none",
                        "fontWeight": "600",
                        "transition": "opacity 0.2s ease"
                    }}
                >
                    Login
                </Link>
            </div>
        </div>
    </div>;
}
