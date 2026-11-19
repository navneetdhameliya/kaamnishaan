"""Admin panel API (A01 log in, setup, A03 dashboard). Only staff tokens work here; an app user's
token is refused. Every log in, failed log in and setup is written to the audit log (A31)."""

import uuid
from typing import Literal

from fastapi import APIRouter, Depends, Query, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Staff, client_ip, get_db, get_staff
from app.core.errors import AppError, Forbidden
from app.core.security import now
from app.schemas.admin_audit import AdminAuditList
from app.schemas.admin_companies import AdminCompanyDetail, AdminCompanyList
from app.schemas.admin_leads import AdminLeadDetail, AdminLeadList, AdminLeadUpdate
from app.schemas.admin_users import AdminUserAction, AdminUserDetail, AdminUserList
from app.schemas.identity import Locale
from app.schemas.staff import (
    AdminDashboardOut,
    StaffLoginIn,
    StaffOut,
    StaffRefreshIn,
    StaffSessionOut,
    StaffSetupIn,
    StaffSetupInfo,
    StaffSetupOut,
)
from app.services import admin_audit, admin_companies, admin_dashboard, admin_leads, admin_users, audit, staff

router = APIRouter(prefix="/admin", tags=["admin"])


@router.post("/auth/login", response_model=StaffSessionOut)
async def login(body: StaffLoginIn, request: Request, db: AsyncSession = Depends(get_db)) -> StaffSessionOut:
    """Email, password and the 6-digit code from the authenticator app (or one recovery code).
    Five wrong tries lock the email for 15 minutes; the error never says which part was wrong."""
    return await staff.login(
        db,
        email=body.email,
        password=body.password,
        code=body.code,
        recovery_code=body.recovery_code,
        ip=client_ip(request),
        agent=request.headers.get("user-agent"),
    )


@router.post("/auth/refresh", response_model=StaffSessionOut)
async def refresh(body: StaffRefreshIn, db: AsyncSession = Depends(get_db)) -> StaffSessionOut:
    """New tokens; the old refresh token stops working. A staff session ends 12 hours after log in."""
    return await staff.refresh(db, body.refresh_token)


@router.post("/auth/logout", status_code=204)
async def logout(me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)) -> Response:
    await staff.logout(db, me.session_id)
    return Response(status_code=204)


@router.get("/auth/setup", response_model=StaffSetupInfo)
async def setup_info(token: str, response: Response, db: AsyncSession = Depends(get_db)) -> StaffSetupInfo:
    """What the setup page needs: the authenticator secret (and QR text) for this link."""
    response.headers["Cache-Control"] = "no-store"
    return await staff.setup_info(db, token)


@router.post("/auth/setup", response_model=StaffSetupOut)
async def setup(body: StaffSetupIn, request: Request, db: AsyncSession = Depends(get_db)) -> StaffSetupOut:
    """Choose a password and confirm the first code. Returns 8 recovery codes, shown only once."""
    return await staff.finish_setup(
        db,
        token=body.token,
        password=body.password,
        code=body.code,
        ip=client_ip(request),
        agent=request.headers.get("user-agent"),
    )


@router.get("/me", response_model=StaffOut)
async def me(s: Staff = Depends(get_staff)) -> StaffOut:
    return staff.staff_out(s.staff)


