"""What each role may do. Screens hide buttons from this list; the API enforces it again."""

OWNER = {
    "company.manage", "billing.manage", "team.invite_manager", "team.invite_technician", "team.manage",
    "customers.manage", "jobs.create", "jobs.assign", "jobs.view_all", "reports.approve", "reports.share",
    "reviews.manage", "reviews.request", "checklists.manage",
}  # fmt: skip
MANAGER = {
    "team.invite_technician", "team.manage", "customers.manage", "jobs.create", "jobs.assign",
    "jobs.view_all", "reports.approve", "reports.share", "reviews.manage", "reviews.request", "checklists.manage",
}  # fmt: skip
TECHNICIAN = {"jobs.create_quick", "jobs.view_own", "evidence.capture", "reports.submit"}


def permissions_for(role: str | None, company_settings: dict | None = None) -> set[str]:
    s = company_settings or {}
    if role == "owner":
        return set(OWNER)
    if role == "manager":
        return set(MANAGER)
    if role == "technician":
        perms = set(TECHNICIAN)
        if s.get("technicians_can_share", False):
            perms.add("reports.share")
        if s.get("technicians_can_request_reviews", True):
            perms.add("reviews.request")
        return perms
    return set()
