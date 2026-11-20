"""Report drafting in the background (M31 "making your report").

Steps shown on GET /tasks/{id}: collect evidence -> write report -> check against evidence.
Safe to run twice. AI errors end in generation_failed (evidence is safe; retry allowed).
"""

import uuid

from sqlalchemy import select

from app.core.db import SessionLocal
from app.core.security import now
from app.models import BackgroundTask, Job, PromptVersion, Report, ReportVersion
from app.providers.ai import LANGUAGE_NAMES, get_ai
from app.services import ai_usage
from app.services.report_draft import collect, merge_flags, parse_ai, server_flags, template_draft
from app.tasks import task

STEPS = ("collect_evidence", "write_report", "check_evidence")
SECTIONS = ("summary", "work_done", "advice")


def _steps(done: int, running: int | None = None, failed: int | None = None) -> list[dict]:
    out = []
    for i, key in enumerate(STEPS):
        status = "done" if i < done else "running" if i == running else "failed" if i == failed else "waiting"
        out.append({"key": key, "status": status})
    return out


async def _live_prompt(db, task_name: str) -> PromptVersion | None:
    return (
        await db.execute(
            select(PromptVersion).where(PromptVersion.task == task_name, PromptVersion.live.is_(True))
        )
    ).scalar_one_or_none()


@task
async def draft_report(ctx, report_id: str, task_id: str, section: str | None = None) -> str:
    """Write the whole report, or only `section` when regenerating one part."""
    async with SessionLocal() as db:
        rep = await db.get(Report, uuid.UUID(report_id))
        bt = await db.get(BackgroundTask, uuid.UUID(task_id))
        if not rep or not bt or bt.status in ("done", "failed"):
            return "skipped"
        job = await db.get(Job, rep.job_id)
        bt.status, bt.steps = "running", _steps(0, running=0)
        await db.commit()

        step = 0
        asked_ai, company_id = False, rep.company_id
        try:
            bundle = await collect(db, job, rep.language)
            step = 1
            bt.steps = _steps(1, running=1)
            await db.commit()

            ai = get_ai()
            links, ai_flags = [], []
            if ai:
                prompt = await _live_prompt(db, "report_draft")
                system = prompt.system_prompt.format(language=LANGUAGE_NAMES.get(rep.language, rep.language))
                evidence = {k: v for k, v in bundle.items() if not k.startswith("_")}
                asked_ai = True
                draft = await ai.draft_report(system, evidence)
                asked_ai = False
                sections, links, ai_flags = parse_ai(draft.data, bundle)
                cost = ai_usage.record(
                    db, "report_draft", company_id=rep.company_id, model=draft.model,
                    tokens_in=draft.tokens_in, tokens_out=draft.tokens_out, related_id=rep.id,
                )  # fmt: skip
                rep.ai_tokens += draft.tokens_in + draft.tokens_out
                rep.ai_cost_usd += cost
                rep.ai_prompt_version = prompt.version
                source = "ai"
            else:
                sections = template_draft(bundle, rep.language)
                source = "template"

            step = 2
            bt.steps = _steps(2, running=2)
            await db.commit()

            keys = (section,) if section else SECTIONS
            for k in keys:
                setattr(rep, k, sections[k] or None)
                rep.section_sources = {**rep.section_sources, k: source}
            if section:
                rep.evidence_links = {
                    **rep.evidence_links,
                    section: [x for x in links if x["section"] == section],
                }
            else:
                rep.evidence_links = {k: [x for x in links if x["section"] == k] for k in SECTIONS}
                rep.flags = merge_flags(server_flags(bundle), ai_flags)
                rep.drafted_by = source
                c = bundle["_counts"]
                rep.source_counts = c
                rep.checks_passed, rep.checks_failed = c["checks_passed"], c["checks_failed"]
            rep.version += 1
            db.add(
                ReportVersion(
                    report_id=rep.id,
                    version=rep.version,
                    source=source,
                    event="regenerated" if section else "drafted",
                    sections={k: getattr(rep, k) for k in SECTIONS},
                )
            )
            if rep.status == "generating":
                # a report sent back by the manager stays marked that way until it is sent again
                rep.status = "changes_requested" if job.status == "changes_requested" else "draft"
            rep.error = None
            bt.status, bt.steps, bt.finished_at = "done", _steps(3), now()
            await db.commit()
            return "done"
        except Exception as e:  # noqa: BLE001 - evidence is untouched; the person can retry
            await db.rollback()
            if asked_ai:
                await ai_usage.record_failure(
                    "report_draft", company_id=company_id, related_id=uuid.UUID(report_id)
                )
            rep = await db.get(Report, uuid.UUID(report_id))
            bt = await db.get(BackgroundTask, uuid.UUID(task_id))
            if rep.status == "generating":
                rep.status = "generation_failed"
            rep.error = f"{type(e).__name__}: {e}"[:300]
            bt.status, bt.steps, bt.error, bt.finished_at = (
                "failed",
                _steps(step, failed=step),
                rep.error,
                now(),
            )
            await db.commit()
            return "failed"


@task
async def build_report_pdf(ctx, report_id: str) -> str:
    """Build the customer PDF after approval (M34). Safe to run twice; failures can be retried."""
    from app.models import Evidence
    from app.providers.storage import get_storage, sha256
    from app.services.report_pdf import build_pdf
    from app.services.report_view import customer_view
    from app.tasks.photos import ensure_web_copy

    storage = get_storage()
    async with SessionLocal() as db:
        rep = await db.get(Report, uuid.UUID(report_id))
        if not rep or rep.status not in ("approved", "shared", "acknowledged") or rep.pdf_status == "ready":
            return "skipped"
        rep.pdf_status, rep.pdf_error = "building", None
        await db.commit()
        try:
            view = await customer_view(db, rep)
            images = {}
            for e in view.photos:
                if e.thumb_key:
                    images[e.id] = await storage.read(e.thumb_key)
            # make the customer copies of older photos now, so the report page is ready when opened
            for e in (await db.execute(select(Evidence).where(Evidence.job_id == rep.job_id))).scalars():
                await ensure_web_copy(e)
            logo = await storage.read(view.company.logo_key) if view.company.logo_key else None
            data, pages = build_pdf(view, rep.language, images, logo)
            key = f"{rep.company_id}/reports/{rep.id}/R-{rep.number}.pdf"
            await storage.write(key, data, "application/pdf")
            rep.pdf_key, rep.pdf_pages, rep.pdf_size, rep.pdf_sha256 = key, pages, len(data), sha256(data)
            rep.pdf_status, rep.pdf_built_at = "ready", now()
            await db.commit()
            return "ready"
        except Exception as e:  # noqa: BLE001 - the report stays approved; the PDF can be rebuilt
            await db.rollback()
            rep = await db.get(Report, uuid.UUID(report_id))
            rep.pdf_status, rep.pdf_error = "failed", f"{type(e).__name__}: {e}"[:300]
            await db.commit()
            return "failed"
