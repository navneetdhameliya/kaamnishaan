"""Admin panel API (A01 log in, setup, A03 dashboard). Only staff tokens work here; an app user's
token is refused. Every log in, failed log in and setup is written to the audit log (A31)."""

import uuid
from datetime import datetime
from typing import Literal

from fastapi import APIRouter, Depends, Query, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Staff, client_ip, get_db, get_staff
from app.core.errors import AppError, Forbidden
from app.core.security import normalize_phone, now
from app.schemas.admin_ai import AdminAiUsageOut
from app.schemas.admin_ai_calls import (
    AdminAiCallSettings,
    AdminAiCallsOut,
    AdminCallScript,
    AdminScriptStepIn,
    AdminTestCall,
    AdminTestCallOut,
)
from app.schemas.admin_audit import AdminAuditList
from app.schemas.admin_checklists import (
    AdminChecklistApprove,
    AdminChecklistCreate,
    AdminChecklistDetail,
    AdminChecklistList,
    AdminChecklistPatch,
    AdminTranslateOut,
)
from app.schemas.admin_companies import (
    AdminCompanyCreate,
    AdminCompanyDetail,
    AdminCompanyList,
    AdminCompanyReason,
    AdminCompanyUpdate,
    AdminOwnerInvite,
)
from app.schemas.admin_credits import AdminCreditAdjust, AdminCreditRulesIn, AdminCreditsOut
from app.schemas.admin_email import AdminEmailIn, AdminEmailOut, AdminEmailTest, AdminEmailTestOut
from app.schemas.admin_jobs import AdminJobDetail, AdminJobList, JobStatus
from app.schemas.admin_leads import AdminLeadDetail, AdminLeadList, AdminLeadUpdate
from app.schemas.admin_messages import (
    AdminTemplate,
    AdminTemplateIn,
    AdminTemplatesOut,
    AdminTemplateTest,
    AdminTemplateTestOut,
    Channel,
    Lang,
    TemplateKey,
)
from app.schemas.admin_platform import AdminPlatformOut, AdminPlatformSettings
from app.schemas.admin_reviews import (
    AdminReviewDetail,
    AdminReviewHide,
    AdminReviewList,
    AdminReviewRules,
    ReviewStatusFilter,
)
from app.schemas.admin_staff import (
    AdminRolesOut,
    AdminStaffInvite,
    AdminStaffLink,
    AdminStaffRow,
    AdminStaffUpdate,
)
from app.schemas.admin_users import AdminUserAction, AdminUserDetail, AdminUserList
from app.schemas.checklists import QuestionIn, QuestionPatch
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
from app.services import (
    admin_ai,
    admin_ai_calls,
    admin_audit,
    admin_checklists,
    admin_companies,
    admin_credits,
    admin_dashboard,
    admin_email,
    admin_jobs,
    admin_leads,
    admin_messages,
    admin_platform,
    admin_reviews,
    admin_staff,
    admin_users,
    ai_calls,
    audit,
    staff,
)
from app.services import checklists as checklist_svc
from app.tasks import enqueue

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


