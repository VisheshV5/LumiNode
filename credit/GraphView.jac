"""LumiNode - Force-directed, drillable credit graph.

Three tiers, physics-placed instead of a fixed ring: center (the score) ->
the 5 real FICO factor nodes (sized by weight, colored by the factor
agent's actual tone) -> the accounts that feed each one. d3-force spreads
everything to fill whatever space the panel actually has, nodes can be
dragged, and clicking a factor or account opens a detail panel with the
real numbers/explanation behind it - not just a label.
"""

import from react { useEffect }
import from "d3-force" { forceSimulation, forceLink, forceManyBody, forceCollide, forceX, forceY }
import from "./components/magicui/particles" { Particles }
sv import from .model { CreditProfile, CreditCard, Loan, FactorAssessment }

glob SIM_WIDTH: float = 760.0;
glob SIM_HEIGHT: float = 480.0;

glob FACTOR_WEIGHTS: dict[str, int] = {
    "Credit Utilization": 30, "Payment History": 35, "Credit Mix": 10,
    "Credit Age": 15, "New Credit": 10
};
glob FACTOR_ORDER: list[str] = ["Payment History", "Credit Utilization", "Credit Age", "Credit Mix", "New Credit"];

def tone_color(tone: str) -> str {
    if tone == "good" { return "var(--node-green)"; }
    if tone == "bad" { return "var(--node-red)"; }
    return "var(--node-amber)";
}

def util_color(pct: float) -> str {
    if pct < 30.0 { return "var(--node-green)"; }
    if pct < 50.0 { return "var(--node-amber)"; }
    return "var(--node-red)";
}

"""Which factor a card's edge should point to - the single most relevant one,
so every account gets exactly one clean connection instead of a cluttered
fan-out to every factor it technically touches."""
def card_primary_factor(c: CreditCard) -> str {
    return "Payment History" if c.has_late_payment else "Credit Utilization";
}

"""The factor agent's actual factor_name strings vary (e.g. "Length of Credit
History (15%)", "New Credit/Inquiries (10%)") rather than matching our short
canonical labels exactly - match by keyword instead of exact equality."""
def matches_factor(raw_name: str, canonical: str) -> bool {
    r = raw_name.lower();
    if canonical == "Credit Utilization" { return "utilization" in r; }
    if canonical == "Payment History" { return "payment history" in r; }
    if canonical == "Credit Mix" { return "credit mix" in r; }
    if canonical == "Credit Age" { return "credit age" in r or "length of credit" in r or "credit history" in r; }
    if canonical == "New Credit" { return "new credit" in r or "inquir" in r; }
    return False;
}

def find_assessment(factorAssessments: list[FactorAssessment], canonical: str) -> FactorAssessment | None {
    for a in factorAssessments {
        if matches_factor(a.factor_name, canonical) { return a; }
    }
    return None;
}

"""Builds the plain-object node/link data d3-force operates on. Pure/
deterministic given the same profile data - re-run whenever the account or
factor set actually changes."""
def build_sim_data(cards: list[CreditCard], loans: list[Loan], factorAssessments: list[FactorAssessment]) -> dict {
    nodes: list[dict] = [];
    links: list[dict] = [];

    nodes.append({
        "id": "center", "kind": "center", "label": "Score",
        "r": 46.0, "color": "var(--lumi-glow)",
        "x": SIM_WIDTH / 2.0, "y": SIM_HEIGHT / 2.0,
        "fx": SIM_WIDTH / 2.0, "fy": SIM_HEIGHT / 2.0
    });

    for name in FACTOR_ORDER {
        weight: int = FACTOR_WEIGHTS.get(name, 10);
        a = find_assessment(factorAssessments, name);
        tone = a.tone if a else "warn";
        headline = a.headline if a else "";
        explanation = a.explanation if a else "No assessment yet - run a simulation.";
        nodes.append({
            "id": "factor:" + name, "kind": "factor", "label": name,
            "r": 20.0 + (weight * 0.55), "color": tone_color(tone),
            "weight": weight, "tone": tone, "headline": headline, "explanation": explanation
        });
        links.append({"source": "center", "target": "factor:" + name, "color": tone_color(tone), "tier": 1});
    }

    for c in cards {
        factor = card_primary_factor(c);
        node_id = "account:" + jid(c);
        nodes.append({
            "id": node_id, "kind": "card", "label": c.card_name,
            "r": 16.0 + min(20.0, c.credit_limit / 180.0), "color": util_color(c.utilization_pct),
            "balance": c.current_balance, "limit": c.credit_limit, "utilization": c.utilization_pct,
            "apr": c.apr, "isAu": c.is_authorized_user, "hasLate": c.has_late_payment
        });
        links.append({"source": "factor:" + factor, "target": node_id, "color": util_color(c.utilization_pct), "tier": 2});
    }

    for l in loans {
        node_id = "account:" + jid(l);
        nodes.append({
            "id": node_id, "kind": "loan", "label": l.loan_type + " loan",
            "r": 20.0, "color": "var(--node-blue)",
            "balance": l.current_balance, "payment": l.monthly_payment, "apr": l.apr
        });
        links.append({"source": "factor:Credit Mix", "target": node_id, "color": "var(--node-blue)", "tier": 2});
    }

    return {"nodes": nodes, "links": links};
}

