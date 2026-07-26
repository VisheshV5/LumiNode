"""LumiNode - Dashboard route shell ("/dashboard").

Owns every reactive field the dashboard needs. Redirects to /start if this
browser has no credit profile yet. Sections below are stateless and receive
props + callbacks.
"""

import from "@jac/runtime" { Navigate, __jacSleep }

sv import from .graph { get_dashboard_data, rerun_simulation }
sv import from .chat { send_chat_message }
sv import from .model {
    CreditProfile, CreditCard, Loan, Action,
    SimulationResult, ChatMessage, FactorAssessment
}

import from .TopBar { TopBar }
import from .FactorsPanel { FactorsPanel }
import from .GraphView { GraphView }
import from .ActionPath { ActionPath }
import from .ChatPanel { ChatPanel }

def:pub DashboardShell() -> JsxElement {
    has loading: bool = True,
        submitting: bool = False,
        profile: CreditProfile | None = None,
        cards: list[CreditCard] = [],
        loans: list[Loan] = [],
        actions: list[Action] = [],
        factorAssessments: list[FactorAssessment] = [],
        latestResult: SimulationResult | None = None,
        chatMessages: list[ChatMessage] = [],
        chatOpen: bool = False,
        chatSending: bool = False,
        hoveredNodeId: str = "",
        selectedNodeId: str = "";

    can with entry {
        loadDashboard();
    }

    async def loadDashboard() -> None;
    async def sendChat(message: str) -> None;
    async def runAnotherSimulation() -> None;
    def toggleChat(e: MouseEvent) -> None;
    def hoverNode(nodeId: str) -> None;
    def selectNode(nodeId: str) -> None;

    if loading {
        return <div className="lumi-boot">
            <div className="lumi-boot-glow"/>
            <p className="lumi-boot-word">LumiNode</p>
            <p className="lumi-boot-text">Loading your graph…</p>
        </div>;
    }

    if profile is None {
        return <Navigate to="/start" replace={True} />;
    }

    return <div className="lumi-dashboard">
        <TopBar profile={profile} onToggleChat={toggleChat} chatOpen={chatOpen}/>
        <ActionPath result={latestResult} onRerun={runAnotherSimulation} submitting={submitting}/>
        <div className="lumi-main-grid">
            <FactorsPanel
                profile={profile}
                cards={cards}
                loans={loans}
                actions={actions}
                factorAssessments={factorAssessments}
            />
            <GraphView
                profile={profile}
                cards={cards}
                loans={loans}
                factorAssessments={factorAssessments}
                hoveredNodeId={hoveredNodeId}
                selectedNodeId={selectedNodeId}
                onHoverNode={hoverNode}
                onSelectNode={selectNode}
            />
        </div>
        {if chatOpen {
            <ChatPanel messages={chatMessages} sending={chatSending} onSend={sendChat} onClose={toggleChat}/>
        }}
    </div>;
}
