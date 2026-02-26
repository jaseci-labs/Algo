# RegisterPage Component
# Registration form with username, password, and confirm password

import from "@jac/runtime" { Link }
import from ..hooks.useAuth { useAuth }
import from ..utils.mergeCls { cn }
import from ..components.Layout { Layout }

def:pub RegisterPage() -> any {
    # Call Hook (Get All Logic)
    hook = useAuth();

    # Destructure for easier access
    username = hook.username;
    password = hook.password;
    confirmPassword = hook.confirmPassword;
    error = hook.error;
    loading = hook.loading;
    handleRegister = hook.handleRegister;
    handleUsernameChange = hook.handleUsernameChange;
    handlePasswordChange = hook.handlePasswordChange;
    handleConfirmPasswordChange = hook.handleConfirmPasswordChange;

    # Error display element
    errorDisplay = None;
    if error {
        errorDisplay = <div className="error-display p-3 mb-4 bg-error/10 border border-error/30 rounded-lg text-error text-sm">
            {error}
        </div>;
    }

    # Input classes with conditional styling
    inputClass = cn(
        "w-full px-4 py-3.5 border-2 rounded-xl text-base transition-all box-border outline-none font-sans",
        ("bg-background-hover border-border/80" if loading else "bg-background border-border"),
        "text-text-primary placeholder:text-text-secondary",
        "focus:border-primary focus:ring-2 focus:ring-primary/20"
    );

    # Button classes with conditional styling
    buttonClass = cn(
        "auth-button w-full py-4  border-none rounded-xl text-base font-semibold transition-all flex items-center justify-center gap-2 tracking-wide",
        (" opacity-70 cursor-not-allowed" if loading else "cursor-pointer hover:opacity-90")
    );
    buttonText = "Creating account..." if loading else "Sign up";

    # Render (UI Only)
    return <Layout meta={{"title": "Register | Algo", "description": "Create your Algo AI assistant account"}}>
        <div className="flex items-center justify-center min-h-screen p-5  overflow-hidden">

            <div className="glass-panel p-12 rounded-3xl w-full max-w-md shadow-2 ">
                <div className="text-center mb-10">
                    <h1 className="text-4xl font-bold text-text-primary mb-2 tracking-tight">
                        {"Algo"}
                    </h1>
                    <p className="text-text-secondary text-base font-normal">
                        {"Create your account"}
                    </p>
                </div>

                <form onSubmit={handleRegister}>
                    <div className="mb-5">
                        <label className="block mb-2.5 text-sm font-semibold text-text-primary tracking-wide">
                            {"Username"}
                        </label>
                        <input
                            type="text"
                            value={username}
                            onChange={handleUsernameChange}
                            placeholder="Choose a username"
                            disabled={loading}
                            className={inputClass}
                        />
                    </div>

                    <div className="mb-5">
                        <label className="block mb-2.5 text-sm font-semibold text-text-primary tracking-wide">
                            {"Password"}
                        </label>
                        <input
                            type="password"
                            value={password}
                            onChange={handlePasswordChange}
                            placeholder="Choose a password (min 6 characters)"
                            disabled={loading}
                            className={inputClass}
                        />
                    </div>

                    <div className="mb-8">
                        <label className="block mb-2.5 text-sm font-semibold text-text-primary tracking-wide">
                            {"Confirm Password"}
                        </label>
                        <input
                            type="password"
                            value={confirmPassword}
                            onChange={handleConfirmPasswordChange}
                            placeholder="Re-enter your password"
                            disabled={loading}
                            className={inputClass}
                        />
                    </div>

                    {errorDisplay}

                    <button
                        type="submit"
                        disabled={loading}
                        className={buttonClass}
                    >
                        {buttonText}
                    </button>
                </form>

                <div className="mt-8 text-center text-sm text-text-secondary">
                    {"Already have an account?"}
                    <Link
                        to="/login"
                        className="ml-1.5 text-primary font-semibold no-underline transition-opacity hover:opacity-80"
                    >
                        {"Login"}
                    </Link>
                </div>
            </div>
        </div>
    </Layout>;
}