@router.get("/dashboard", response_model=AdminDashboardOut)
async def dashboard(
    days: int = Query(30, description="7, 30 or 90"),
    locale: Locale = "en",
    _: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminDashboardOut:
    if days not in (7, 30, 90):
        raise AppError(
            "validation_error", "Some fields are not valid.", fields={"days": "choose_7_30_90"}, status=422
        )
    return await admin_dashboard.dashboard(db, days=days, lang=locale)


# ---- A04 / A05 companies ------------------------------------------------------------------------------
Status = Literal["trial", "active", "past_due", "suspended", "cancelled"]
Sort = Literal["reports", "name", "newest", "technicians"]


@router.get("/companies", response_model=AdminCompanyList)
async def companies(
    q: str | None = Query(None, max_length=120, description="Company, owner name, email or phone"),
    status: Status | None = None,
    plan: str | None = Query(None, max_length=24),
    industry: str | None = Query(None, max_length=40),
    country: str | None = Query(None, min_length=2, max_length=2),
    sort: Sort = "reports",
    page: int = Query(1, ge=1, le=10_000),
    page_size: int = Query(20, ge=5, le=100),
    locale: Locale = "en",
    _: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminCompanyList:
    return await admin_companies.companies(
        db, lang=locale, q=q, status=status, plan=plan, industry=industry, country=country, sort=sort,
        page=page, page_size=page_size,
    )  # fmt: skip


@router.get("/companies.csv", response_class=Response, responses={200: {"content": {"text/csv": {}}}})
async def companies_csv(
    q: str | None = Query(None, max_length=120),
    status: Status | None = None,
    plan: str | None = Query(None, max_length=24),
    industry: str | None = Query(None, max_length=40),
    country: str | None = Query(None, min_length=2, max_length=2),
    sort: Sort = "reports",
    locale: Locale = "en",
    me: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Every matching company (not just one page), for a spreadsheet. Exports are written to the audit log."""
    filters = {"q": q, "status": status, "plan": plan, "industry": industry, "country": country}
    body = await admin_companies.companies_csv(db, lang=locale, sort=sort, **filters)
    await audit.record(db, "staff.export", staff_id=me.staff.id, target_type="companies",
                       data={k: v for k, v in filters.items() if v})  # fmt: skip
    stamp = now().strftime("%Y-%m-%d")
    return Response(
        "".join(body),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="kaamnishaan-companies-{stamp}.csv"',
                 "Cache-Control": "no-store"},
    )  # fmt: skip


@router.get("/companies/{company_id}", response_model=AdminCompanyDetail)
async def company(
    company_id: uuid.UUID,
    locale: Locale = "en",
    _: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminCompanyDetail:
    return await admin_companies.company(db, company_id, lang=locale)


# ---- A08 / A09 users ------------------------------------------------------------------------------------
@router.get("/users", response_model=AdminUserList)
async def users(
    q: str | None = Query(None, max_length=120, description="Name, phone, email or company"),
    role: Literal["owner", "manager", "technician"] | None = None,
    status: Literal["active", "invited", "removed", "disabled"] | None = None,
    language: Locale | None = None,
    company: uuid.UUID | None = None,
    page: int = Query(1, ge=1, le=10_000),
    page_size: int = Query(20, ge=5, le=100),
    _: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminUserList:
    """One row per person per company, latest active first. Without a status, removed people are hidden."""
    return await admin_users.users(
        db,
        q=q,
        role=role,
        status=status,
        language=language,
        company_id=company,
        page=page,
        page_size=page_size,
    )


@router.get("/users/{user_id}", response_model=AdminUserDetail)
async def user(
    user_id: uuid.UUID, _: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)
) -> AdminUserDetail:
    return await admin_users.user(db, user_id)


def _can_act(me: Staff) -> None:
    if me.staff.role not in ("super_admin", "admin"):
        raise Forbidden("forbidden", "Support staff can look but not change accounts.")


@router.post("/users/{user_id}/deactivate", response_model=AdminUserDetail)
async def deactivate(
    user_id: uuid.UUID, body: AdminUserAction, request: Request,
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminUserDetail:  # fmt: skip
    """Turn the person off for every company: they can't log in and every session ends."""
    _can_act(me)
    return await admin_users.set_active(
        db, user_id, active=False, reason=body.reason, staff_id=me.staff.id, ip=client_ip(request)
    )


@router.post("/users/{user_id}/reactivate", response_model=AdminUserDetail)
async def reactivate(
    user_id: uuid.UUID, body: AdminUserAction, request: Request,
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminUserDetail:  # fmt: skip
    _can_act(me)
    return await admin_users.set_active(
        db, user_id, active=True, reason=body.reason, staff_id=me.staff.id, ip=client_ip(request)
    )


@router.post("/users/{user_id}/sign-out", response_model=AdminUserDetail)
async def sign_out(
    user_id: uuid.UUID, body: AdminUserAction, request: Request,
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminUserDetail:  # fmt: skip
    """End every session (lost phone, shared device). The person can log in again."""
    _can_act(me)
    return await admin_users.sign_out(
        db, user_id, reason=body.reason, staff_id=me.staff.id, ip=client_ip(request)
    )


# ---- website leads (demo bookings, contact messages, newsletter) ------------------------------------
@router.get("/leads", response_model=AdminLeadList)
async def leads(
    tab: Literal["new", "demo", "contact", "newsletter", "done"] = "new",
    q: str | None = Query(None, max_length=120, description="Name, email, company, message or KN-number"),
    page: int = Query(1, ge=1, le=10_000),
    page_size: int = Query(20, ge=5, le=100),
    _: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminLeadList:
    """new: demos and messages nobody has handled yet; done: contacted, done or spam."""
    return await admin_leads.leads(db, tab=tab, q=q, page=page, page_size=page_size)


@router.get("/leads/newsletter.csv", response_class=Response, responses={200: {"content": {"text/csv": {}}}})
async def newsletter_csv(me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)) -> Response:
    """Every newsletter email, for a mailing tool. Each export is written to the audit log."""
    body = await admin_leads.newsletter_csv(db)
    await audit.record(db, "staff.export", staff_id=me.staff.id, target_type="newsletter")
    return Response(
        body,
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": f'attachment; filename="kaamnishaan-newsletter-{now():%Y-%m-%d}.csv"',
            "Cache-Control": "no-store",
        },
    )


@router.get("/leads/{lead_id}", response_model=AdminLeadDetail)
async def lead(
    lead_id: uuid.UUID,
    locale: Locale = "en",
    _: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminLeadDetail:
    return await admin_leads.lead(db, lead_id, lang=locale)


@router.patch("/leads/{lead_id}", response_model=AdminLeadDetail)
async def update_lead(
    lead_id: uuid.UUID,
    body: AdminLeadUpdate,
    request: Request,
    locale: Locale = "en",
    me: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminLeadDetail:
    """Change the status and / or the staff note. Support staff can do this too."""
    return await admin_leads.update(
        db, lead_id, body, staff_id=me.staff.id, ip=client_ip(request), lang=locale
    )


# ---- A31 audit logs -------------------------------------------------------------------------------------
Actor = Literal["staff", "user", "system"]
Group = Literal["security", "admin", "company", "team", "jobs", "reports"]
DAYS = (1, 7, 30, 90, 365)


def _days(days: int = Query(7, description="1, 7, 30, 90 or 365")) -> int:
    if days not in DAYS:
        raise AppError(
            "validation_error", "Some fields are not valid.", fields={"days": "choose_from_list"}, status=422
        )
    return days


@router.get("/audit-logs", response_model=AdminAuditList)
async def audit_logs(
    q: str | None = Query(
        None, max_length=120, description="Actor name or email, action, target, IP, details"
    ),
    actor: Actor | None = None,
    group: Group | None = None,
    company: uuid.UUID | None = None,
    days: int = Depends(_days),
    page: int = Query(1, ge=1, le=10_000),
    page_size: int = Query(25, ge=5, le=100),
    _: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminAuditList:
    """Newest first. Every staff member can read it; nobody can change or delete entries."""
    return await admin_audit.logs(
        db, q=q, actor=actor, group=group, company_id=company, days=days, page=page, page_size=page_size
    )


@router.get("/audit-logs.csv", response_class=Response, responses={200: {"content": {"text/csv": {}}}})
async def audit_logs_csv(
    q: str | None = Query(None, max_length=120),
    actor: Actor | None = None,
    group: Group | None = None,
    company: uuid.UUID | None = None,
    days: int = Depends(_days),
    me: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Up to 50,000 matching entries. The export itself is written to the audit log."""
    body = await admin_audit.logs_csv(db, q=q, actor=actor, group=group, company_id=company, days=days)
    await audit.record(
        db, "staff.export", staff_id=me.staff.id, target_type="audit_logs",
        data={k: v for k, v in {"q": q, "actor": actor, "group": group, "days": days}.items() if v},
    )  # fmt: skip
    return Response(
        body,
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": f'attachment; filename="kaamnishaan-audit-{now():%Y-%m-%d}.csv"',
            "Cache-Control": "no-store",
        },
    )
