# ConnectButton Component
# Atomic connection toggle button (Connect/Connecting/Disconnect)

import from ...utils.mergeCls { cn }

def:pub ConnectButton(
    sessionStatus: str,
    onToggleConnection: any
) -> any {
    # Compute connection states
    isConnected = sessionStatus == "CONNECTED";
    isConnecting = sessionStatus == "CONNECTING";

    # Button text based on state
    btnText = "Disconnect" if isConnected else ("Connecting..." if isConnecting else "Connect");

    # Button classes with conditional styling
    btnClass = cn(
        "text-white text-base py-2 w-36 rounded-md border-none transition-all",
        (
            "bg-error cursor-pointer hover:opacity-90" if isConnected else (
                "bg-secondary cursor-not-allowed opacity-70" if isConnecting else
                "bg-black cursor-pointer hover:opacity-90"
            )
        )
    );

    return <button
        onClick={onToggleConnection}
        disabled={isConnecting}
        className={btnClass}
    >
        {btnText}
    </button>;
}
