"""LumiNode - TopBar handlers."""

impl TopBar.submitPhone() -> None {
    connecting = True;
    connectStatus = "";

    ok: bool = False;
    try {
        ok = await connect_phone(phoneInput.strip());  # jac:ignore[E1053]
    } except Exception {
        ok = False;
    }

    connecting = False;
    if ok {
        phonePanelOpen = False;
        phoneInput = "";
        consentChecked = False;
    } else {
        connectStatus = "Couldn't send that text - check the number and try again.";
    }
}
