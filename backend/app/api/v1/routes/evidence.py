import uuid
from typing import Literal

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.routes.jobs import member
from app.core.deps import Principal, get_db, get_principal
from app.schemas.evidence import (
    EvidenceCreate,
    EvidenceDetail,
    EvidenceList,
    NoteIn,
    NoteOut,
    PairIn,
    PairOut,
    Proof,
    UploadCreate,
    UploadOut,
)
from app.schemas.work import PersonRef
from app.services import evidence as svc
from app.tasks import enqueue

router = APIRouter()


@router.post("/uploads", response_model=UploadOut, status_code=status.HTTP_201_CREATED, tags=["files"])
async def create_upload(
    body: UploadCreate, p: Principal = Depends(get_principal), db: AsyncSession = Depends(get_db)
) -> UploadOut:
    """Step 1 of 3: get a signed URL. Step 2: PUT the file there with the given headers.
    Step 3: confirm with the call for what the file is (e.g. POST /jobs/{id}/evidence)."""
    return await svc.create_upload(db, p, body)


@router.get("/jobs/{job_id}/proof", response_model=Proof, tags=["evidence"])
async def proof(
    job_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> Proof:
    return await svc.proof(db, p, job_id)


@router.get("/jobs/{job_id}/evidence", response_model=EvidenceList, tags=["evidence"])
async def list_evidence(
    job_id: uuid.UUID,
    stage: Literal["before", "during", "after"] | None = None,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> EvidenceList:
    return await svc.list_evidence(db, p, job_id, stage)


@router.post("/jobs/{job_id}/evidence", response_model=EvidenceDetail, status_code=201, tags=["evidence"])
async def add_evidence(
    job_id: uuid.UUID,
    body: EvidenceCreate,
    response: Response,
    p: Principal = Depends(member),
    db: AsyncSession = Depends(get_db),
) -> EvidenceDetail:
    e, created = await svc.add_evidence(db, p, job_id, body)
    if created:
        await db.commit()  # the worker must see the row
        await enqueue("process_photo", evidence_id=str(e.id))
        await db.refresh(e)
    else:
        response.status_code = status.HTTP_200_OK
    return await svc.evidence_detail(db, p, e)


@router.get("/evidence/{evidence_id}", response_model=EvidenceDetail, tags=["evidence"])
async def get_evidence(
    evidence_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> EvidenceDetail:
    return await svc.evidence_detail(db, p, await svc.get_evidence(db, p, evidence_id))


@router.delete("/evidence/{evidence_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["evidence"])
async def delete_evidence(
    evidence_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> Response:
    await svc.delete_evidence(db, p, evidence_id)
    return Response(status_code=204)


@router.post("/evidence/{evidence_id}/notes", response_model=NoteOut, status_code=201, tags=["evidence"])
async def add_note(
    evidence_id: uuid.UUID, body: NoteIn, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> NoteOut:
    n = await svc.add_note(db, p, evidence_id, body)
    return NoteOut(
        id=n.id, author=PersonRef(id=p.user.id, name=p.user.name or ""), text=n.text, created_at=n.created_at
    )


@router.post("/jobs/{job_id}/photo-pairs", response_model=PairOut, status_code=201, tags=["evidence"])
async def create_pair(
    job_id: uuid.UUID, body: PairIn, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> PairOut:
    return await svc.pair_out(db, await svc.create_pair(db, p, job_id, body))


@router.delete("/photo-pairs/{pair_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["evidence"])
async def delete_pair(
    pair_id: uuid.UUID, p: Principal = Depends(member), db: AsyncSession = Depends(get_db)
) -> Response:
    await svc.delete_pair(db, p, pair_id)
    return Response(status_code=204)
