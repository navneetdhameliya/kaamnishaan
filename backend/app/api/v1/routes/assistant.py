"""M36 Ask KaamNishaan AI (owners and managers)."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, get_db
from app.schemas.assistant import AskIn, AskOut, AssistantOut
from app.services import assistant

from .jobs import member, with_feature

router = APIRouter(tags=["assistant"])
WITH_ASSISTANT = with_feature("ai_assistant")  # D-147: Professional and up


@router.get("/assistant", response_model=AssistantOut)
async def chat(p: Principal = Depends(member), db: AsyncSession = Depends(get_db)) -> AssistantOut:
    """My recent questions and answers, and how many of this month's questions are used."""
    return await assistant.state(db, p)


@router.post("/assistant/ask", response_model=AskOut)
async def ask(
    body: AskIn,
    p: Principal = Depends(WITH_ASSISTANT),
    db: AsyncSession = Depends(get_db),
) -> AskOut:
    """Ask about the company's jobs. 402 ai_limit_reached when this month's questions are used up."""
    return await assistant.ask(db, p, body.text)