def:pub GraphView(
    profile: CreditProfile,
    cards: list[CreditCard],
    loans: list[Loan],
    factorAssessments: list[FactorAssessment],
    hoveredNodeId: str,
    selectedNodeId: str,
    onHoverNode: Callable[[str], None],
    onSelectNode: Callable[[str], None]
) -> JsxElement {
    has svgRef: Ref[any] = Ref();
    has containerRef: Ref[any] = Ref();
    has simRef: Ref[any] = Ref(None);
    has dragIdRef: Ref[str] = Ref("");
    has downPosRef: Ref[any] = Ref(None);
    has renderNodes: list[dict] = [];
    has renderLinks: list[dict] = [];

    """The SVG uses preserveAspectRatio="meet", so it letterboxes whenever the
    container's aspect ratio doesn't match SIM_WIDTH/SIM_HEIGHT - simple
    percentage math drifts from where nodes actually render. This computes
    the real scale + letterbox offset so screen<->sim conversions line up."""
    def getSvgTransform() -> any {
        if not svgRef.current { return {"ready": False}; }
        rect = svgRef.current.getBoundingClientRect();  # jac:ignore[E1099]
        rect_w: float = rect.width;  # jac:ignore[E1099]
        rect_h: float = rect.height;  # jac:ignore[E1099]
        rect_l: float = rect.left;  # jac:ignore[E1099]
        rect_t: float = rect.top;  # jac:ignore[E1099]
        scale = min(rect_w / SIM_WIDTH, rect_h / SIM_HEIGHT);
        offsetX = (rect_w - (SIM_WIDTH * scale)) / 2.0;
        offsetY = (rect_h - (SIM_HEIGHT * scale)) / 2.0;
        return {
            "ready": True, "scale": scale, "offsetX": offsetX, "offsetY": offsetY,
            "left": rect_l, "top": rect_t, "width": rect_w, "height": rect_h
        };
    }

    def toSimCoords(clientX: float, clientY: float) -> any {
        t = getSvgTransform();
        if not (t["ready"] as bool) { return {"x": 0.0, "y": 0.0}; }
        scale = t["scale"] as float;
        simX = ((clientX - (t["left"] as float)) - (t["offsetX"] as float)) / scale;
        simY = ((clientY - (t["top"] as float)) - (t["offsetY"] as float)) / scale;
        return {"x": simX, "y": simY};
    }

    """Popup position, in real pixels: measures the actual rendered node
    position (accounting for letterboxing) and clamps to stay fully inside
    the container. Visibility comes first here - it does NOT try to dodge
    other nodes, just prefers below-the-node and flips above only if that
    would push it off the bottom edge."""
    def popup_style(n: dict) -> dict {
        t = getSvgTransform();
        if not (t["ready"] as bool) { return {"display": "none"}; }
        scale = t["scale"] as float;

        container_left: float = t["left"] as float;
        container_top: float = t["top"] as float;
        container_w: float = t["width"] as float;
        container_h: float = t["height"] as float;
        if containerRef.current {
            crect = containerRef.current.getBoundingClientRect();  # jac:ignore[E1099]
            container_left = crect.left;  # jac:ignore[E1099]
            container_top = crect.top;  # jac:ignore[E1099]
            container_w = crect.width;  # jac:ignore[E1099]
            container_h = crect.height;  # jac:ignore[E1099]
        }
        base_left = ((t["left"] as float) - container_left) + (t["offsetX"] as float);
        base_top = ((t["top"] as float) - container_top) + (t["offsetY"] as float);

        px_x = base_left + (n["x"] as float) * scale;
        px_y = base_top + (n["y"] as float) * scale;
        node_r_px = (n["r"] as float) * scale;

        popup_w = 260.0;
        popup_h = 200.0;
        margin = 12.0;

        left = px_x - (popup_w / 2.0);
        if left < margin { left = margin; }
        if left + popup_w > container_w - margin { left = container_w - margin - popup_w; }
        if left < margin { left = margin; }

        top = px_y + node_r_px + 16.0;
        if top + popup_h > container_h - margin {
            flipped = px_y - node_r_px - 16.0 - popup_h;
            top = flipped if flipped > margin else margin;
        }

        return {"left": f"{left}px", "top": f"{top}px"};
    }

    """Ticks the live simulation and syncs render state. Called from our own
    setInterval loop below rather than relying on d3-force's built-in
    RAF-driven auto-tick, which doesn't reliably fire in every host
    environment (background/inactive tabs throttle requestAnimationFrame) -
    a plain interval is a small, guaranteed-to-run alternative."""
    def onTick() {
        sim = simRef.current;
        if not sim { return; }
        sim.tick();  # jac:ignore[E1099]
        renderNodes = [n for n in sim.nodes()];  # jac:ignore[E1099]
    }

    can with (len(cards), len(loans), len(factorAssessments)) entry {
        data = build_sim_data(cards, loans, factorAssessments);
        simNodes = data["nodes"];
        simLinks = data["links"];

        sim = forceSimulation(simNodes)
            .force("link", forceLink(simLinks).id(lambda (d: dict) -> str { return d["id"] as str; }).distance(
                lambda (d: dict) -> float { return 165.0 if (d["tier"] as int) == 1 else 105.0; }
            ).strength(0.9))
            .force("charge", forceManyBody().strength(-340.0))
            .force("collide", forceCollide().radius(lambda (d: dict) -> float { return (d["r"] as float) + 30.0; }).strength(0.9))
            .force("x", forceX(SIM_WIDTH / 2.0).strength(0.04))
            .force("y", forceY(SIM_HEIGHT / 2.0).strength(0.04))
            .stop();

        simRef.current = sim;
        renderLinks = simLinks;
        renderNodes = [n for n in sim.nodes()];
    }

    useEffect(lambda {
        interval = setInterval(lambda { onTick(); }, 16);
        return lambda { clearInterval(interval); };
    }, []);

    def endDrag() {
        sim = simRef.current;
        node_id = dragIdRef.current;
        if sim and node_id {
            for n in sim.nodes() {
                if (n["id"] as str) == node_id {
                    n["fx"] = None;
                    n["fy"] = None;
                }
            }
            sim.alphaTarget(0.0);
        }
        dragIdRef.current = "";
        window.removeEventListener("mousemove", handleWindowMouseMove);
        window.removeEventListener("mouseup", handleWindowMouseUp);
    }

    def handleWindowMouseMove(e: any) {
        node_id = dragIdRef.current;
        if not node_id { return; }
        pos = toSimCoords(e.clientX, e.clientY);
        sim = simRef.current;
        if sim {
            for n in sim.nodes() {
                if (n["id"] as str) == node_id {
                    n["fx"] = pos["x"];
                    n["fy"] = pos["y"];
                }
            }
        }
    }

    def handleWindowMouseUp(e: any) {
        downPos = downPosRef.current;
        node_id = dragIdRef.current;
        if downPos and node_id {
            dx = e.clientX - (downPos["clientX"] as float);
            dy = e.clientY - (downPos["clientY"] as float);
            moved = ((dx * dx) + (dy * dy)) ** 0.5;
            if moved < 5.0 {
                onSelectNode(node_id);
            }
        }
        endDrag();
    }

    def startDrag(nodeId: str, e: MouseEvent) {
        downPosRef.current = {"clientX": e.clientX, "clientY": e.clientY};
        dragIdRef.current = nodeId;
        sim = simRef.current;
        if sim { sim.alphaTarget(0.3).alpha(0.5); }
        window.addEventListener("mousemove", handleWindowMouseMove);
        window.addEventListener("mouseup", handleWindowMouseUp);
    }

    active_id = selectedNodeId if selectedNodeId else hoveredNodeId;
    selected_node: dict | None = None;
    for n in renderNodes {
        if (n["id"] as str) == selectedNodeId { selected_node = n; }
    }

    connected_accounts: list[dict] = [];
    if selected_node and (selected_node["kind"] as str) == "factor" {
        factor_id = selected_node["id"] as str;
        for lnk in renderLinks {
            src_id = lnk["source"]["id"] as str;
            tgt_id = lnk["target"]["id"] as str;
            if src_id == factor_id {
                for n in renderNodes {
                    if (n["id"] as str) == tgt_id { connected_accounts.append(n); }
                }
            }
        }
    }

    return <div className="lumi-graph-view" ref={containerRef}>
        <Particles className="lumi-graph-particles" quantity={26} color="#F0C850" staticity={55} size={0.5} ease={45}/>
        <svg ref={svgRef} viewBox={"0 0 " + str(SIM_WIDTH) + " " + str(SIM_HEIGHT)} className="lumi-graph-svg" preserveAspectRatio="xMidYMid meet">
            {for lnk in renderLinks {
                <line
                    key={"lnk-" + (lnk["source"]["id"] as str) + "-" + (lnk["target"]["id"] as str)}
                    x1={lnk["source"]["x"] as float}
                    y1={lnk["source"]["y"] as float}
                    x2={lnk["target"]["x"] as float}
                    y2={lnk["target"]["y"] as float}
                    stroke={lnk["color"] as str}
                    strokeWidth={2.4 if (lnk["tier"] as int) == 1 else 1.8}
                    className="lumi-graph-edge"
                />
            }}
            {for n in renderNodes {
                <g
                    key={n["id"] as str}
                    className={"lumi-graph-node lumi-graph-node-" + (n["kind"] as str) + ("" if (not active_id or active_id == "center" or active_id == (n["id"] as str) or (n["id"] as str) == "center") else " lumi-graph-node-dim")}
                    onMouseEnter={lambda (_: MouseEvent) { onHoverNode(n["id"] as str); }}
                    onMouseLeave={lambda (_: MouseEvent) { onHoverNode(""); }}
                    onMouseDown={lambda (e: MouseEvent) { startDrag(n["id"] as str, e); }}
                >
                    <circle
                        cx={n["x"] as float} cy={n["y"] as float} r={n["r"] as float}
                        fill={n["color"] as str} className="lumi-graph-node-circle"
                    />
                    {if (n["id"] as str) == "center" {
                        <text key={"score-" + (n["id"] as str)} x={n["x"] as float} y={(n["y"] as float) + 8.0} textAnchor="middle" className="lumi-graph-center-label">
                            {profile.current_score}
                        </text>
                    }}
                    <text key={"label-" + (n["id"] as str)} x={n["x"] as float} y={(n["y"] as float) + (n["r"] as float) + 15.0} textAnchor="middle" className="lumi-graph-node-label">
                        {n["label"] as str}
                    </text>
                </g>
            }}
        </svg>

        <div className="lumi-graph-legend">
            <span className="lumi-legend-item"><i className="lumi-legend-dot lumi-legend-good"/>Healthy</span>
            <span className="lumi-legend-item"><i className="lumi-legend-dot lumi-legend-warn"/>Needs attention</span>
            <span className="lumi-legend-item"><i className="lumi-legend-dot lumi-legend-bad"/>Hurting your score</span>
        </div>

        {if selected_node and (selected_node["kind"] as str) == "factor" {
            <div className="lumi-graph-detail lumi-fade-in" style={popup_style(selected_node)}>
                <div className="lumi-graph-detail-head">
                    <span className={"lumi-graph-detail-badge lumi-graph-detail-badge-" + (selected_node["tone"] as str)}>
                        {selected_node["headline"] as str}
                    </span>
                    <h3>{selected_node["label"] as str}</h3>
                    <span className="lumi-graph-detail-weight">{str(selected_node["weight"] as int) + "% of your score"}</span>
                </div>
                <p className="lumi-graph-detail-explanation">{selected_node["explanation"] as str}</p>
                {if len(connected_accounts) > 0 {
                    <div className="lumi-graph-detail-accounts">
                        {for acc in connected_accounts {
                            <div key={acc["id"] as str} className="lumi-graph-detail-account">
                                <span className="lumi-graph-detail-account-dot" style={{"background": acc["color"] as str}}/>
                                {acc["label"] as str}
                                {(" — " + f"{(acc['utilization'] as float):.0f}% utilization") if (acc["kind"] as str) == "card" else ""}
                                {" — late payment on file" if ((acc["kind"] as str) == "card" and (acc["hasLate"] as bool)) else ""}
                            </div>
                        }}
                    </div>
                }}
            </div>
        }}

        {if selected_node and (selected_node["kind"] as str) != "factor" and (selected_node["kind"] as str) != "center" {
            <div className="lumi-graph-detail lumi-fade-in" style={popup_style(selected_node)}>
                <div className="lumi-graph-detail-head">
                    <h3>{selected_node["label"] as str}</h3>
                </div>
                {if (selected_node["kind"] as str) == "card" {
                    <div className="lumi-graph-detail-stats">
                        <div><span>Balance</span><b>{f"${(selected_node['balance'] as float):.0f}"}</b></div>
                        <div><span>Limit</span><b>{f"${(selected_node['limit'] as float):.0f}"}</b></div>
                        <div><span>Utilization</span><b>{f"{(selected_node['utilization'] as float):.0f}%"}</b></div>
                        <div><span>APR</span><b>{f"{(selected_node['apr'] as float):.1f}%"}</b></div>
                    </div>
                }}
                {if (selected_node["kind"] as str) == "loan" {
                    <div className="lumi-graph-detail-stats">
                        <div><span>Balance</span><b>{f"${(selected_node['balance'] as float):.0f}"}</b></div>
                        <div><span>Monthly payment</span><b>{f"${(selected_node['payment'] as float):.0f}"}</b></div>
                        <div><span>APR</span><b>{f"{(selected_node['apr'] as float):.1f}%"}</b></div>
                    </div>
                }}
            </div>
        }}
    </div>;
}
