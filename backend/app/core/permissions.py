"""What each role may do (API document, Roles and permissions; Figma A10).

Screens hide or disable buttons from this list; the API enforces it again on every call.
"""

_SHARED = {
    "company.view", "customers.manage", "jobs.create", "jobs.assign", "jobs.view_all",
    "evidence.capture", "reports.edit", "reports.approve", "reports.share",
    "checklists.manage", "reviews.request", "reviews.view_all", "reviews.reply",
    "reviews.settings", "ai.assistant", "team.view", "team.invite_technician",
}  # fmt: skip
OWNER = _SHARED | {
    "company.manage", "billing.manage", "team.invite_manager", "team.manage_managers", "audit.view",
}  # fmt: skip
MANAGER = set(_SHARED)
TECHNICIAN = {
    "jobs.create_quick", "jobs.view_own", "evidence.capture", "reports.edit_own", "reports.submit",
    "ai.assistant",  # about their own jobs (D-150)
}  # fmt: skip


def permissions_for(
    role: str | None, company_settings: dict | None = None, features: list[str] | None = None
) -> set[str]:
    """[features]: what the plan switches on (D-147). Without "manager_approvals" (Free, Starter) only the
    owner approves reports; managers still see, edit and share them (D-148)."""
    s = company_settings or {}
    if role == "owner":
        return set(OWNER)
    if role == "manager":
        if features is not None and "manager_approvals" not in features:
            return MANAGER - {"reports.approve"}
        return set(MANAGER)
    if role == "technician":
        perms = set(TECHNICIAN)
        if s.get("technicians_can_share", False):
            perms.add("reports.share")
        if s.get("technicians_can_request_reviews", True):
            perms.add("reviews.request")
        if s.get("techs_see_reviews", True):
            perms.add("reviews.view_own")
        return perms
    return set()
