"""What the customer sees: the same content feeds the PDF (M34) and the report page (W27).

Only an approved report is shown. Photos are given as their EXIF-free copies (no GPS), never the
original file. Checklist questions follow the requested language; the report text stays in the
language it was written and approved in.
"""

from dataclasses import dataclass, field
from datetime import datetime
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Company, Customer, Evidence, Job, PhotoPair, Report, Site, User
from app.services.report_draft import collect
from app.services.report_labels import label


@dataclass
class CustomerView:
    company: Company
    report: Report
    job: Job
    number: str
    job_number: str
    title: str
    customer: str
    address: str | None
    technician: str | None
    approved_by: str | None
    tz: ZoneInfo
    photos: list[Evidence] = field(default_factory=list)
    pairs: list[tuple[str | None, Evidence, Evidence]] = field(default_factory=list)
    checklists: list[dict] = field(default_factory=list)

    def local(self, t: datetime | None) -> datetime | None:
        return t.astimezone(self.tz) if t else None

    @property
    def lines(self) -> list[str]:
        return [x.strip(" -•") for x in (self.report.work_done or "").splitlines() if x.strip(" -•")]

    @property
    def advice_lines(self) -> list[str]:
        return [x.strip(" -•") for x in (self.report.advice or "").splitlines() if x.strip(" -•")]


async def customer_view(db: AsyncSession, rep: Report, lang: str | None = None) -> CustomerView:
    job = await db.get(Job, rep.job_id)
    company = await db.get(Company, rep.company_id)
    customer = await db.get(Customer, job.customer_id)
    site = await db.get(Site, job.site_id) if job.site_id else None
    tech = await db.get(User, job.assigned_to) if job.assigned_to else None
    approver = await db.get(User, rep.approved_by) if rep.approved_by else None
    photos = list(
        (
            await db.execute(
                select(Evidence)
                .where(
                    Evidence.job_id == job.id, Evidence.deleted_at.is_(None), Evidence.processing == "ready"
                )
                .order_by(Evidence.taken_at)
            )
        ).scalars()
    )
    by_id = {e.id: e for e in photos}
    pairs = [
        (x.subject, by_id[x.before_id], by_id[x.after_id])
        for x in (await db.execute(select(PhotoPair).where(PhotoPair.job_id == job.id))).scalars()
        if x.use_in_report and x.before_id in by_id and x.after_id in by_id
    ]
    lang = lang or rep.language
    bundle = await collect(db, job, lang)
    for cl in bundle["checklists"]:
        for a in cl["answers"]:
            if a["type"] == "yes_no" and a["answer"] in ("yes", "no"):
                a["answer"] = label(lang, a["answer"])
    checklists = [
        {"name": cl["name"], "items": [a for a in cl["answers"] if a["type"] not in ("photo", "signature")]}
        for cl in bundle["checklists"]
    ]
    address = ", ".join(filter(None, [site.address_line1, site.address_line2, site.city])) if site else None
    try:
        tz = ZoneInfo(company.timezone)
    except (KeyError, ValueError):
        tz = ZoneInfo("Asia/Kolkata")
    return CustomerView(
        company=company,
        report=rep,
        job=job,
        number=f"R-{rep.number}",
        job_number=f"J-{job.number}",
        title=job.title,
        customer=customer.name,
        address=address,
        technician=tech.name if tech else None,
        approved_by=approver.name if approver else None,
        tz=tz,
        photos=photos,
        pairs=pairs,
        checklists=[c for c in checklists if c["items"]],
    )
