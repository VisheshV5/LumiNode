"""LumiNode - Dashboard shell handlers."""

impl DashboardShell.loadDashboard() -> None {
    bundle = await get_dashboard_data();
    attempt = 0;
    # A profile submitted moments ago (e.g. right after onboarding) can be
    # momentarily invisible to this fresh request while the backend's agent
    # pipeline is still settling - retry briefly before concluding there
    # really is no profile and bouncing the user back to /start.
    while not bundle.has_profile and attempt < 3 {
        await __jacSleep(600 * (attempt + 1));  # jac:ignore[E1053]
        bundle = await get_dashboard_data();
        attempt = attempt + 1;
    }

    if bundle.has_profile {
        profile = bundle.profile;
        cards = bundle.cards;
        loans = bundle.loans;
        actions = bundle.actions;
        factorAssessments = bundle.factor_assessments;
        latestResult = bundle.latest_result;
        chatMessages = bundle.chat_messages;
    } else {
        profile = None;
    }
    loading = False;
}

impl DashboardShell.runAnotherSimulation() -> None {
    submitting = True;
    bundle = await rerun_simulation();
    actions = bundle.actions;
    latestResult = bundle.latest_result;
    submitting = False;
}

impl DashboardShell.sendChat(message: str) -> None {
    if not message.strip() { return; }
    chatSending = True;
    msgs = await send_chat_message(message);
    chatMessages = msgs;
    chatSending = False;
}

impl DashboardShell.toggleChat(e: MouseEvent) -> None {
    chatOpen = not chatOpen;
}

impl DashboardShell.hoverNode(nodeId: str) -> None {
    hoveredNodeId = nodeId;
}

impl DashboardShell.selectNode(nodeId: str) -> None {
    selectedNodeId = "" if selectedNodeId == nodeId else nodeId;
}
