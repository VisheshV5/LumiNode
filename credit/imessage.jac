"""LumiNode - iMessage Integration (BlueBubbles).

The iMessage agent is NOT a separate agent - it's the exact same
`_generate_agent_reply` (credit/chat.jac) that powers the website chat panel,
just triggered from a webhook instead of a button click, and keyed by an
iMessage handle (phone number OR Apple ID email - Mac users often have no
phone number on iMessage at all) instead of a login session. `connect_phone`
links a handle to the caller's own profile and fires the opening text;
`imessage_webhook` receives every subsequent inbound text from BlueBubbles,
answers it with the shared agent, applies any credit-score update the agent
detected, and sends the reply back through BlueBubbles.
"""

import os;
import json;
import from uuid { uuid4, UUID }
import from urllib.request { Request, urlopen }
import from urllib.parse { quote }
import from jaclang { JacRuntime as Jac }

import from .model { CreditProfile, HasAccount }

glob _BB_URL: str = os.environ.get("BLUEBUBBLES_URL", "http://localhost:1234");
glob _BB_PASSWORD: str = os.environ.get("BLUEBUBBLES_PASSWORD", "");

# Keyed by normalized iMessage address -> the last text WE sent them. When the
# connected account texts itself (self-testing, or genuinely texting your own
# number/email), BlueBubbles can echo our own outgoing reply back as a fresh
# "received" event - isFromMe is not reliable in that one case, since sending
# and receiving collapse into the same account. Anything that arrives
# byte-identical to what we just sent that address is treated as our own
# echo, not a new user message.
glob _recent_bot_texts: dict[str, str] = {};

# ═══════════════════════════════════════════
# BLUEBUBBLES REST HELPERS
# ═══════════════════════════════════════════

def _bb_post(path: str, body: dict) -> dict {
    url = f"{_BB_URL}{path}?password={quote(_BB_PASSWORD)}";
    data = json.dumps(body).encode("utf-8");
    try {
        req = Request(url, data=data, headers={"Content-Type": "application/json"}, method="POST");
        resp = urlopen(req, timeout=10);
        raw = resp.read();
        resp.close();
        return json.loads(raw.decode("utf-8"));
    } except Exception as e {
        return {"status": 0, "error": str(e)};
    }
}

"""Starts a brand-new iMessage thread with `address` and sends the first text."""
def _send_imessage_new(address: str, text: str) -> bool {
    result = _bb_post("/api/v1/chat/new", {
        "addresses": [address],
        "message": text,
        "method": "apple-script"
    });
    ok = int(result.get("status", 0)) == 200;
    if ok { _recent_bot_texts[address] = text; }
    if not ok { print("BlueBubbles chat/new failed:", result); }
    return ok;
}

"""Sends a reply into an existing iMessage thread by its chat GUID."""
def _send_imessage_reply(chat_guid: str, text: str, address: str = "") -> bool {
    result = _bb_post("/api/v1/message/text", {
        "chatGuid": chat_guid,
        "tempGuid": str(uuid4()),
        "message": text,
        "method": "apple-script"
    });
    ok = int(result.get("status", 0)) == 200;
    if ok and address { _recent_bot_texts[address] = text; }
    if not ok { print("BlueBubbles message/text failed:", result); }
    return ok;
}

"""Digits-only E.164 normalization; assumes US (+1) for bare 10-digit input.
Returns '' for anything that doesn't look like a real phone number."""
def _normalize_phone(raw: str) -> str {
    digits = "";
    for ch in raw {
        if ch.isdigit() { digits = digits + ch; }
    }
    if len(digits) == 10 { return "+1" + digits; }
    if len(digits) == 11 and digits[0] == "1" { return "+" + digits; }
    return "";
}

"""True for a plausible email address - just enough shape-checking to route
between phone and email normalization, not full RFC validation."""
def _looks_like_email(raw: str) -> bool {
    if "@" not in raw { return False; }
    local = raw.split("@")[0];
    domain = raw.split("@")[-1];
    return bool(local.strip()) and "." in domain and len(domain.strip()) > 2;
}

"""Normalizes either a phone number or an Apple ID email into the address
form BlueBubbles/iMessage expects. iMessage identifies people by phone OR
email (Mac users very often use email, since a Mac has no phone number of
its own) - this is the single place that decides which one we're looking at.
Returns '' if it's neither."""
def _normalize_imessage_address(raw: str) -> str {
    trimmed = raw.strip();
    if _looks_like_email(trimmed) { return trimmed.lower(); }
    return _normalize_phone(trimmed);
}

