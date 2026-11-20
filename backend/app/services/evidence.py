"""Uploads and job evidence (API document: Evidence, checklists and voice; Files).

Flow: POST /uploads -> app PUTs the file to the signed URL -> POST /jobs/{id}/evidence confirms it.
Photos can be added while the job is In progress (or sent back with Changes requested). They lock when
the report is submitted (`lock_job_evidence`); after that only notes can be added.
"""

import uuid
from datetime import datetime, timedelta

from sqlalchemy import func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal
from app.core.errors import AppError, Conflict, Forbidden, NotFound
from app.core.security import now
from app.models import Evidence, EvidenceNote, Job, PhotoPair, Upload, User
from app.providers.storage import get_storage
from app.schemas.evidence import (
    EvidenceCreate,
    EvidenceDetail,
    EvidenceList,
    EvidenceOut,
    NoteIn,
    NoteOut,
    PairIn,
    PairOut,
    Proof,
    ProofReport,
    ProofStep,
    ShotPrompt,
    UploadCreate,
    UploadOut,
)
from app.schemas.identity import ListMeta
from app.schemas.work import PersonRef, ProofCount
from app.services import audit, platform
from app.services.jobs import get_job

MB = 1024 * 1024
# kind -> (allowed types and file endings, max size). Photos are compressed on the phone to 2,560 px.
UPLOAD_RULES: dict[str, tuple[dict[str, str], int]] = {
    "photo": ({"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}, 12 * MB),
    "audio": (
        {
            "audio/mp4": "m4a",
            "audio/m4a": "m4a",
            "audio/aac": "aac",
            "audio/mpeg": "mp3",
            "audio/wav": "wav",
            "audio/webm": "webm",
            "audio/ogg": "ogg",
        },
        25 * MB,
    ),  # fmt: skip
    "logo": ({"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp", "image/svg+xml": "svg"}, 2 * MB),
    "avatar": ({"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}, 5 * MB),
    "signature": ({"image/png": "png", "image/jpeg": "jpg"}, 1 * MB),
}
UPLOAD_TTL = timedelta(hours=1)
CAPTURE_STATUSES = ("in_progress", "changes_requested")


# ---- uploads ---------------------------------------------------------------------------------
async def create_upload(db: AsyncSession, p: Principal, body: UploadCreate) -> UploadOut:
    types, max_bytes = UPLOAD_RULES[body.kind]
    if body.kind == "photo":
        max_bytes = (await platform.config(db)).max_photo_mb * MB  # A32 "Max photo size"
    ct = body.content_type.lower().split(";")[0].strip()
    if ct not in types:
        raise AppError(
            "file_type_not_allowed", "This kind of file can't be uploaded here.",
            {"allowed": sorted(types)}, fields={"content_type": "not_allowed"},
        )  # fmt: skip
    if body.size and body.size > max_bytes:
        raise AppError(
            "file_too_large", "This file is too big.", {"max_bytes": max_bytes}, fields={"size": "too_large"}
        )
    uid = uuid.uuid4()
    t = now()
    owner = str(p.company.id) if p.company else f"users/{p.user.id}"
    key = f"{owner}/{body.kind}/{t:%Y/%m}/{uid}.{types[ct]}"
    db.add(
        Upload(
            id=uid,
            company_id=p.company.id if p.company else None,
            user_id=p.user.id,
            kind=body.kind,
            content_type=ct,
            key=key,
            max_bytes=max_bytes,
            expires_at=t + UPLOAD_TTL,
        )  # fmt: skip
    )
    signed = await get_storage().presign_put(key, ct, max_bytes)
    return UploadOut(
        upload_id=uid, url=signed.url, method="PUT", headers=signed.headers, max_bytes=max_bytes,
        expires_at=t + UPLOAD_TTL,
    )  # fmt: skip


async def take_upload(db: AsyncSession, p: Principal, upload_id: uuid.UUID, kind: str) -> tuple[Upload, int]:
    """Check an upload belongs to this person, is unused, and the file really arrived within the limit."""
    return await take_upload_for(db, p.user.id, upload_id, kind)


async def take_upload_for(
    db: AsyncSession, user_id: uuid.UUID, upload_id: uuid.UUID, kind: str
) -> tuple[Upload, int]:
    up = await db.get(Upload, upload_id, with_for_update=True)
    if not up or up.user_id != user_id or up.kind != kind:
        raise NotFound("upload_not_found", "Upload not found.")
    if up.used_at:
        raise Conflict("upload_used", "This upload was already used.")
    if up.expires_at < now():
        raise AppError("upload_expired", "This upload has expired. Please upload the file again.")
    obj = await get_storage().head(up.key)
    if not obj:
        raise AppError("upload_missing", "The file hasn't finished uploading.")
    if obj.size > up.max_bytes:
        await get_storage().delete(up.key)
        raise AppError("file_too_large", "This file is too big.", {"max_bytes": up.max_bytes})
    up.used_at = now()
    return up, obj.size


# ---- shapes -----------------------------------------------------------------------------------
async def _out(db: AsyncSession, rows: list[Evidence]) -> list[EvidenceOut]:
    if not rows:
        return []
    storage = get_storage()
    ids = [e.id for e in rows]
    users = {
        u.id: u
        for u in (await db.execute(select(User).where(User.id.in_({e.taken_by for e in rows})))).scalars()
    }
    notes = dict(
        (
            await db.execute(
                select(EvidenceNote.evidence_id, func.count())
                .where(EvidenceNote.evidence_id.in_(ids))
                .group_by(EvidenceNote.evidence_id)
            )
        ).all()
    )
    return [
        EvidenceOut(
            id=e.id,
            job_id=e.job_id,
            stage=e.stage,
            shot_slot=e.shot_slot,
            url=storage.presign_get(e.file_key),
            thumb_url=storage.presign_get(e.thumb_key) if e.thumb_key else None,
            width=e.width,
            height=e.height,
            size=e.size,
            processing=e.processing,
            taken_at=e.taken_at,
            taken_by=PersonRef(id=e.taken_by, name=users[e.taken_by].name or ""),
            lat=e.lat,
            lng=e.lng,
            locked=e.locked_at is not None,
            locked_at=e.locked_at,
            notes_count=notes.get(e.id, 0),
        )  # fmt: skip
        for e in rows
    ]


def _can_delete(p: Principal, e: Evidence) -> bool:
    return e.locked_at is None and (e.taken_by == p.user.id or "jobs.view_all" in p.permissions)


# ---- photos -----------------------------------------------------------------------------------
async def add_evidence(
    db: AsyncSession, p: Principal, job_id: uuid.UUID, body: EvidenceCreate
) -> tuple[Evidence, bool]:
    p.require("evidence.capture")
    j = await get_job(db, p, job_id, lock=True)
    if body.client_uuid:
        existing = (
            await db.execute(
                select(Evidence).where(
                    Evidence.company_id == p.company_id, Evidence.client_uuid == body.client_uuid
                )
            )
        ).scalar_one_or_none()
        if existing:
            return existing, False
    if j.status not in CAPTURE_STATUSES:
        if j.status in ("in_review", "completed"):
            raise Conflict(
                "evidence_locked", "The report was sent, so photos are locked. You can still add a note."
            )
        raise Conflict("job_not_started", "Start the job before adding photos.", {"status": j.status})
    if body.taken_at > now() + timedelta(minutes=10):
        raise AppError("validation_error", "The photo time is in the future.", fields={"taken_at": "future"})
    up, size = await take_upload(db, p, body.upload_id, "photo")
    e = Evidence(
        company_id=p.company_id, job_id=j.id, client_uuid=body.client_uuid, stage=body.stage,
        shot_slot=body.shot_slot, file_key=up.key, content_type=up.content_type, size=size,
        taken_at=body.taken_at, taken_by=p.user.id, lat=body.lat, lng=body.lng,
    )  # fmt: skip
    db.add(e)
    await db.flush()
    return e, True


def _visible_evidence(p: Principal):
    q = (
        select(Evidence)
        .join(Job, Job.id == Evidence.job_id)
        .where(Evidence.company_id == p.company_id, Evidence.deleted_at.is_(None), Job.deleted_at.is_(None))
    )
    if "jobs.view_all" not in p.permissions:
        q = q.where(Job.assigned_to == p.user.id)
    return q


async def get_evidence(db: AsyncSession, p: Principal, evidence_id: uuid.UUID) -> Evidence:
    e = (await db.execute(_visible_evidence(p).where(Evidence.id == evidence_id))).scalar_one_or_none()
    if not e:
        raise NotFound("evidence_not_found", "Photo not found.")
    return e


async def evidence_detail(db: AsyncSession, p: Principal, e: Evidence) -> EvidenceDetail:
    base = (await _out(db, [e]))[0]
    rows = (
        await db.execute(
            select(EvidenceNote, User.name)
            .join(User, User.id == EvidenceNote.author_id)
            .where(EvidenceNote.evidence_id == e.id)
            .order_by(EvidenceNote.created_at)
        )
    ).all()
    notes = [
        NoteOut(
            id=n.id, author=PersonRef(id=n.author_id, name=name or ""), text=n.text, created_at=n.created_at
        )
        for n, name in rows
    ]
    return EvidenceDetail(**base.model_dump(), notes=notes, can_delete=_can_delete(p, e))


async def list_evidence(db: AsyncSession, p: Principal, job_id: uuid.UUID, stage: str | None) -> EvidenceList:
    j = await get_job(db, p, job_id)
    rows = (
        (
            await db.execute(
                select(Evidence)
                .where(Evidence.job_id == j.id, Evidence.deleted_at.is_(None))
                .order_by(Evidence.taken_at, Evidence.created_at)
            )
        )
        .scalars()
        .all()
    )
    counts = {"before": 0, "during": 0, "after": 0}
    for e in rows:
        counts[e.stage] += 1
    counts["all"] = len(rows)
    shown = [e for e in rows if not stage or e.stage == stage]
    by_id = {o.id: o for o in await _out(db, list(rows))}
    pairs = (
        (await db.execute(select(PhotoPair).where(PhotoPair.job_id == j.id).order_by(PhotoPair.created_at)))
        .scalars()
        .all()
    )
    return EvidenceList(
        data=[by_id[e.id] for e in shown],
        meta=ListMeta(counts=counts),
        pairs=[
            PairOut(
                id=x.id,
                before=by_id[x.before_id],
                after=by_id[x.after_id],
                subject=x.subject,
                use_in_report=x.use_in_report,
            )  # fmt: skip
            for x in pairs
            if x.before_id in by_id and x.after_id in by_id
        ],
    )


async def delete_evidence(db: AsyncSession, p: Principal, evidence_id: uuid.UUID) -> None:
    e = await get_evidence(db, p, evidence_id)
    if e.locked_at:
        raise Conflict("evidence_locked", "This photo is locked because the report was sent.")
    if not _can_delete(p, e):
        raise Forbidden("forbidden", "Only the person who took this photo or a manager can remove it.")
    e.deleted_at = now()
    await db.execute(
        PhotoPair.__table__.delete().where((PhotoPair.before_id == e.id) | (PhotoPair.after_id == e.id))
    )
    await audit.record(
        db, "evidence.deleted", company_id=p.company_id, actor_id=p.user.id, actor_role=p.role,
        target_type="evidence", target_id=e.id, data={"job_id": str(e.job_id), "stage": e.stage},
    )  # fmt: skip


async def add_note(db: AsyncSession, p: Principal, evidence_id: uuid.UUID, body: NoteIn) -> EvidenceNote:
    e = await get_evidence(db, p, evidence_id)  # allowed after lock
    n = EvidenceNote(company_id=p.company_id, evidence_id=e.id, author_id=p.user.id, text=body.text)
    db.add(n)
    await db.flush()
    return n


# ---- before/after pairs ------------------------------------------------------------------------
async def create_pair(db: AsyncSession, p: Principal, job_id: uuid.UUID, body: PairIn) -> PhotoPair:
    p.require("evidence.capture")
    j = await get_job(db, p, job_id)
    found = {
        e.id: e
        for e in (
            await db.execute(
                select(Evidence).where(
                    Evidence.id.in_([body.before_id, body.after_id]),
                    Evidence.job_id == j.id,
                    Evidence.deleted_at.is_(None),
                )
            )
        ).scalars()
    }
    before, after = found.get(body.before_id), found.get(body.after_id)
    if not before or before.stage != "before":
        raise AppError(
            "validation_error", "Pick a Before photo from this job.", fields={"before_id": "not_before"}
        )
    if not after or after.stage != "after":
        raise AppError(
            "validation_error", "Pick an After photo from this job.", fields={"after_id": "not_after"}
        )
    if before.locked_at:
        raise Conflict("evidence_locked", "Photos are locked because the report was sent.")
    pair = PhotoPair(
        company_id=p.company_id, job_id=j.id, before_id=before.id, after_id=after.id, subject=body.subject,
        use_in_report=body.use_in_report, created_by=p.user.id,
    )  # fmt: skip
    db.add(pair)
    await db.flush()
    return pair


async def pair_out(db: AsyncSession, pair: PhotoPair) -> PairOut:
    rows = (
        (await db.execute(select(Evidence).where(Evidence.id.in_([pair.before_id, pair.after_id]))))
        .scalars()
        .all()
    )
    by_id = {o.id: o for o in await _out(db, list(rows))}
    return PairOut(
        id=pair.id, before=by_id[pair.before_id], after=by_id[pair.after_id], subject=pair.subject,
        use_in_report=pair.use_in_report,
    )  # fmt: skip


async def delete_pair(db: AsyncSession, p: Principal, pair_id: uuid.UUID) -> None:
    pair = (
        await db.execute(
            select(PhotoPair).where(PhotoPair.id == pair_id, PhotoPair.company_id == p.company_id)
        )
    ).scalar_one_or_none()
    if not pair:
        raise NotFound("pair_not_found", "Pair not found.")
    await get_job(db, p, pair.job_id)  # visibility
    before = await db.get(Evidence, pair.before_id)
    if before and before.locked_at:
        raise Conflict("evidence_locked", "Photos are locked because the report was sent.")
    await db.delete(pair)


# ---- capture hub (M19) and lock ------------------------------------------------------------------
async def proof(db: AsyncSession, p: Principal, job_id: uuid.UUID) -> Proof:
    j = await get_job(db, p, job_id)
    rows = (
        (
            await db.execute(
                select(Evidence)
                .where(Evidence.job_id == j.id, Evidence.deleted_at.is_(None))
                .order_by(Evidence.taken_at.desc())
            )
        )
        .scalars()
        .all()
    )
    storage = get_storage()

    def step(stage: str, required: bool) -> ProofStep:
        mine = [e for e in rows if e.stage == stage]
        return ProofStep(
            key=stage, count=len(mine), required=required, done=bool(mine),
            thumbs=[storage.presign_get(e.thumb_key) for e in mine if e.thumb_key][:3],
        )  # fmt: skip

    from app.services.checklists import checklist_progress, pick, shot_prompts
    from app.services.voice import count_for_job

    steps = [step("before", True), step("during", False), step("after", True)]
    done_lists, all_lists = await checklist_progress(db, j.id)
    notes = await count_for_job(db, j.id)
    steps += [
        # a job with checklists needs them finished before the report
        ProofStep(
            key="checklist",
            count=done_lists,
            total=all_lists,
            required=all_lists > 0,
            done=all_lists > 0 and done_lists == all_lists,
        ),  # fmt: skip
        ProofStep(key="voice", count=notes, required=False, done=notes > 0),
    ]
    lang = p.user.app_language or "en"
    taken = {e.shot_slot for e in rows if e.shot_slot}
    prompts = [
        ShotPrompt(stage=stage, key=key, prompt=pick(text, lang), done=key in taken)
        for stage, key, text in await shot_prompts(db, j.id)
    ]
    locked = any(e.locked_at for e in rows)
    blocked = None
    # after "ask for changes" old photos stay locked, but new proof can be added and the report redone
    if j.status in ("in_review", "completed"):
        blocked = "evidence_locked"
    elif j.status not in CAPTURE_STATUSES:
        blocked = "job_not_started"
    elif not steps[0].done:
        blocked = "need_before_photo"
    elif not steps[2].done:
        blocked = "need_after_photo"
    elif steps[3].required and not steps[3].done:
        blocked = "need_checklist"
    return Proof(
        job_id=j.id,
        status=j.status,
        steps=steps,
        shot_prompts=prompts,
        can_make_report=blocked is None,
        blocked_by=blocked,
        locked=locked,
        report=await _report_ref(db, j.id),
    )


async def _report_ref(db: AsyncSession, job_id: uuid.UUID) -> ProofReport | None:
    from app.models import Report
    from app.services.reports import rlabel

    rep = (await db.execute(select(Report).where(Report.job_id == job_id))).scalar_one_or_none()
    return ProofReport(id=rep.id, number=rlabel(rep.number), status=rep.status) if rep else None


async def lock_job_evidence(db: AsyncSession, job_id: uuid.UUID) -> int:
    """Called when the report is submitted (Step 1e). Locks the job's photos, checklist answers and
    voice notes together. Returns how many photos were locked."""
    from app.services.checklists import lock_answers
    from app.services.voice import lock_notes

    r = await db.execute(
        update(Evidence)
        .where(Evidence.job_id == job_id, Evidence.locked_at.is_(None), Evidence.deleted_at.is_(None))
        .values(locked_at=now())
    )
    await lock_answers(db, job_id)
    await lock_notes(db, job_id)
    return r.rowcount or 0


async def thumbs_for(db: AsyncSession, job_ids: list[uuid.UUID], each: int = 3) -> dict[uuid.UUID, list[str]]:
    """The newest few photo thumbnails of each job (M30 review queue)."""
    if not job_ids:
        return {}
    rows = (
        await db.execute(
            select(Evidence.job_id, Evidence.thumb_key)
            .where(
                Evidence.job_id.in_(job_ids), Evidence.deleted_at.is_(None), Evidence.thumb_key.is_not(None)
            )
            .order_by(Evidence.job_id, Evidence.taken_at.desc())
        )
    ).all()
    storage = get_storage()
    out: dict[uuid.UUID, list[str]] = {}
    for job_id, key in rows:
        got = out.setdefault(job_id, [])
        if len(got) < each:
            got.append(storage.presign_get(key))
    return out


async def covers(db: AsyncSession, jobs: list[Job]) -> dict[uuid.UUID, str]:
    """A picture for each job card: its latest photo, else the latest photo of the same site."""
    if not jobs:
        return {}
    job_ids = [j.id for j in jobs]
    site_ids = [j.site_id for j in jobs if j.site_id]
    where = Evidence.job_id.in_(job_ids)
    if site_ids:
        where = or_(where, Job.site_id.in_(site_ids))
    rows = (
        await db.execute(
            select(Evidence.job_id, Job.site_id, Evidence.thumb_key)
            .join(Job, Job.id == Evidence.job_id)
            .where(
                Evidence.company_id == jobs[0].company_id,
                Evidence.deleted_at.is_(None),
                Evidence.thumb_key.is_not(None),
                where,
            )
            .order_by(Evidence.taken_at.desc())
            .limit(500)
        )
    ).all()
    by_job: dict = {}
    by_site: dict = {}
    for job_id, site_id, key in rows:
        by_job.setdefault(job_id, key)
        if site_id:
            by_site.setdefault(site_id, key)
    storage = get_storage()
    out = {}
    for j in jobs:
        key = by_job.get(j.id) or by_site.get(j.site_id)
        if key:
            out[j.id] = storage.presign_get(key)
    return out


async def photo_counts(db: AsyncSession, job_ids: list[uuid.UUID]) -> dict[uuid.UUID, int]:
    if not job_ids:
        return {}
    rows = await db.execute(
        select(Evidence.job_id, func.count())
        .where(Evidence.job_id.in_(job_ids), Evidence.deleted_at.is_(None))
        .group_by(Evidence.job_id)
    )
    return dict(rows.all())


async def proof_progress(db: AsyncSession, job: Job) -> ProofCount:
    """The same steps as GET /jobs/{id}/proof, counted: before, during, after, checklists (if any), voice."""
    from app.services.checklists import checklist_progress
    from app.services.voice import count_for_job

    stages = set(
        (
            await db.execute(
                select(Evidence.stage)
                .where(Evidence.job_id == job.id, Evidence.deleted_at.is_(None))
                .distinct()
            )
        ).scalars()
    )
    done_lists, all_lists = await checklist_progress(db, job.id)
    notes = await count_for_job(db, job.id)
    steps = [s in stages for s in ("before", "during", "after")]
    if all_lists:
        steps.append(done_lists == all_lists)
    steps.append(notes > 0)
    return ProofCount(done=sum(steps), total=len(steps))


async def photos_by(
    db: AsyncSession, company_id: uuid.UUID, user_id: uuid.UUID, since: datetime | None = None
) -> int:
    q = select(func.count()).where(
        Evidence.company_id == company_id, Evidence.taken_by == user_id, Evidence.deleted_at.is_(None)
    )
    if since:
        q = q.where(Evidence.taken_at >= since)
    return (await db.execute(q)).scalar_one()
