"""Sending an approved report to the customer (M34, M35) and the customer's report page (W27).

Links: one current link per report, valid 30 days. Creating, sending or renewing pushes the expiry to
30 days from now. A turned-off (revoked) link stays off; the next share makes a new one.
"""

import base64
import hashlib
import hmac
import uuid
from datetime import timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.deps import Principal
from app.core.errors import AppError, Conflict, Gone, NotFound, RateLimited
from app.core.security import normalize_phone, now
from app.models import (
    Company,
    CustomerContact,
    Job,
    JobEvent,
    Membership,
    Message,
    Report,
    ReportIssue,
    ShareLink,
    User,
)
from app.providers import messaging
from app.providers.storage import get_storage
from app.schemas.sharing import (
    Acknowledgement,
    ChannelOut,
    MessageOut,
    NewLinkOut,
    PdfOut,
    Preview,
    PublicChecklist,
    PublicCompany,
    PublicItem,
    PublicPair,
    PublicPhoto,
    PublicReport,
    Recipient,
    SendIn,
    ShareInfo,
    ShareLinkOut,
)
from app.services import audit, messages, notifications
from app.services import email as email_svc
from app.services.report_labels import LABELS, fmt_date, label
from app.services.report_view import customer_view
from app.services.reports import DONE, get_report, rlabel

LINK_DAYS = 30
NEW_LINK_WAIT = timedelta(hours=1)
ISSUES_PER_DAY = 5
LANGS = list(LABELS)


# ---- link tokens -------------------------------------------------------------------------------------
def _mac(link_id: uuid.UUID) -> bytes:
    key = get_settings().secret_key.get_secret_value().encode()
    return hmac.new(key, b"share-link:" + link_id.bytes, hashlib.sha256).digest()[:16]


def make_token(link_id: uuid.UUID) -> str:
    return base64.urlsafe_b64encode(link_id.bytes + _mac(link_id)).decode().rstrip("=")


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def parse_token(token: str) -> uuid.UUID | None:
    try:
        raw = base64.urlsafe_b64decode(token + "=" * (-len(token) % 4))
    except (ValueError, TypeError):
        return None
    if len(raw) != 32:
        return None
    link_id = uuid.UUID(bytes=raw[:16])
    return link_id if hmac.compare_digest(raw[16:], _mac(link_id)) else None


async def email_on(db: AsyncSession, group: str = "reports") -> bool:
    """False until an email service is connected in the admin panel (A33; D-96)."""
    return await email_svc.email_on(db, group)


def link_url(link: ShareLink) -> str:
    return f"{get_settings().web_url.rstrip('/')}/r/{make_token(link.id)}"


def link_state(link: ShareLink) -> str:
    if link.revoked_at:
        return "revoked"
    return "expired" if link.expires_at <= now() else "active"


def link_out(link: ShareLink) -> ShareLinkOut:
    return ShareLinkOut(
        id=link.id,
        url=link_url(link),
        channel=link.channel,
        status=link_state(link),
        expires_at=link.expires_at,
        open_count=link.open_count,
        first_opened_at=link.first_opened_at,
        last_opened_at=link.last_opened_at,
        created_at=link.created_at,
    )


def mask(value: str | None) -> str | None:
    if not value:
        return None
    if "@" in value:
        name, _, domain = value.partition("@")
        return f"{name[:1]}•••@{domain}"
    return f"{value[:-7]}•••{value[-3:]}" if len(value) > 7 else "•••"


# ---- PDF (M34) -------------------------------------------------------------------------------------
def pdf_out(rep: Report) -> PdfOut:
    ready = rep.pdf_status == "ready" and rep.pdf_key
    filename = f"{rlabel(rep.number)}.pdf"
    return PdfOut(
        status=rep.pdf_status or "building",
        filename=filename,
        url=get_storage().presign_get(rep.pdf_key, filename=filename) if ready else None,
        pages=rep.pdf_pages,
        size=rep.pdf_size,
        sha256=rep.pdf_sha256,
        built_at=rep.pdf_built_at,
        error=rep.pdf_error,
    )


