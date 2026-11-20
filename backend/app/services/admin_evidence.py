"""A13 Evidence review: every company's photos, with checks the server runs on its own data (no AI):
the same file used twice, no GPS, taken far from the site, taken before the job existed. Staff can also
flag a photo for support with a note. Flags are only seen in the admin panel."""

import uuid
from datetime import timedelta

from sqlalchemy import and_, exists, func, literal, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.core.errors import NotFound
from app.core.security import now
from app.models import Company, Customer, Evidence, Job, Site, StaffUser, User
from app.providers.storage import get_storage
from app.schemas.admin_companies import AdminOption
from app.schemas.admin_evidence import (
    AdminPhoto,
    AdminPhotoDetail,
    AdminPhotoJob,
    AdminPhotoList,
    AdminPhotoTwin,
    AdminStaffFlag,
)  # fmt: skip
from app.services import audit
from app.services.admin_jobs import _distance_m
from app.services.jobs import label

FAR_M = 500
EARLY = timedelta(hours=1)  # phone clocks drift a little

_twin = aliased(Evidence)
DUP = and_(
    Evidence.sha256.is_not(None),
    exists().where(_twin.sha256 == Evidence.sha256, _twin.id != Evidence.id, _twin.deleted_at.is_(None)),
)
NO_GPS = Evidence.lat.is_(None)
# metres, flat-earth approximation: plenty for "is it 500 m away"
DIST = literal(111_320.0) * func.sqrt(
    func.power(Evidence.lat - Site.lat, 2)
    + func.power((Evidence.lng - Site.lng) * func.cos(func.radians(Site.lat)), 2)
)
FAR = and_(Evidence.lat.is_not(None), Site.lat.is_not(None), Site.lng.is_not(None), DIST > FAR_M)
EARLY_SQL = Evidence.taken_at < Job.created_at - EARLY
STAFF = Evidence.staff_flagged_at.is_not(None)
ANY = or_(DUP, NO_GPS, FAR, EARLY_SQL, STAFF)
CHECKS = {"duplicate": DUP, "no_gps": NO_GPS, "far": FAR, "early": EARLY_SQL}


def _base():
    return (
        select(
            Evidence, Job, Company.name, Customer.name, StaffUser.name,
            DUP.label("dup"), FAR.label("far"), EARLY_SQL.label("early"),
        )
        .join(Job, Job.id == Evidence.job_id)
        .join(Company, Company.id == Evidence.company_id)
        .join(Customer, Customer.id == Job.customer_id)
        .outerjoin(Site, Site.id == Job.site_id)
        .outerjoin(StaffUser, StaffUser.id == Evidence.staff_flagged_by)
        .where(Evidence.deleted_at.is_(None), Job.deleted_at.is_(None))
    )  # fmt: skip


def _filters(q: str | None, stage: str | None, flag: str | None, company_id, job_id) -> list:
    where: list = []
    if q:
        q = q.strip()
        like = f"%{q}%"
        conds = [Job.title.ilike(like), Customer.name.ilike(like), Company.name.ilike(like)]
        num = q.upper().removeprefix("#").removeprefix("J-")
        if num.isdigit():
            conds.append(Job.number == int(num))
        where.append(or_(*conds))
    if stage:
        where.append(Evidence.stage == stage)
    if flag == "needs_look":
        where.append(ANY)
    elif flag == "staff":
        where.append(STAFF)
    elif flag == "clean":
        where.append(~ANY)
    elif flag in CHECKS:
        where.append(CHECKS[flag])
    if company_id:
        where.append(Evidence.company_id == company_id)
    if job_id:
        where.append(Evidence.job_id == job_id)
    return where


def _photo(row, storage) -> dict:
    e, j, co, cust, flagger, dup, far, early = row
    checks = [
        c for c, on in (("duplicate", dup), ("no_gps", e.lat is None), ("far", far), ("early", early)) if on
    ]
    return dict(
        id=e.id, thumb_url=storage.presign_get(e.thumb_key) if e.thumb_key else None, stage=e.stage,
        job=AdminPhotoJob(id=j.id, number=label(j.number), title=j.title, customer=cust),
        company=AdminOption(value=str(e.company_id), label=co), taken_at=e.taken_at, gps=e.lat is not None,
        locked=e.locked_at is not None, checks=checks,
        staff_flag=AdminStaffFlag(note=e.staff_flag or "", by=flagger, at=e.staff_flagged_at)
        if e.staff_flagged_at else None,
    )  # fmt: skip