# ═══════════════════════════════════════════
# CLIENT-FACING ENDPOINT - "Connect on my phone"
# ═══════════════════════════════════════════

"""Grants the anonymous iMessage webhook write access to this profile AND
every account node hanging off it (cards, loans). Grants are per-node, not
per-subtree, so each account needs its own grant call - re-running this
after Update Info rebuilds the account list (credit/graph.jac) is what
covers cards/loans added or replaced after the initial connect."""
def grant_imessage_write_access(profile: CreditProfile) -> None {
    if not profile.imessage_handle { return; }
    # BlueBubbles calls the webhook with no login session - it runs as the
    # anonymous guest identity (root.shared), not "a logged-in user", so
    # grant() (which only covers other logged-in users) never applies here.
    # allow_root targets one SPECIFIC root id though, and root.shared has its
    # own stable id like any other root - granting write access to that
    # specific id is what actually lets the anonymous webhook write back to
    # this profile and its accounts (attach chat messages, update the score
    # or a card balance).
    guest_root = UUID(jid(root.shared));
    Jac.allow_root(profile, guest_root, WritePerm);  # jac:ignore[E1053]
    for acct in [profile ->:HasAccount:->] {
        Jac.allow_root(acct, guest_root, WritePerm);  # jac:ignore[E1053]
    }
}

"""Links a phone number OR an Apple ID email to the caller's own profile and
fires the opening text - Mac users commonly have no phone number registered
on iMessage at all, just their email."""
def:protect connect_phone(phone_number: str) -> bool {
    profiles = [root -->][?:CreditProfile];
    if len(profiles) == 0 { return False; }
    profile = profiles[0];

    normalized = _normalize_imessage_address(phone_number);
    if not normalized { return False; }

    profile.imessage_handle = normalized;
    grant_imessage_write_access(profile);
    return _send_imessage_new(
        normalized,
        "Hey! I'm your LumiNode credit agent. Text me anytime - ask me things like "
        + "\"what should I pay first?\" or \"how do I get to my target?\", or just tell me "
        + "when your score changes, like \"my score is 620 now,\" and I'll keep your account in sync."
    );
}

# ═══════════════════════════════════════════
# BLUEBUBBLES WEBHOOK - every inbound text lands here
# ═══════════════════════════════════════════

"""Receives every BlueBubbles webhook event. Only 'new-message' events that
weren't sent by us are processed - everything else is a no-op ack. Writing
to the matched profile - and sending the reply - happens by visiting it
(`accept_imessage_write` on CreditProfile, credit/model.jac) rather than
mutating it directly from here: this walker is anonymous (BlueBubbles has
no login session), and a node's own ability runs in its own permission
context, so this is what lets an anonymous caller write to a profile it
doesn't own. The send itself also happens inside that same node ability,
not back here after the visit - a separate walker-side "on arrival" ability
was tried first but its firing order relative to the node's own ability
isn't guaranteed, and in testing it ran before the reply existed."""
walker:pub imessage_webhook {
    has type: str = "",
        data: dict = {},
        pending_user_text: str = "",
        pending_chat_guid: str = "",
        pending_address: str = "";

    can handle with Root entry {
        if self.type == "new-message" {
            msg = self.data;
            is_from_me = bool(msg.get("isFromMe", False));
            text = str(msg.get("text", "") or "").strip();

            if not is_from_me and text {
                chat_guid = "";
                chats = msg.get("chats", []);
                if len(chats) > 0 { chat_guid = str(chats[0].get("guid", "") or ""); }

                address = "";
                handle = msg.get("handle", {});
                if handle { address = str(handle.get("address", "") or ""); }

                is_echo = bool(address) and _recent_bot_texts.get(address, "") == text;
                if is_echo {
                    _recent_bot_texts[address] = "";
                } elif address {
                    normalized = _normalize_imessage_address(address);
                    target_profile: CreditProfile | None = None;
                    if normalized {
                        for r in allroots() {
                            for p in [r -->][?:CreditProfile] {
                                if p.imessage_handle == normalized {
                                    target_profile = p;
                                }
                            }
                        }
                    }

                    if target_profile is None {
                        if chat_guid {
                            unknown_reply = "I don't recognize this number/email yet - connect on the LumiNode dashboard first.";
                            _send_imessage_reply(chat_guid, unknown_reply, address);
                        }
                    } else {
                        profile = target_profile as CreditProfile;
                        self.pending_user_text = text;
                        self.pending_chat_guid = chat_guid;
                        self.pending_address = address;
                        visit profile;
                    }
                }
            }
        }

        report {"ok": True};
    }
}