def needs_pdf(rep: Report) -> bool:
    """True when the PDF should be (re)built; marks it building so the answer already says so."""
    if rep.status in DONE and rep.pdf_status in (None, "failed"):
        rep.pdf_status, rep.pdf_error = "building", None
        return True
    return False


async def get_pdf(db: AsyncSession, p: Principal, report_id: uuid.UUID) -> tuple[Report, bool]:
    rep, _ = await get_report(db, p, report_id, lock=True)
    if rep.status not in DONE:
        raise Conflict(
            "report_not_approved", "The PDF is made after the report is approved.", {"status": rep.status}
        )
    return rep, needs_pdf(rep)


# ---- share screen (M35) ------------------------------------------------------------------------------
async def _contact(db: AsyncSession, job: Job) -> CustomerContact | None:
    return (
        await db.execute(
            select(CustomerContact)
            .where(CustomerContact.customer_id == job.customer_id, CustomerContact.deleted_at.is_(None))
            .order_by(CustomerContact.is_primary.desc(), CustomerContact.created_at)
            .limit(1)
        )
    ).scalar_one_or_none()


async def current_link(db: AsyncSession, rep: Report) -> ShareLink | None:
    return (
        await db.execute(
            select(ShareLink)
            .where(ShareLink.report_id == rep.id, ShareLink.revoked_at.is_(None))
            .order_by(ShareLink.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()


def _texts(
    view_company: str, rep: Report, job: Job, url: str, name: str | None, expires,
    store: dict | None = None, template: str = "report_link",
) -> Preview:  # fmt: skip
    """The messages for one send, from the A39 message templates (staff's edits, else the defaults)."""
    lang = rep.language
    store = store or {}
    values = {
        "company": view_company, "customer": name or "", "job": job.title,
        "report_number": rlabel(rep.number), "link": url, "expires": fmt_date(expires, lang),
    }  # fmt: skip
    channels = messages.TEMPLATES[template]["channels"]
    sms = messages.render(store, template, "sms", lang, **values)["text"]
    wa = (
        messages.render(store, template, "whatsapp", lang, **values)["text"]
        if "whatsapp" in channels
        else sms
    )
    email = (
        messages.render(store, template, "email", lang, **values)
        if "email" in channels
        else {"subject": "", "body": sms}
    )
    return Preview(
        language=lang,
        sms=sms,
        whatsapp=wa,
        email_subject=email["subject"],
        email_body=email["body"],
    )


async def share_info(db: AsyncSession, p: Principal, report_id: uuid.UUID) -> ShareInfo:
    p.require("reports.share")
    rep, job = await get_report(db, p, report_id)
    contact = await _contact(db, job)
    link = await current_link(db, rep)
    company = await db.get(Company, rep.company_id)
    phone, email = (contact.phone, contact.email) if contact else (None, None)
    mail_on = await email_on(db)
    channels = [
        ChannelOut(key="sms", available=bool(phone), to=phone, reason=None if phone else "no_phone"),
        ChannelOut(key="whatsapp", available=bool(phone), to=phone, reason=None if phone else "no_phone"),
        ChannelOut(
            key="email",
            available=bool(email) and mail_on,
            to=email,
            reason="email_off" if not mail_on else (None if email else "no_email"),
        ),
    ]
    approved = rep.status in DONE
    preview = None
    if approved:
        url = link_url(link) if link and link_state(link) == "active" else "{link}"
        expires = (link.expires_at if link else now() + timedelta(days=LINK_DAYS)).astimezone()
        store = await messages.load(db)
        preview = _texts(company.name, rep, job, url, contact.name if contact else None, expires, store)
    sent = (
        await db.execute(
            select(Message).where(Message.report_id == rep.id).order_by(Message.created_at.desc())
        )
    ).scalars()
    from app.services import reviews

    review_ask = await reviews.share_default(db, job)
    return ShareInfo(
        report_id=rep.id,
        report_status=rep.status,
        can_share=approved,
        blocked_by=None if approved else "not_approved",
        recipient=Recipient(name=contact.name, phone=phone, email=email) if contact else None,
        channels=channels,
        link=link_out(link) if link else None,
        preview=preview,
        sent=[
            MessageOut(
                id=m.id, channel=m.channel, to=m.to, status=m.status, error=m.error, created_at=m.created_at
            )
            for m in sent
        ],
        review_ask=review_ask,
    )


async def _ensure_link(
    db: AsyncSession,
    rep: Report,
    channel: str,
    user_id: uuid.UUID | None,
    name: str | None = None,
    phone: str | None = None,
    email: str | None = None,
) -> ShareLink:
    link = await current_link(db, rep)
    expires = now() + timedelta(days=LINK_DAYS)
    if link:
        link.expires_at = expires
        link.recipient_name = name or link.recipient_name
        link.phone, link.email = phone or link.phone, email or link.email
    else:
        link_id = uuid.uuid4()
        link = ShareLink(
            id=link_id,
            company_id=rep.company_id,
            report_id=rep.id,
            token_hash=token_hash(make_token(link_id)),
            channel=channel,
            recipient_name=name,
            phone=phone,
            email=email,
            expires_at=expires,
            created_by=user_id,
        )
        db.add(link)
    await db.flush()
    return link


async def _mark_shared(db: AsyncSession, p: Principal, rep: Report, job: Job, channels: list[str]) -> None:
    if rep.status == "approved":
        rep.status, rep.shared_at = "shared", now()
        db.add(
            JobEvent(
                company_id=job.company_id,
                job_id=job.id,
                type="report_shared",
                from_status=job.status,
                to_status=job.status,
                actor_id=p.user.id,
                data={"report": rlabel(rep.number), "channels": channels},
            )
        )
        await notifications.notify(
            db, company_id=job.company_id, to=[job.assigned_to], kind="report_shared", actor_id=p.user.id,
            job=job, report_id=rep.id,
            params={**await notifications.job_params(db, job), "report": rlabel(rep.number)},
        )  # fmt: skip


def _approved(rep: Report) -> None:
    if rep.status not in DONE:
        raise Conflict(
            "report_not_approved",
            "A report can be sent only after a manager approves it.",
            {"status": rep.status},
        )


async def create_link(db: AsyncSession, p: Principal, report_id: uuid.UUID, channel: str) -> ShareLinkOut:
    """M35 "Copy link" (or a link for another channel): create, or renew for 30 more days."""
    p.require("reports.share")
    rep, job = await get_report(db, p, report_id, lock=True)
    _approved(rep)
    link = await _ensure_link(db, rep, channel, p.user.id)
    if channel == "copy":
        await _mark_shared(db, p, rep, job, ["copy"])
    await audit.record(
        db,
        "share_link.created",
        company_id=p.company_id,
        actor_id=p.user.id,
        actor_role=p.role,
        target_type="report",
        target_id=rep.id,
        data={"link": str(link.id), "channel": channel},
    )
    await db.flush()
    return link_out(link)


async def revoke_link(db: AsyncSession, p: Principal, link_id: uuid.UUID) -> None:
    p.require("reports.approve")
    link = (
        await db.execute(
            select(ShareLink)
            .where(ShareLink.id == link_id, ShareLink.company_id == p.company_id)
            .with_for_update()
        )
    ).scalar_one_or_none()
    if not link:
        raise NotFound("not_found", "This link was not found.")
    if not link.revoked_at:
        link.revoked_at, link.revoked_by = now(), p.user.id
        await audit.record(
            db,
            "share_link.revoked",
            company_id=p.company_id,
            actor_id=p.user.id,
            actor_role=p.role,
            target_type="report",
            target_id=link.report_id,
            data={"link": str(link.id)},
        )
    await db.flush()


async def _deliver(
    db: AsyncSession,
    rep: Report,
    link: ShareLink,
    channel: str,
    to: str,
    texts: Preview,
    user_id: uuid.UUID | None,
    template: str = "report_link",
) -> Message:
    msg = Message(
        company_id=rep.company_id,
        report_id=rep.id,
        share_link_id=link.id,
        channel=channel,
        to=to,
        template=template,
        language=rep.language,
        body=texts.email_body if channel == "email" else texts.sms,
        sent_by=user_id,
    )
    try:
        if channel == "sms":
            msg.provider_id = await messaging.send_sms_text(to, template, texts.sms)
        elif channel == "whatsapp":
            msg.provider_id = await messaging.send_whatsapp_text(to, template, texts.whatsapp)
        else:
            msg.provider_id = await messaging.send_email_text(
                to, template, texts.email_subject, texts.email_body
            )
        msg.status = "sent"
    except Exception as e:  # noqa: BLE001 - one channel failing must not stop the others
        msg.status, msg.error = "failed", f"{type(e).__name__}: {e}"[:300]
    db.add(msg)
    return msg


async def send(db: AsyncSession, p: Principal, report_id: uuid.UUID, body: SendIn) -> ShareInfo:
    """M35 Send: SMS, WhatsApp and/or email to the customer, each with the report link."""
    p.require("reports.share")
    rep, job = await get_report(db, p, report_id, lock=True)
    _approved(rep)
    contact = await _contact(db, job)
    company = await db.get(Company, rep.company_id)
    name = body.name or (contact.name if contact else None)
    phone = (
        normalize_phone(body.phone, company.country) if body.phone else (contact.phone if contact else None)
    )
    email = str(body.email) if body.email else (contact.email if contact else None)
    channels = list(dict.fromkeys(body.channels))
    if "email" in channels and not await email_on(db):
        raise AppError("email_off", "Email isn't switched on yet. Send by SMS or WhatsApp, or copy the link.")
    missing = {}
    if {"sms", "whatsapp"} & set(channels) and not phone:
        missing["phone"] = "missing"
    if "email" in channels and not email:
        missing["email"] = "missing"
    if missing:
        raise AppError(
            "contact_missing", "Add the customer's phone or email to send the report.", fields=missing
        )
    link = await _ensure_link(db, rep, channels[0], p.user.id, name, phone, email)
    texts = _texts(
        company.name, rep, job, link_url(link), name, link.expires_at.astimezone(), await messages.load(db)
    )
    msgs = [
        await _deliver(db, rep, link, ch, email if ch == "email" else phone, texts, p.user.id)
        for ch in channels
    ]
    ok = [m.channel for m in msgs if m.status == "sent"]
    if ok:
        await _mark_shared(db, p, rep, job, channels)
        from app.services import reviews

        await reviews.with_share(db, p, rep, job, contact, link, ok, body.ask_for_review)
    await audit.record(
        db,
        "report.sent",
        company_id=p.company_id,
        actor_id=p.user.id,
        actor_role=p.role,
        target_type="report",
        target_id=rep.id,
        data={"channels": channels, "failed": [m.channel for m in msgs if m.status == "failed"]},
    )
    await db.flush()
    return await share_info(db, p, rep.id)


# ---- customer report page (W27) ----------------------------------------------------------------------
async def _link(db: AsyncSession, token: str, *, allow_expired: bool = False) -> tuple[ShareLink, Report]:
    link_id = parse_token(token)
    link = await db.get(ShareLink, link_id, with_for_update=True) if link_id else None
    if not link or link.token_hash != token_hash(token):
        raise NotFound("not_found", "This report link is not valid.")
    rep = await db.get(Report, link.report_id)
    company = await db.get(Company, link.company_id)
    state = link_state(link)
    if state == "revoked":
        raise Gone("link_revoked", "This link was turned off by the company.", {"company": company.name})
    if state == "expired" and not allow_expired:
        raise Gone(
            "link_expired",
            "This link has expired. You can ask for a new one.",
            {
                "company": company.name,
                "expired_at": link.expires_at.isoformat(),
                "can_request_new_link": True,
            },
        )
    return link, rep


def _photo(e) -> PublicPhoto:
    s = get_storage()
    key = e.web_key or e.thumb_key  # never the original: it may carry GPS
    return PublicPhoto(
        id=e.id,
        stage=e.stage,
        url=s.presign_get(key),
        thumb_url=s.presign_get(e.thumb_key) if e.thumb_key else None,
        taken_at=e.taken_at,
    )


async def _review_state(db: AsyncSession, rep: Report):
    from app.services import reviews

    return await reviews.public_state(db, rep)


async def public_report(db: AsyncSession, token: str, lang: str | None) -> PublicReport:
    link, rep = await _link(db, token)
    t = now()
    link.first_opened_at = link.first_opened_at or t
    link.last_opened_at, link.open_count = t, link.open_count + 1
    lang = lang if lang in LANGS else rep.language
    v = await customer_view(db, rep, lang)
    s = get_storage()
    with_web = [e for e in v.photos if e.web_key or e.thumb_key]
    return PublicReport(
        number=v.number,
        job_number=v.job_number,
        title=v.title,
        customer=v.customer,
        address=v.address,
        technician=v.technician,
        approved_by=v.approved_by,
        approved_at=rep.approved_at,
        completed_at=v.job.completed_at,
        company=PublicCompany(
            name=v.company.name, logo_url=s.presign_get(v.company.logo_key) if v.company.logo_key else None
        ),
        language=rep.language,
        lang=lang,
        languages=LANGS,
        summary=rep.summary,
        work_done=v.lines,
        advice=v.advice_lines,
        pairs=[PublicPair(subject=sub, before=_photo(b), after=_photo(a)) for sub, b, a in v.pairs],
        photos=[_photo(e) for e in with_web],
        checklists=[
            PublicChecklist(
                name=c["name"],
                items=[
                    PublicItem(question=a["question"], answer=a["answer"], passed=a["passed"])
                    for a in c["items"]
                ],
            )
            for c in v.checklists
        ],
        photos_locked_at=rep.submitted_at,
        acknowledged=Acknowledgement(
            at=rep.acknowledged_at, name=rep.acknowledged_name, organisation=rep.acknowledged_org
        )
        if rep.acknowledged_at
        else None,
        link_expires_at=link.expires_at,
        pdf_ready=rep.pdf_status == "ready",
        fingerprint=rep.pdf_sha256,
        review=await _review_state(db, rep),
    )


async def public_pdf(db: AsyncSession, token: str) -> tuple[str | None, Report, bool]:
    """Signed link to the PDF, or (None, report, build_started) while it is being made."""
    _, rep = await _link(db, token)
    if rep.pdf_status == "ready" and rep.pdf_key:
        return get_storage().presign_get(rep.pdf_key, filename=f"{rlabel(rep.number)}.pdf"), rep, False
    return None, rep, needs_pdf(rep)


async def acknowledge(db: AsyncSession, token: str, name: str, org: str | None) -> Acknowledgement:
    _, rep = await _link(db, token)
    rep = await db.get(Report, rep.id, with_for_update=True)
    if not rep.acknowledged_at:  # pressing it twice keeps the first answer
        rep.acknowledged_at, rep.acknowledged_name, rep.acknowledged_org = now(), name, org
        rep.status = "acknowledged"
        job = await db.get(Job, rep.job_id)
        db.add(
            JobEvent(
                company_id=rep.company_id,
                job_id=job.id,
                type="report_acknowledged",
                from_status=job.status,
                to_status=job.status,
                data={"report": rlabel(rep.number), "name": name, "organisation": org},
            )
        )
        await audit.record(
            db,
            "report.acknowledged",
            company_id=rep.company_id,
            target_type="report",
            target_id=rep.id,
            data={"name": name, "organisation": org},
        )
        await db.flush()
    return Acknowledgement(
        at=rep.acknowledged_at, name=rep.acknowledged_name, organisation=rep.acknowledged_org
    )


async def _tell_team(db: AsyncSession, company_id: uuid.UUID, subject: str, body: str) -> None:
    emails = (
        await db.execute(
            select(User.email)
            .join(Membership, Membership.user_id == User.id)
            .where(
                Membership.company_id == company_id,
                Membership.status == "active",
                Membership.role.in_(("owner", "manager")),
                User.email.is_not(None),
            )
        )
    ).scalars()
    if not await email_on(db, "team"):
        return
    for e in emails:
        await messaging.send_email_text(e, "team_notice", subject, body)


async def request_new_link(db: AsyncSession, token: str) -> NewLinkOut:
    """ "Send me a new link" on an expired page. The new link goes to the person it was sent to before,
    never to whoever asks; a copied link (no recipient on file) tells the company instead."""
    link, rep = await _link(db, token, allow_expired=True)
    if link_state(link) == "active":
        raise Conflict("link_active", "This link still works.", {"expires_at": link.expires_at.isoformat()})
    t = now()
    if link.new_link_requested_at and t - link.new_link_requested_at < NEW_LINK_WAIT:
        after = link.new_link_requested_at + NEW_LINK_WAIT
        raise RateLimited(
            "rate_limited", "A new link was asked for a moment ago.", {"resend_after": after.isoformat()}
        )
    link.new_link_requested_at = t
    job = await db.get(Job, rep.job_id)
    company = await db.get(Company, rep.company_id)
    channel = (
        link.channel if link.channel != "copy" else ("sms" if link.phone else "email" if link.email else None)
    )
    to = link.email if channel == "email" else link.phone
    if channel and to:
        link.expires_at = t + timedelta(days=LINK_DAYS)
        texts = _texts(
            company.name, rep, job, link_url(link), link.recipient_name, link.expires_at.astimezone(),
            await messages.load(db),
        )  # fmt: skip
        await _deliver(db, rep, link, channel, to, texts, None, template="report_new_link")
        await db.flush()
        return NewLinkOut(sent_to=mask(to), channel=channel, company_notified=False)
    db.add(ReportIssue(company_id=rep.company_id, report_id=rep.id, share_link_id=link.id, kind="new_link"))
    await _tell_team(
        db,
        rep.company_id,
        label("en", "new_link_subject"),
        f"The customer of {job.title} ({rlabel(rep.number)}) opened an expired link and asked for a new one. "
        "Send it again from the report's Share screen.",
    )
    await db.flush()
    return NewLinkOut(sent_to=None, channel=None, company_notified=True)


async def report_issue(db: AsyncSession, token: str, message: str, contact: str | None) -> ReportIssue:
    link, rep = await _link(db, token, allow_expired=True)
    since = now() - timedelta(days=1)
    count = (
        await db.execute(
            select(func.count()).where(ReportIssue.share_link_id == link.id, ReportIssue.created_at > since)
        )
    ).scalar_one()
    if count >= ISSUES_PER_DAY:
        raise RateLimited(
            "rate_limited", "Thanks, we already have your messages. The company will contact you."
        )
    issue = ReportIssue(
        company_id=rep.company_id,
        report_id=rep.id,
        share_link_id=link.id,
        kind="problem",
        message=message,
        contact=contact,
    )
    db.add(issue)
    job = await db.get(Job, rep.job_id)
    await _tell_team(
        db,
        rep.company_id,
        label("en", "problem_subject", number=rlabel(rep.number)),
        f"About {job.title}:\n\n{message}\n\nContact: {contact or 'not given'}",
    )
    await db.flush()
    await db.refresh(issue)
    return issue
