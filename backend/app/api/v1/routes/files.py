"""Local file storage only (KN_STORAGE_PROVIDER=local): stands in for R2's signed upload and
download links on your computer and in tests. Never mounted when files live in R2."""

from fastapi import APIRouter, Request, Response

from app.core.errors import AppError
from app.core.security import read_link_token
from app.providers.storage import LocalStorage, get_storage

router = APIRouter(prefix="/files", tags=["files (local only)"])


@router.put("/upload/{token}", status_code=200)
async def upload(token: str, request: Request) -> dict:
    claims = read_link_token(token, "file_put")
    content_type, max_bytes = claims["fp"].split("|")
    if request.headers.get("content-type", "").split(";")[0].strip().lower() != content_type:
        raise AppError("file_type_not_allowed", "Send the file with the Content-Type from POST /uploads.")
    data = bytearray()
    async for chunk in request.stream():
        data.extend(chunk)
        if len(data) > int(max_bytes):
            raise AppError(
                "file_too_large", "This file is too big.", {"max_bytes": int(max_bytes)}, status=413
            )
    await get_storage().write(claims["sub"], bytes(data), content_type)
    return {"ok": True, "size": len(data)}


@router.get("/{token}")
async def download(token: str) -> Response:
    claims = read_link_token(token, "file_get")
    storage = get_storage()
    assert isinstance(storage, LocalStorage)
    obj = await storage.head(claims["sub"])
    if not obj:
        raise AppError("not_found", "File not found.", status=404)
    return Response(
        await storage.read(claims["sub"]),
        media_type=obj.content_type or "application/octet-stream",
        headers={"Cache-Control": "private, max-age=600"},
    )
