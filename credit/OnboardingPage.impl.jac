"""LumiNode - Onboarding wizard handlers."""

impl OnboardingPage.bootstrapPage() -> None {
    params = new(URLSearchParams, location.search);  # jac:ignore[E1053]
    editing = params.get("edit");  # jac:ignore[E1031]

    bundle = await get_dashboard_data();
    if bundle.has_profile {
        if not editing {
            nav("/dashboard", {"replace": True});
            return;
        }
        edit_data = await get_edit_payload();  # jac:ignore[E1053]
        if edit_data {
            applyEditPayload(edit_data);
        }
        return;
    }

    sample = params.get("sample");  # jac:ignore[E1031]
    if sample {
        fillMaria();
    }
}

impl OnboardingPage.handleSubmit() -> None {
    submitting = True;
    submitError = "";
    payload = {
        "name": name.strip() if name.strip() else "Friend",
        "current_score": parse_int(currentScore, 580),
        "target_score": parse_int(targetScore, 680),
        "credit_history_years": parse_float(creditHistoryYears, 2.0),
        "num_inquiries": parse_int(numInquiries, 0),
        "monthly_income": parse_float(monthlyIncome, 0.0),
        "monthly_cost_of_living": parse_float(costOfLiving, 0.0),
        "savings_balance": parse_float(savings, 0.0),
        "investment_balance": parse_float(investment, 0.0),
        "cards": buildCards(),
        "loans": buildLoans()
    };

    result: any = None;
    try {
        result = await submit_onboarding(payload);  # jac:ignore[E1053]
    } except Exception {
        result = None;
    }

    submitting = False;
    if result is not None and result.has_profile {
        nav("/dashboard");
    } else {
        submitError = "Something went wrong saving your info - please try again.";
    }
}