async def photos(
    db: AsyncSession, *, q: str | None, stage: str | None, flag: str | None, company_id: uuid.UUID | None,
    job_id: uuid.UUID | None, page: int, page_size: int, can_act: bool,
) -> AdminPhotoList:  # fmt: skip
    base = _base().where(*_filters(q, stage, flag, company_id, job_id))
    total = int(await db.scalar(select(func.count()).select_from(base.subquery())) or 0)
    # flagged photos first, then newest
    order = (STAFF.desc(), Evidence.taken_at.desc(), Evidence.id)
    rows = (await db.execute(base.order_by(*order).offset((page - 1) * page_size).limit(page_size))).all()
    needs = int(await db.scalar(select(func.count()).select_from(_base().where(ANY).subquery())) or 0)
    companies = (
        await db.execute(
            select(Company.id, Company.name)
            .where(Company.id.in_(select(Evidence.company_id).where(Evidence.deleted_at.is_(None))))
            .order_by(Company.name)
        )
    ).all()
    storage = get_storage()
    return AdminPhotoList(
        items=[AdminPhoto(**_photo(r, storage)) for r in rows], total=total, page=page, page_size=page_size,
        needs_look=needs, can_act=can_act,
        companies=[AdminOption(value=str(i), label=n) for i, n in companies],
    )  # fmt: skip


def _distance(e: Evidence, site: Site | None) -> int | None:
    if not site or None in (e.lat, e.lng, site.lat, site.lng):
        return None
    return _distance_m(site.lat, site.lng, e.lat, e.lng)


async def detail(db: AsyncSession, photo_id: uuid.UUID) -> AdminPhotoDetail:
    row = (await db.execute(_base().where(Evidence.id == photo_id))).first()
    if not row:
        raise NotFound("not_found", "Photo not found.")
    e, j = row[0], row[1]
    storage = get_storage()
    site = await db.get(Site, j.site_id) if j.site_id else None
    taker = await db.scalar(select(User.name).where(User.id == e.taken_by))
    twins = []
    if e.sha256:
        for t, tj, tco, tcust in (
            await db.execute(
                select(Evidence, Job, Company.name, Customer.name)
                .join(Job, Job.id == Evidence.job_id)
                .join(Company, Company.id == Evidence.company_id)
                .join(Customer, Customer.id == Job.customer_id)
                .where(Evidence.sha256 == e.sha256, Evidence.id != e.id, Evidence.deleted_at.is_(None))
                .order_by(Evidence.taken_at)
                .limit(20)
            )
        ).all():
            twins.append(AdminPhotoTwin(
                id=t.id, job=AdminPhotoJob(id=tj.id, number=label(tj.number), title=tj.title, customer=tcust),
                company=AdminOption(value=str(t.company_id), label=tco), taken_at=t.taken_at,
            ))  # fmt: skip
    return AdminPhotoDetail(
        **_photo(row, storage), image_url=storage.presign_get(e.web_key or e.file_key), taken_by=taker,
        distance_m=_distance(e, site), width=e.width, height=e.height, size=e.size, fingerprint=e.sha256,
        job_created_at=j.created_at, twins=twins,
    )  # fmt: skip


async def flag(
    db: AsyncSession, photo_id: uuid.UUID, note: str | None, *, staff_id: uuid.UUID, ip: str | None
) -> AdminPhotoDetail:
    """note=None clears the flag."""
    e = await db.get(Evidence, photo_id, with_for_update=True)
    if not e or e.deleted_at:
        raise NotFound("not_found", "Photo not found.")
    if note is None:
        if e.staff_flagged_at:
            await audit.record(db, "evidence.unflagged", staff_id=staff_id, target_type="evidence",
                               target_id=e.id, data={"note": e.staff_flag}, ip=ip)  # fmt: skip
        e.staff_flag = e.staff_flagged_by = e.staff_flagged_at = None
    else:
        e.staff_flag, e.staff_flagged_by, e.staff_flagged_at = note, staff_id, now()
        await audit.record(db, "evidence.flagged", staff_id=staff_id, target_type="evidence", target_id=e.id,
                           data={"note": note, "job_id": str(e.job_id)}, ip=ip)  # fmt: skip
    await db.flush()
    return await detail(db, photo_id)
