"""No-login legal pages for the website: W06 Privacy policy, W07 Terms."""

from fastapi import APIRouter, Response

from app.schemas.identity import Locale
from app.schemas.legal import LegalDoc, LegalOut
from app.services import legal

router = APIRouter(prefix="/public", tags=["website"])


@router.get("/legal/{doc}", response_model=LegalOut)
async def legal_doc(doc: LegalDoc, response: Response, locale: Locale = "en") -> LegalOut:
    response.headers["Cache-Control"] = "public, max-age=300"
    return legal.get(doc, locale)
