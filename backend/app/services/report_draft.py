"""Turn a job's evidence into a report draft.

`collect()` gathers everything the report may use (and nothing else): photos with notes, before/after
pairs, checklist answers in the report language, voice and typed notes, manager answers.

With an OpenAI key the live `report_draft` prompt writes the text and links every sentence to its
evidence. Without one, `template_draft()` writes a plain draft from the answers and notes, so the flow
still works. Either way the server adds its own flags (failed checks) so they can't be missed.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    ChecklistAnswer,
    Customer,
    Evidence,
    EvidenceNote,
    Job,
    JobChecklist,
    ManagerQuestion,
    PhotoPair,
    Site,
    User,
    VoiceNote,
)
from app.providers.ai import LANGUAGE_NAMES
from app.services.checklists import pick
from app.services.voice import text_for_report

PHRASES = {
    "en": {
        "intro": "{title} for {customer}.",
        "checks": "{passed} of {total} checks passed.",
        "attention": "{failed} need attention.",
        "done": "{q}",
        "reading": "{q}: {v}",
        "fix": "Please get this fixed soon: {q}.",
        "photos": "{n} photos were taken before and after the work.",
    },
    "hi": {
        "intro": "{customer} के लिए {title}।",
        "checks": "{total} में से {passed} जांच ठीक रहीं।",
        "attention": "{failed} पर ध्यान देना है।",
        "done": "{q}",
        "reading": "{q}: {v}",
        "fix": "कृपया इसे जल्दी ठीक करवाएं: {q}।",
        "photos": "काम से पहले और बाद में {n} फोटो ली गईं।",
    },
    "gu": {
        "intro": "{customer} માટે {title}.",
        "checks": "{total} માંથી {passed} તપાસ બરાબર રહી.",
        "attention": "{failed} પર ધ્યાન આપવાનું છે.",
        "done": "{q}",
        "reading": "{q}: {v}",
        "fix": "કૃપા કરીને આ જલ્દી ઠીક કરાવો: {q}.",
        "photos": "કામ પહેલાં અને પછી {n} ફોટા લેવાયા.",
    },
    "es": {
        "intro": "{title} para {customer}.",
        "checks": "{passed} de {total} revisiones correctas.",
        "attention": "{failed} necesitan atención.",
        "done": "{q}",
        "reading": "{q}: {v}",
        "fix": "Conviene arreglar esto pronto: {q}.",
        "photos": "Se tomaron {n} fotos antes y después del trabajo.",
    },
    "fr": {
        "intro": "{title} pour {customer}.",
        "checks": "{passed} contrôles sur {total} conformes.",
        "attention": "{failed} demandent une attention.",
        "done": "{q}",
        "reading": "{q} : {v}",
        "fix": "À faire réparer rapidement : {q}.",
        "photos": "{n} photos prises avant et après l'intervention.",
    },
}


def _answer_text(q: dict, a: ChecklistAnswer, lang: str) -> str:
    v = a.value.get("v")
    if q["type"] == "choice":
        opt = next((o for o in q.get("options", []) if o["key"] == v), None)
        return pick(opt["label"], lang) if opt else str(v)
    if q["type"] == "number" and v is not None:
        num = int(v) if float(v).is_integer() else v
        return f"{num} {q.get('unit') or ''}".strip()
    return "" if v is None else str(v)


async def collect(db: AsyncSession, job: Job, lang: str) -> dict:
    customer = await db.get(Customer, job.customer_id)
    site = await db.get(Site, job.site_id) if job.site_id else None
    tech = await db.get(User, job.assigned_to) if job.assigned_to else None
    photos = list(
        (
            await db.execute(
                select(Evidence)
                .where(Evidence.job_id == job.id, Evidence.deleted_at.is_(None))
                .order_by(Evidence.taken_at)
            )
        ).scalars()
    )
    notes_by_photo: dict = {}
    if photos:
        for n in (
            await db.execute(select(EvidenceNote).where(EvidenceNote.evidence_id.in_([p.id for p in photos])))
        ).scalars():
            notes_by_photo.setdefault(n.evidence_id, []).append(n.text)
    pairs = list((await db.execute(select(PhotoPair).where(PhotoPair.job_id == job.id))).scalars())
    checklists = []
    passed = failed = 0
    for jc in (await db.execute(select(JobChecklist).where(JobChecklist.job_id == job.id))).scalars():
        answers = {
            str(a.question_id): a
            for a in (
                await db.execute(select(ChecklistAnswer).where(ChecklistAnswer.job_checklist_id == jc.id))
            ).scalars()
        }
        items = []
        for q in jc.questions:
            a = answers.get(q["id"])
            if not a:
                continue
            ok = None
            if q["type"] == "pass_fail":
                ok = a.value.get("v") == "pass"
                passed += ok
                failed += not ok
            items.append(
                {
                    "question_id": q["id"],
                    "question": pick(q["text"], lang),
                    "type": q["type"],
                    "answer": _answer_text(q, a, lang),
                    "passed": ok,
                    "photo_id": str(a.photo_id) if a.photo_id else None,
                }
            )
        checklists.append({"name": pick(jc.name, lang), "answers": items})
    notes = [
        {"id": str(v.id), "kind": v.kind, "text": text_for_report(v)}
        for v in (
            await db.execute(
                select(VoiceNote)
                .where(VoiceNote.job_id == job.id, VoiceNote.deleted_at.is_(None))
                .order_by(VoiceNote.recorded_at)
            )
        ).scalars()
        if text_for_report(v)
    ]
    manager = [
        {"question": m.text, "answer": m.answer}
        for m in (
            await db.execute(
                select(ManagerQuestion).where(
                    ManagerQuestion.job_id == job.id, ManagerQuestion.answer.is_not(None)
                )
            )
        ).scalars()
    ]
    return {
        "language": LANGUAGE_NAMES.get(lang, lang),
        "job": {
            "number": f"J-{job.number}",
            "title": job.title,
            "problem": job.description,
            "customer": customer.name,
            "address": ", ".join(filter(None, [site.address_line1, site.city])) if site else None,
            "technician": tech.name if tech else None,
            "started_at": job.started_at,
        },
        "photos": [
            {
                "id": str(p.id),
                "stage": p.stage,
                "taken_at": p.taken_at,
                "shot": p.shot_slot,
                "notes": notes_by_photo.get(p.id, []),
            }
            for p in photos
        ],
        "before_after_pairs": [
            {"before": str(x.before_id), "after": str(x.after_id), "subject": x.subject}
            for x in pairs
            if x.use_in_report
        ],
        "checklists": checklists,
        "notes": notes,
        "manager_answers": manager,
        "_counts": {
            "photos": {s: sum(p.stage == s for p in photos) for s in ("before", "during", "after")},
            "pairs": len(pairs),
            "checks_passed": passed,
            "checks_failed": failed,
            "notes": len(notes),
        },
    }


def server_flags(bundle: dict) -> list[dict]:
    flags = []
    for cl in bundle["checklists"]:
        for a in cl["answers"]:
            if a["passed"] is False:
                flags.append(
                    {"kind": "failed_check", "text": a["question"], "ref": f"answer:{a['question_id']}"}
                )
    return flags


def template_draft(bundle: dict, lang: str) -> dict:
    ph = PHRASES.get(lang, PHRASES["en"])
    c = bundle["_counts"]
    total = c["checks_passed"] + c["checks_failed"]
    summary = [ph["intro"].format(title=bundle["job"]["title"], customer=bundle["job"]["customer"])]
    if total:
        summary.append(ph["checks"].format(passed=c["checks_passed"], total=total))
    if c["checks_failed"]:
        summary.append(ph["attention"].format(failed=c["checks_failed"]))
    work, advice = [], []
    for cl in bundle["checklists"]:
        for a in cl["answers"]:
            if a["type"] in ("photo", "signature", "text"):
                continue
            if a["type"] == "number":
                work.append(ph["reading"].format(q=a["question"], v=a["answer"]))
            elif a["passed"] is True:
                work.append(ph["done"].format(q=a["question"]))
            elif a["passed"] is False:
                advice.append(ph["fix"].format(q=a["question"]))
    work.extend(n["text"] for n in bundle["notes"])
    shots = c["photos"]["before"] + c["photos"]["after"]
    if shots:
        work.append(ph["photos"].format(n=shots))
    return {"summary": " ".join(summary), "work_done": "\n".join(work), "advice": "\n".join(advice)}


def parse_ai(data: dict, bundle: dict) -> tuple[dict, list[dict], list[dict]]:
    """Check the AI's answer: right keys, only real evidence ids in links and flags."""
    known = {f"photo:{p['id']}" for p in bundle["photos"]} | {f"note:{n['id']}" for n in bundle["notes"]}
    known |= {f"answer:{a['question_id']}" for cl in bundle["checklists"] for a in cl["answers"]}
    work = data.get("work_done")
    if isinstance(work, list):
        work = "\n".join(str(x).strip() for x in work if str(x).strip())
    sections = {
        "summary": str(data.get("summary") or "").strip(),
        "work_done": str(work or "").strip(),
        "advice": "\n".join(data["advice"])
        if isinstance(data.get("advice"), list)
        else str(data.get("advice") or "").strip(),
    }
    if not sections["summary"] or not sections["work_done"]:
        raise ValueError("the AI draft is missing the summary or the work done")
    links = []
    for link in data.get("links") or []:
        if link.get("section") in sections and link.get("text"):
            links.append(
                {
                    "section": link["section"],
                    "text": str(link["text"]),
                    "refs": [r for r in link.get("refs") or [] if r in known],
                }
            )
    flags = []
    for f in data.get("flags") or []:
        if f.get("kind") in ("missing_evidence", "failed_check", "unsupported_claim") and f.get("text"):
            flags.append(
                {
                    "kind": f["kind"],
                    "text": str(f["text"])[:300],
                    "ref": f.get("ref") if f.get("ref") in known else None,
                }
            )
    # every sentence should point at evidence; ones that don't are flagged for the manager
    for link in links:
        if not link["refs"]:
            flags.append({"kind": "unsupported_claim", "text": link["text"][:300], "ref": None})
    return sections, links, flags


def merge_flags(*groups: list[dict]) -> list[dict]:
    seen, out = set(), []
    for g in groups:
        for f in g:
            key = (f["kind"], f.get("ref") or f["text"])
            if key not in seen:
                seen.add(key)
                out.append(f)
    return out