@router.get("/ai-usage", response_model=AdminAiUsageOut)
async def ai_usage(
    days: int = Query(30, description="7, 30 or 90"),
    _: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminAiUsageOut:
    """A20: AI cost and use over the period. Every staff member can look."""
    if days not in (7, 30, 90):
        raise AppError(
            "validation_error", "Some fields are not valid.", fields={"days": "choose_7_30_90"}, status=422
        )
    return await admin_ai.usage(db, days=days)


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


def _can_change(me: Staff) -> None:
    if me.staff.role not in ("super_admin", "admin"):
        raise Forbidden("forbidden", "Support staff can look but not change companies.")


@router.post("/companies", response_model=AdminOwnerInvite, status_code=201)
async def create_company(
    body: AdminCompanyCreate, request: Request, locale: Locale = "en",
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminOwnerInvite:  # fmt: skip
    """A06: a company on a trial, and an invite for its owner. The owner logs in to the app with their
    phone (OTP) and accepts it. The join link is returned once, to share if SMS isn't set up."""
    _can_change(me)
    c, link, sms = await admin_companies.create_company(db, body, staff_id=me.staff.id, ip=client_ip(request))
    return AdminOwnerInvite(
        company=await admin_companies.company(db, c.id, lang=locale), invite_link=link, sms_text=sms
    )


@router.patch("/companies/{company_id}", response_model=AdminCompanyDetail)
async def update_company(
    company_id: uuid.UUID, body: AdminCompanyUpdate, request: Request, locale: Locale = "en",
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminCompanyDetail:  # fmt: skip
    """A07. Changing the country also changes the currency (no payments are taken yet)."""
    _can_change(me)
    await admin_companies.update_company(db, company_id, body, staff_id=me.staff.id, ip=client_ip(request))
    return await admin_companies.company(db, company_id, lang=locale)


@router.post("/companies/{company_id}/owner-invite", response_model=AdminOwnerInvite)
async def resend_owner_invite(
    company_id: uuid.UUID, request: Request, locale: Locale = "en",
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminOwnerInvite:  # fmt: skip
    """A new join link for an owner who hasn't joined; older links stop working."""
    _can_change(me)
    c, link, sms = await admin_companies.resend_owner_invite(
        db, company_id, staff_id=me.staff.id, ip=client_ip(request)
    )
    return AdminOwnerInvite(
        company=await admin_companies.company(db, c.id, lang=locale), invite_link=link, sms_text=sms
    )


@router.post("/companies/{company_id}/suspend", response_model=AdminCompanyDetail)
async def suspend_company(
    company_id: uuid.UUID, body: AdminCompanyReason, request: Request, locale: Locale = "en",
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminCompanyDetail:  # fmt: skip
    """Nobody in the company can work in the app until it is turned back on. Nothing is deleted."""
    _can_change(me)
    await admin_companies.suspend(
        db, company_id, reason=body.reason, staff_id=me.staff.id, ip=client_ip(request)
    )
    return await admin_companies.company(db, company_id, lang=locale)


@router.post("/companies/{company_id}/reactivate", response_model=AdminCompanyDetail)
async def reactivate_company(
    company_id: uuid.UUID, body: AdminCompanyReason, request: Request, locale: Locale = "en",
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminCompanyDetail:  # fmt: skip
    _can_change(me)
    await admin_companies.reactivate(
        db, company_id, reason=body.reason, staff_id=me.staff.id, ip=client_ip(request)
    )
    return await admin_companies.company(db, company_id, lang=locale)


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


# ---- A23 checklist templates (KaamNishaan's own) -----------------------------------------------------
def _can_edit(me: Staff) -> None:
    if me.staff.role not in ("super_admin", "admin"):
        raise Forbidden("forbidden", "Support staff can look but not change checklists.")


@router.get("/checklist-templates", response_model=AdminChecklistList)
async def checklist_templates(
    tab: Literal["all", "by_trade", "needs_translation", "drafts"] = "all",
    q: str | None = Query(None, max_length=120),
    trade: str | None = Query(None, max_length=40),
    language_state: Literal["ready", "review", "missing"] | None = None,
    locale: Locale = "en",
    _: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminChecklistList:
    """KaamNishaan's own checklists (not archived). language_state: some language is in that state."""
    return await admin_checklists.templates(
        db, tab=tab, q=q, trade=trade, lang_state=language_state, lang=locale
    )


@router.post("/checklist-templates", response_model=AdminChecklistDetail, status_code=201)
async def create_checklist(
    body: AdminChecklistCreate,
    locale: Locale = "en",
    me: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminChecklistDetail:
    """A new draft, written in English. Companies see it once it is published."""
    _can_edit(me)
    t = await admin_checklists.create(db, body, staff_id=me.staff.id)
    return await admin_checklists.detail(db, t.id, lang=locale)


@router.get("/checklist-templates/{template_id}", response_model=AdminChecklistDetail)
async def checklist_template(
    template_id: uuid.UUID,
    locale: Locale = "en",
    _: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminChecklistDetail:
    return await admin_checklists.detail(db, template_id, lang=locale)


@router.patch("/checklist-templates/{template_id}", response_model=AdminChecklistDetail)
async def patch_checklist(
    template_id: uuid.UUID, body: AdminChecklistPatch, locale: Locale = "en",
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminChecklistDetail:  # fmt: skip
    """Name (and its translations), trade, minutes, or status (published needs a question)."""
    _can_edit(me)
    t = await admin_checklists.global_template(db, template_id)
    await admin_checklists.update(db, t, body, staff_id=me.staff.id)
    return await admin_checklists.detail(db, template_id, lang=locale)


@router.post(
    "/checklist-templates/{template_id}/questions", response_model=AdminChecklistDetail, status_code=201
)
async def add_checklist_question(
    template_id: uuid.UUID, body: QuestionIn, locale: Locale = "en",
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminChecklistDetail:  # fmt: skip
    """Same rules as the app. Other languages are machine-translated afterwards (when AI is set up)."""
    _can_edit(me)
    if body.reference_upload_id:
        raise AppError(
            "validation_error",
            "Reference photos can't be added here yet.",
            fields={"reference_upload_id": "not_supported"},
        )
    t = await admin_checklists.global_template(db, template_id)
    q = await checklist_svc.add_question_to(db, t, body)
    await db.commit()
    await enqueue("translate_checklist_question", question_id=str(q.id))
    return await admin_checklists.detail(db, template_id, lang=locale)


@router.patch(
    "/checklist-templates/{template_id}/questions/{question_id}", response_model=AdminChecklistDetail
)
async def patch_checklist_question(
    template_id: uuid.UUID, question_id: uuid.UUID, body: QuestionPatch, locale: Locale = "en",
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminChecklistDetail:  # fmt: skip
    """Change the question (its other languages are translated again) or fix one translation by hand."""
    _can_edit(me)
    if body.reference_upload_id:
        raise AppError(
            "validation_error",
            "Reference photos can't be added here yet.",
            fields={"reference_upload_id": "not_supported"},
        )
    t = await admin_checklists.global_template(db, template_id)
    q = await checklist_svc.template_question(db, t, question_id)
    q, words_changed = await checklist_svc.update_question_in(db, t, q, body)
    await db.commit()
    if words_changed:
        await enqueue("translate_checklist_question", question_id=str(q.id))
    return await admin_checklists.detail(db, template_id, lang=locale)


@router.delete(
    "/checklist-templates/{template_id}/questions/{question_id}", response_model=AdminChecklistDetail
)
async def delete_checklist_question(
    template_id: uuid.UUID, question_id: uuid.UUID, locale: Locale = "en",
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminChecklistDetail:  # fmt: skip
    _can_edit(me)
    t = await admin_checklists.global_template(db, template_id)
    await checklist_svc.delete_question_in(db, t, await checklist_svc.template_question(db, t, question_id))
    return await admin_checklists.detail(db, template_id, lang=locale)


@router.post("/checklist-templates/{template_id}/approve", response_model=AdminChecklistDetail)
async def approve_checklist_language(
    template_id: uuid.UUID, body: AdminChecklistApprove, locale: Locale = "en",
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminChecklistDetail:  # fmt: skip
    """Mark all machine translations in one language as checked."""
    _can_edit(me)
    t = await admin_checklists.global_template(db, template_id)
    await admin_checklists.approve(db, t, body.language, staff_id=me.staff.id)
    return await admin_checklists.detail(db, template_id, lang=locale)


@router.post("/checklist-templates/{template_id}/translate", response_model=AdminTranslateOut)
async def translate_checklist(
    template_id: uuid.UUID, me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)
) -> AdminTranslateOut:
    """Machine-translate every question that is missing a language. Needs the AI key."""
    _can_edit(me)
    t = await admin_checklists.global_template(db, template_id)
    ids = await admin_checklists.untranslated(db, t)
    ai = admin_checklists.get_ai() is not None
    if ai:
        for qid in ids:
            await enqueue("translate_checklist_question", question_id=str(qid))
    return AdminTranslateOut(queued=len(ids) if ai else 0, ai_available=ai)


# ---- A37 Reviews and ratings ------------------------------------------------------------------------
RatingFilter = Literal["1", "2", "3", "4", "5", "low"]


def _can_moderate(me: Staff) -> None:
    if me.staff.role not in ("super_admin", "admin"):
        raise Forbidden("forbidden", "Support staff can look but not change reviews.")


@router.get("/reviews", response_model=AdminReviewList)
async def reviews(
    q: str | None = Query(None, max_length=120),
    rating: RatingFilter | None = None,
    status: ReviewStatusFilter | None = None,
    company: uuid.UUID | None = None,
    page: int = Query(1, ge=1, le=10_000),
    page_size: int = Query(25, ge=5, le=100),
    _: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminReviewList:
    """Every company's reviews; reviews held by the review rules come first, then newest first."""
    return await admin_reviews.reviews(
        db, q=q, rating=rating, status=status, company_id=company, page=page, page_size=page_size
    )


@router.get("/reviews.csv", response_class=Response, responses={200: {"content": {"text/csv": {}}}})
async def reviews_csv(
    q: str | None = Query(None, max_length=120),
    rating: RatingFilter | None = None,
    status: ReviewStatusFilter | None = None,
    company: uuid.UUID | None = None,
    me: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Every matching review (up to 50,000), for a spreadsheet. Exports are written to the audit log."""
    filters = {"q": q, "rating": rating, "status": status, "company": str(company) if company else None}
    body = await admin_reviews.reviews_csv(db, q=q, rating=rating, status=status, company_id=company)
    await audit.record(db, "staff.export", staff_id=me.staff.id, target_type="reviews",
                       data={k: v for k, v in filters.items() if v})  # fmt: skip
    return Response(
        "".join(body),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="kaamnishaan-reviews-{now():%Y-%m-%d}.csv"',
                 "Cache-Control": "no-store"},
    )  # fmt: skip


@router.get("/reviews/{review_id}", response_model=AdminReviewDetail)
async def review(
    review_id: uuid.UUID, me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)
) -> AdminReviewDetail:
    return await admin_reviews.detail(db, review_id, can_act=me.staff.role in ("super_admin", "admin"))


@router.post("/reviews/{review_id}/publish", response_model=AdminReviewDetail)
async def publish_review(
    review_id: uuid.UUID, request: Request, me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)
) -> AdminReviewDetail:
    """A held review goes to the company, with phone numbers and emails still hidden."""
    _can_moderate(me)
    await admin_reviews.publish(db, review_id, staff_id=me.staff.id, ip=client_ip(request))
    return await admin_reviews.detail(db, review_id, can_act=True)


@router.post("/reviews/{review_id}/hide", response_model=AdminReviewDetail)
async def hide_review(
    review_id: uuid.UUID, body: AdminReviewHide, request: Request,
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminReviewDetail:  # fmt: skip
    """Nobody but KaamNishaan staff sees it any more. It is kept and can be put back."""
    _can_moderate(me)
    await admin_reviews.hide(db, review_id, body.reason, staff_id=me.staff.id, ip=client_ip(request))
    return await admin_reviews.detail(db, review_id, can_act=True)


@router.post("/reviews/{review_id}/restore", response_model=AdminReviewDetail)
async def restore_review(
    review_id: uuid.UUID, request: Request, me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)
) -> AdminReviewDetail:
    _can_moderate(me)
    await admin_reviews.restore(db, review_id, staff_id=me.staff.id, ip=client_ip(request))
    return await admin_reviews.detail(db, review_id, can_act=True)


@router.get("/review-rules", response_model=AdminReviewRules)
async def review_rules(_: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)) -> AdminReviewRules:
    return await admin_reviews.rules(db)


@router.put("/review-rules", response_model=AdminReviewRules)
async def set_review_rules(
    body: AdminReviewRules,
    request: Request,
    me: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminReviewRules:
    """Checks run on every new review from now on; reviews already in are not checked again."""
    _can_moderate(me)
    return await admin_reviews.set_rules(db, body, staff_id=me.staff.id, ip=client_ip(request))


# ---- A38 AI review calls ----------------------------------------------------------------------------
@router.get("/ai-calls", response_model=AdminAiCallsOut)
async def ai_call_page(
    page: int = Query(1, ge=1, le=10_000),
    page_size: int = Query(20, ge=5, le=100),
    me: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminAiCallsOut:
    """The voice provider's health, the numbers, settings, call script and call log (newest first)."""
    can_act = me.staff.role in ("super_admin", "admin")
    return await admin_ai_calls.page(db, page=page, page_size=page_size, can_act=can_act)


@router.put("/ai-calls/settings", response_model=AdminAiCallSettings)
async def ai_call_settings(
    body: AdminAiCallSettings,
    request: Request,
    me: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminAiCallSettings:
    """Skipping do-not-call numbers and calling only jobs still without a rating are always on."""
    _can_moderate(me)
    return await admin_ai_calls.save_settings(db, body, staff_id=me.staff.id, ip=client_ip(request))


@router.put("/ai-calls/script/{step}", response_model=AdminCallScript)
async def ai_call_script_step(
    step: str, body: AdminScriptStepIn, request: Request,
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminCallScript:  # fmt: skip
    """Changes one step of the call script; the script gets a new version, used from the next call."""
    _can_moderate(me)
    return await admin_ai_calls.save_step(db, step, body.text, staff_id=me.staff.id, ip=client_ip(request))


@router.post("/ai-calls/test", response_model=AdminTestCallOut)
async def ai_call_test(
    body: AdminTestCall, request: Request, me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)
) -> AdminTestCallOut:
    """Calls your own phone with the live script. 409 no_voice_provider until a provider is connected."""
    _can_moderate(me)
    try:
        phone = normalize_phone(body.phone, "IN")
    except AppError:
        raise AppError("validation_error", "Some fields are not valid.", fields={"phone": "invalid"},
                       status=422) from None  # fmt: skip
    return await admin_ai_calls.test(db, phone, staff_id=me.staff.id, ip=client_ip(request))


@router.post("/ai-calls/retry")
async def ai_call_retry(me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)) -> dict:
    """Runs every due call now (after the provider is back), instead of waiting for the scheduler."""
    _can_moderate(me)
    return {"handled": await ai_calls.call_due(db)}


# ---- A39 Message templates --------------------------------------------------------------------------
@router.get("/message-templates", response_model=AdminTemplatesOut)
async def message_templates(
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)
) -> AdminTemplatesOut:
    """The texts customers get with report and rating links, per channel and language."""
    return await admin_messages.templates(db, can_act=me.staff.role in ("super_admin", "admin"))


@router.put("/message-templates/{template}/{channel}/{language}", response_model=AdminTemplate)
async def save_message_template(
    template: TemplateKey, channel: Channel, language: Lang, body: AdminTemplateIn, request: Request,
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminTemplate:  # fmt: skip
    """Publishes a new text, used from the next message. It counts as checked for that language."""
    _can_moderate(me)
    return await admin_messages.save(db, template, channel, language, body, staff_id=me.staff.id,
                                     ip=client_ip(request))  # fmt: skip


@router.post("/message-templates/{template}/{channel}/{language}/check", response_model=AdminTemplate)
async def check_message_template(
    template: TemplateKey, channel: Channel, language: Lang, request: Request,
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminTemplate:  # fmt: skip
    """A person read this language's text and it's fine as it is."""
    _can_moderate(me)
    return await admin_messages.mark(db, template, channel, language, reset=False, staff_id=me.staff.id,
                                     ip=client_ip(request))  # fmt: skip


@router.delete("/message-templates/{template}/{channel}/{language}", response_model=AdminTemplate)
async def reset_message_template(
    template: TemplateKey, channel: Channel, language: Lang, request: Request,
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminTemplate:  # fmt: skip
    """Back to the built-in text."""
    _can_moderate(me)
    return await admin_messages.mark(db, template, channel, language, reset=True, staff_id=me.staff.id,
                                     ip=client_ip(request))  # fmt: skip


@router.post("/message-templates/test", response_model=AdminTemplateTestOut)
async def test_message_template(
    body: AdminTemplateTest, me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)
) -> AdminTemplateTestOut:
    """Sends the text (as being edited, or as saved) with sample values to your own phone or email."""
    _can_moderate(me)
    return await admin_messages.test(db, body, staff_id=me.staff.id)


# ---- A40 Usage and credits --------------------------------------------------------------------------
@router.get("/credits", response_model=AdminCreditsOut)
async def credit_overview(
    q: str | None = Query(None, max_length=120),
    page: int = Query(1, ge=1, le=10_000),
    page_size: int = Query(20, ge=5, le=100),
    locale: Locale = "en",
    me: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminCreditsOut:
    """Credits used, the credit rules, plan credits and every company's credits (out of credits first)."""
    return await admin_credits.overview(
        db,
        q=q,
        page=page,
        page_size=page_size,
        lang=locale,
        can_act=me.staff.role in ("super_admin", "admin"),
    )


@router.get("/credits.csv", response_class=Response, responses={200: {"content": {"text/csv": {}}}})
async def credits_csv(
    q: str | None = Query(None, max_length=120), locale: Locale = "en",
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> Response:  # fmt: skip
    body = await admin_credits.credits_csv(db, q=q, lang=locale)
    await audit.record(
        db, "staff.export", staff_id=me.staff.id, target_type="credits", data={"q": q} if q else {}
    )
    return Response(
        "".join(body),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="kaamnishaan-credits-{now():%Y-%m-%d}.csv"',
                 "Cache-Control": "no-store"},
    )  # fmt: skip


@router.put("/credits/rules", status_code=204)
async def credit_rules(
    body: AdminCreditRulesIn,
    request: Request,
    me: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Credits per SMS, WhatsApp and AI call (used from the next message) and each plan's monthly credits
    (each company gets the new amount from its next month)."""
    _can_change(me)
    await admin_credits.save_rules(db, body, staff_id=me.staff.id, ip=client_ip(request))
    return Response(status_code=204)


@router.post("/companies/{company_id}/credits", status_code=204)
async def adjust_credits(
    company_id: uuid.UUID, body: AdminCreditAdjust, request: Request,
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> Response:  # fmt: skip
    """Adds (or takes back) extra credits for one company. They stay until used, like a top-up."""
    _can_change(me)
    await admin_credits.adjust(db, company_id, body.credits, body.reason, staff_id=me.staff.id,
                               ip=client_ip(request))  # fmt: skip
    return Response(status_code=204)


# ---- A32 Platform settings --------------------------------------------------------------------------
@router.get("/platform-settings", response_model=AdminPlatformOut)
async def platform_settings(
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)
) -> AdminPlatformOut:
    return await admin_platform.get(db, can_act=me.staff.role == "super_admin")


@router.put("/platform-settings", response_model=AdminPlatformOut)
async def save_platform_settings(
    body: AdminPlatformSettings,
    request: Request,
    me: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminPlatformOut:
    """Only super admins: these switches change things for every company at once."""
    if me.staff.role != "super_admin":
        raise Forbidden("forbidden", "Only a super admin can change platform settings.")
    return await admin_platform.save(db, body, staff_id=me.staff.id, ip=client_ip(request))


# ---- A33 Email settings ------------------------------------------------------------------------------
def _super(me: Staff) -> None:
    if me.staff.role != "super_admin":
        raise Forbidden("forbidden", "Only a super admin can change email settings.")


@router.get("/email-settings", response_model=AdminEmailOut)
async def email_settings(me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)) -> AdminEmailOut:
    """The password is never sent back; `password_set` says whether one is saved."""
    return await admin_email.get(db, can_act=me.staff.role == "super_admin")


@router.put("/email-settings", response_model=AdminEmailOut)
async def save_email_settings(
    body: AdminEmailIn, request: Request, me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)
) -> AdminEmailOut:
    _super(me)
    return await admin_email.save(db, body, staff_id=me.staff.id, ip=client_ip(request))


@router.post("/email-settings/test", response_model=AdminEmailTestOut)
async def test_email_settings(
    body: AdminEmailTest, request: Request, me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)
) -> AdminEmailTestOut:
    """Sends a test with the saved settings. 409 email_not_set, or 502 smtp_failed with the reason."""
    _super(me)
    return AdminEmailTestOut(
        to=await admin_email.test(db, str(body.to), staff_id=me.staff.id, ip=client_ip(request))
    )


# ---- A10 Roles and permissions, staff accounts -------------------------------------------------------
def _super_only(me: Staff) -> None:
    if me.staff.role != "super_admin":
        raise Forbidden("forbidden", "Only a super admin can manage staff accounts.")


@router.get("/roles", response_model=AdminRolesOut)
async def roles(me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)) -> AdminRolesOut:
    """Who can do what (from the rules the server enforces) and the KaamNishaan staff accounts."""
    return AdminRolesOut(
        matrix=admin_staff.matrix(), staff_matrix=admin_staff.staff_matrix(),
        staff=await admin_staff.staff_list(db, me.staff.id), can_act=me.staff.role == "super_admin",
    )  # fmt: skip


@router.post("/staff", response_model=AdminStaffLink, status_code=201)
async def invite_staff(
    body: AdminStaffInvite, me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)
) -> AdminStaffLink:
    """The setup link is shown once, to share yourself (no email needed). It works for 72 hours."""
    _super_only(me)
    row, link = await admin_staff.invite(
        db, name=body.name, email=str(body.email), role=body.role, by=me.staff.id
    )
    return AdminStaffLink(staff=row, setup_link=link)


@router.patch("/staff/{staff_id}", response_model=AdminStaffRow)
async def update_staff(
    staff_id: uuid.UUID, body: AdminStaffUpdate, request: Request,
    me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db),
) -> AdminStaffRow:  # fmt: skip
    """Change the role, or turn the account off (signs them out at once) or back on."""
    _super_only(me)
    return await admin_staff.change(db, staff_id, role=body.role, active=body.active, by=me.staff.id,
                                    ip=client_ip(request))  # fmt: skip


@router.post("/staff/{staff_id}/setup-link", response_model=AdminStaffLink)
async def staff_setup_link(
    staff_id: uuid.UUID, me: Staff = Depends(get_staff), db: AsyncSession = Depends(get_db)
) -> AdminStaffLink:
    """For a lost phone or password: clears their password and authenticator and signs them out."""
    _super_only(me)
    row, link = await admin_staff.new_link(db, staff_id, by=me.staff.id)
    return AdminStaffLink(staff=row, setup_link=link)


# ---- A11 Jobs, A12 Job details (read-only) -----------------------------------------------------------
@router.get("/jobs", response_model=AdminJobList)
async def jobs(
    q: str | None = Query(None, max_length=120),
    status: JobStatus | None = None,
    company: uuid.UUID | None = None,
    start: datetime | None = Query(None, alias="from", description="Scheduled (or created) from"),
    end: datetime | None = Query(None, alias="to", description="...and before"),
    page: int = Query(1, ge=1, le=10_000),
    page_size: int = Query(25, ge=5, le=100),
    _: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminJobList:
    """Every company's jobs, newest first by scheduled time. The browser sends its own day as from/to."""
    return await admin_jobs.jobs(db, q=q, status=status, company_id=company, start=start, end=end, page=page,
                                 page_size=page_size)  # fmt: skip


@router.get("/jobs.csv", response_class=Response, responses={200: {"content": {"text/csv": {}}}})
async def jobs_csv(
    q: str | None = Query(None, max_length=120),
    status: JobStatus | None = None,
    company: uuid.UUID | None = None,
    start: datetime | None = Query(None, alias="from"),
    end: datetime | None = Query(None, alias="to"),
    me: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Every matching job (up to 50,000), for a spreadsheet. Exports are written to the audit log."""
    filters = {
        "q": q, "status": status, "company": str(company) if company else None,
        "from": start.isoformat() if start else None, "to": end.isoformat() if end else None,
    }  # fmt: skip
    body = await admin_jobs.jobs_csv(db, q=q, status=status, company_id=company, start=start, end=end)
    await audit.record(db, "staff.export", staff_id=me.staff.id, target_type="jobs",
                       data={k: v for k, v in filters.items() if v})  # fmt: skip
    return Response(
        "".join(body),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="kaamnishaan-jobs-{now():%Y-%m-%d}.csv"',
                 "Cache-Control": "no-store"},
    )  # fmt: skip


@router.get("/jobs/{job_id}", response_model=AdminJobDetail)
async def job(
    job_id: uuid.UUID,
    locale: Locale = "en",
    _: Staff = Depends(get_staff),
    db: AsyncSession = Depends(get_db),
) -> AdminJobDetail:
    """One job: details, where it was started, proof so far, the report and the full timeline."""
    return await admin_jobs.detail(db, job_id, locale)
