"""Photo processing after upload: check it is a real image, record its size in pixels and a
fingerprint, and make two copies with EXIF and GPS removed: a 480 px thumbnail for lists and a
1,600 px web copy for the customer's report page.

The original file is never changed: it is the evidence.
"""

import io
import uuid

from PIL import Image, ImageOps, UnidentifiedImageError

from app.core.db import SessionLocal
from app.models import Evidence
from app.providers.storage import get_storage, sha256
from app.tasks import task

THUMB_PX = 480
WEB_PX = 1600
Image.MAX_IMAGE_PIXELS = 60_000_000  # refuse decompression bombs


def make_thumbnail(data: bytes, px: int = THUMB_PX, quality: int = 80) -> tuple[bytes, int, int]:
    with Image.open(io.BytesIO(data)) as img:
        img = ImageOps.exif_transpose(img)  # honour the phone's rotation
        width, height = img.size
        img = img.convert("RGB")
        img.thumbnail((px, px))
        out = io.BytesIO()
        img.save(out, "JPEG", quality=quality, optimize=True)  # saved without EXIF
        return out.getvalue(), width, height


async def ensure_web_copy(ev: Evidence, data: bytes | None = None) -> str | None:
    """Make the customer copy if it is missing (photos from before Step 1f). Allowed after lock."""
    if ev.web_key:
        return ev.web_key
    storage = get_storage()
    try:
        web, _, _ = make_thumbnail(data or await storage.read(ev.file_key), WEB_PX, 82)
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError):
        return None
    ev.web_key = ev.file_key.rsplit(".", 1)[0] + "_web.jpg"
    await storage.write(ev.web_key, web, "image/jpeg")
    return ev.web_key


@task
async def process_photo(ctx, evidence_id: str) -> str:
    storage = get_storage()
    async with SessionLocal() as db:
        ev = await db.get(Evidence, uuid.UUID(evidence_id))
        if not ev or ev.processing == "ready":
            return "skipped"
        data = await storage.read(ev.file_key)
        try:
            thumb, w, h = make_thumbnail(data)
        except (UnidentifiedImageError, OSError, Image.DecompressionBombError):
            ev.processing = "failed"
            await db.commit()
            return "failed"
        thumb_key = ev.file_key.rsplit(".", 1)[0] + "_thumb.jpg"
        await storage.write(thumb_key, thumb, "image/jpeg")
        ev.thumb_key, ev.width, ev.height, ev.processing = thumb_key, w, h, "ready"
        await ensure_web_copy(ev, data)
        if not ev.sha256:
            ev.sha256 = sha256(data)
        await db.commit()
        return "ready"
