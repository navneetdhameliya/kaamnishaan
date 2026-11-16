import uuid

from fastapi import APIRouter, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.routes.jobs import member
from app.core.deps import Principal, get_db
from app.schemas.checklists import (
    AnswerIn,
    AttachChecklist,
    JobChecklistItem,
    JobChecklistList,
    ManagerAnswerIn,
    ManagerQuestionIn,
    ManagerQuestionList,
    ManagerQuestionOut,
    QuestionIn,
    QuestionPatch,
    SubmissionOut,
    TemplateCreate,
    TemplateList,
    TemplateOut,
    TemplatePatch,
)
from app.schemas.identity import Locale
from app.services import checklists as svc
from app.services.jobs import get_job
from app.tasks import enqueue

router = APIRouter()


# ---- templates (M26) ------------------------------------------------------------------------
@router.get("/checklist-templates", response_model=TemplateList, tags=["checklists"])
async def list_templates(
    trade: str | None = None,
    lang: Locale | None = None,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> TemplateList:
    return await svc.list_templates(db, p, trade, lang)


@router.post("/checklist-templates", response_model=TemplateOut, status_code=201, tags=["checklists"])
async def create_template(
    body: TemplateCreate, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> TemplateOut:
    return await svc.template_out(db, p, await svc.create_template(db, p, body), body.language)


@router.get("/checklist-templates/{template_id}", response_model=TemplateOut, tags=["checklists"])
async def get_template(
    template_id: uuid.UUID,
    lang: Locale | None = None,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> TemplateOut:
    p.require("checklists.manage")
    return await svc.template_out(db, p, await svc.get_template(db, p, template_id), lang)


@router.patch("/checklist-templates/{template_id}", response_model=TemplateOut, tags=["checklists"])
async def patch_template(
    template_id: uuid.UUID,
    body: TemplatePatch,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> TemplateOut:
    return await svc.template_out(db, p, await svc.update_template(db, p, template_id, body), None)


@router.post(
    "/checklist-templates/{template_id}/copy",
    response_model=TemplateOut,
    status_code=201,
    tags=["checklists"],
)
async def copy_template(
    template_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> TemplateOut:
    """Copy a KaamNishaan (or own) checklist so the company can change it."""
    return await svc.template_out(db, p, await svc.copy_template(db, p, template_id), None)


@router.post(
    "/checklist-templates/{template_id}/questions",
    response_model=TemplateOut,
    status_code=201,
    tags=["checklists"],
)
async def add_question(
    template_id: uuid.UUID,
    body: QuestionIn,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> TemplateOut:
    q = await svc.add_question(db, p, template_id, body)
    await db.commit()
    await enqueue("translate_checklist_question", question_id=str(q.id))
    return await svc.template_out(db, p, await svc.get_template(db, p, template_id), None)


@router.patch(
    "/checklist-templates/{template_id}/questions/{question_id}",
    response_model=TemplateOut,
    tags=["checklists"],
)
async def patch_question(
    template_id: uuid.UUID,
    question_id: uuid.UUID,
    body: QuestionPatch,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> TemplateOut:
    q, words_changed = await svc.update_question(db, p, template_id, question_id, body)
    await db.commit()
    if words_changed:
        await enqueue("translate_checklist_question", question_id=str(q.id))
    return await svc.template_out(db, p, await svc.get_template(db, p, template_id), None)


@router.delete(
    "/checklist-templates/{template_id}/questions/{question_id}", status_code=204, tags=["checklists"]
)
async def delete_question(
    template_id: uuid.UUID,
    question_id: uuid.UUID,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> Response:
    await svc.delete_question(db, p, template_id, question_id)
    return Response(status_code=204)


# ---- job checklists (M24, M25) ------------------------------------------------------------------
@router.get("/jobs/{job_id}/checklists", response_model=JobChecklistList, tags=["checklists"])
async def job_checklists(
    job_id: uuid.UUID,
    lang: Locale | None = None,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> JobChecklistList:
    return await svc.list_for_job(db, p, job_id, lang)


@router.post(
    "/jobs/{job_id}/checklists", response_model=JobChecklistItem, status_code=201, tags=["checklists"]
)
async def attach_checklist(
    job_id: uuid.UUID,
    body: AttachChecklist,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> JobChecklistItem:
    job = await get_job(db, p, job_id, lock=True)
    jc = await svc.attach(db, p, job, body.template_id)
    lst = await svc.list_for_job(db, p, job_id, None)
    return next(i for i in lst.data if i.id == jc.id)


@router.delete("/jobs/{job_id}/checklists/{checklist_id}", status_code=204, tags=["checklists"])
async def detach_checklist(
    job_id: uuid.UUID,
    checklist_id: uuid.UUID,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> Response:
    await svc.detach(db, p, job_id, checklist_id)
    return Response(status_code=204)


@router.get("/checklist-submissions/{checklist_id}", response_model=SubmissionOut, tags=["checklists"])
async def get_submission(
    checklist_id: uuid.UUID,
    lang: Locale | None = None,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> SubmissionOut:
    """Questions in the job's language (or ?lang=), with reference photos, rules, answers and progress."""
    return await svc.submission(db, p, checklist_id, lang)


@router.put(
    "/checklist-submissions/{checklist_id}/answers/{question_id}",
    response_model=SubmissionOut,
    tags=["checklists"],
)
async def put_answer(
    checklist_id: uuid.UUID,
    question_id: uuid.UUID,
    body: AnswerIn,
    lang: Locale | None = None,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> SubmissionOut:
    await svc.answer(db, p, checklist_id, question_id, body)
    return await svc.submission(db, p, checklist_id, lang)


# ---- "Not sure? Ask your manager" -------------------------------------------------------------------
@router.post(
    "/jobs/{job_id}/manager-questions",
    response_model=ManagerQuestionOut,
    status_code=201,
    tags=["checklists"],
)
async def ask_manager(
    job_id: uuid.UUID,
    body: ManagerQuestionIn,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> ManagerQuestionOut:
    return await svc.ask_manager(db, p, job_id, body)


@router.get("/jobs/{job_id}/manager-questions", response_model=ManagerQuestionList, tags=["checklists"])
async def manager_questions(
    job_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> ManagerQuestionList:
    return await svc.list_manager_questions(db, p, job_id)


@router.post(
    "/manager-questions/{question_id}/answer", response_model=ManagerQuestionOut, tags=["checklists"]
)
async def answer_manager_question(
    question_id: uuid.UUID,
    body: ManagerAnswerIn,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> ManagerQuestionOut:
    return await svc.answer_manager_question(db, p, question_id, body.answer)
