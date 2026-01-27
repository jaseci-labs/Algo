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
        errorDisplay = <div className="p-3 mb-4 bg-error/10 border border-error/30 rounded-lg text-error text-sm">
            {error}
        </div>;
    }

    # Input classes with conditional styling
    inputClass = cn(
        "w-full px-4 py-3.5 border-2 rounded-xl text-base transition-all box-border outline-none font-sans",
        ("bg-surface-hover border-border/80" if loading else "bg-surface border-border"),
        "text-text-primary placeholder:text-text-secondary",
        "focus:border-primary focus:ring-2 focus:ring-primary/20"
    );
    
    # Button classes with conditional styling
    buttonClass = cn(
        "w-full py-4 text-primary-foreground border-none rounded-xl text-base font-semibold transition-all flex items-center justify-center gap-2 tracking-wide",
        ("bg-secondary/70 opacity-70 cursor-not-allowed" if loading else "bg-secondary cursor-pointer hover:opacity-90")
    );

    buttonText = "Creating account..." if loading else "Sign up";

    # Render (UI Only) 
    return <Layout meta={{"title": "Register | Algo", "description": "Create your Algo AI assistant account"}}>
        <div className="flex items-center justify-center min-h-screen p-5 relative overflow-hidden">
            <div className="absolute inset-0 bg-[radial-gradient(circle_at_20%_50%,rgba(0,0,0,0.03)_0%,transparent_50%),radial-gradient(circle_at_80%_80%,rgba(0,0,0,0.03)_0%,transparent_50%)] pointer-events-none" />

            <div className="bg-surface p-12 rounded-3xl w-full max-w-md shadow-[0_0_0_1px_rgba(0,0,0,0.05),0_20px_60px_rgba(0,0,0,0.08)] relative z-10">
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