"""Testimonials (A27): quotes staff add for the website's Home. A quote is shown only when the customer
agreed in writing and staff switched it on."""

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, NotFound
from app.models import Testimonial
from app.schemas.testimonials import (
    AdminTestimonial,
    AdminTestimonials,
    PublicTestimonial,
    PublicTestimonials,
    TestimonialIn,
)
from app.services import audit, media

MAX_QUOTE = 300


def _out(x: Testimonial) -> AdminTestimonial:
    return AdminTestimonial(
        id=x.id,
        quote=x.quote,
        person_name=x.person_name,
        role=x.role,
        company_name=x.company_name,
        city=x.city,
        photo=x.photo,
        photo_url=media.url(x.photo),
        approved_in_writing=x.approved_in_writing,
        approval_note=x.approval_note,
        on_website=x.on_website,
        updated_at=x.updated_at,
    )


async def admin_list(db: AsyncSession, *, can_act: bool) -> AdminTestimonials:
    rows = (await db.execute(select(Testimonial).order_by(Testimonial.created_at))).scalars()
    return AdminTestimonials(items=[_out(x) for x in rows], can_act=can_act)


def _apply(x: Testimonial, body: TestimonialIn) -> None:
    quote = {k: v.strip() for k, v in body.quote.items() if v and v.strip()}
    if not quote.get("en"):
        raise AppError("validation_error", "English is needed.", fields={"quote.en": "required"})
    if any(len(v) > MAX_QUOTE for v in quote.values()):
        raise AppError(
            "validation_error",
            "At most {limit} characters.",
            fields={"quote": "too_long"},
            params={"limit": MAX_QUOTE},
        )
    if body.photo and not media.is_key(body.photo):
        raise AppError("validation_error", "Upload the photo first.", fields={"photo": "picture"})
    if body.on_website and not body.approved_in_writing:
        raise AppError(
            "not_approved",
            "Only quotes the customer approved in writing can go on the website.",
            fields={"on_website": "not_approved"},
        )
    x.quote = quote
    x.person_name, x.role, x.company_name = body.person_name, body.role, body.company_name
    x.city, x.photo = body.city or None, body.photo or None
    x.approved_in_writing, x.approval_note = body.approved_in_writing, body.approval_note or None
    x.on_website = body.on_website


async def create(db: AsyncSession, body: TestimonialIn, *, staff_id, ip) -> AdminTestimonials:
    x = Testimonial(created_by=staff_id)
    _apply(x, body)
    db.add(x)
    await db.flush()
    await audit.record(
        db,
        "testimonial.created",
        staff_id=staff_id,
        target_type="testimonial",
        target_id=x.id,
        data={"name": x.person_name, "on_website": x.on_website},
        ip=ip,
    )
    return await admin_list(db, can_act=True)


async def update(db: AsyncSession, tid: uuid.UUID, body: TestimonialIn, *, staff_id, ip) -> AdminTestimonials:
    x = await db.get(Testimonial, tid)
    if not x:
        raise NotFound("not_found", "Testimonial not found.")
    was = x.on_website
    _apply(x, body)
    action = (
        "testimonial.updated"
        if was == x.on_website
        else ("testimonial.shown" if x.on_website else "testimonial.hidden")
    )
    await audit.record(
        db,
        action,
        staff_id=staff_id,
        target_type="testimonial",
        target_id=x.id,
        data={"name": x.person_name},
        ip=ip,
    )
    await db.flush()
    return await admin_list(db, can_act=True)


async def delete(db: AsyncSession, tid: uuid.UUID, *, staff_id, ip) -> AdminTestimonials:
    x = await db.get(Testimonial, tid)
    if not x:
        raise NotFound("not_found", "Testimonial not found.")
    await audit.record(
        db,
        "testimonial.deleted",
        staff_id=staff_id,
        target_type="testimonial",
        target_id=x.id,
        data={"name": x.person_name},
        ip=ip,
    )
    await db.delete(x)
    await db.flush()
    return await admin_list(db, can_act=True)


async def public(db: AsyncSession, lang: str) -> PublicTestimonials:
    rows = (
        await db.execute(
            select(Testimonial)
            .where(Testimonial.on_website.is_(True), Testimonial.approved_in_writing.is_(True))
            .order_by(Testimonial.created_at)
        )
    ).scalars()
    out = []
    for x in rows:
        used = lang if x.quote.get(lang) else "en"
        out.append(
            PublicTestimonial(
                id=x.id,
                quote=x.quote[used],
                language=used,  # type: ignore[arg-type]
                name=x.person_name,
                role=x.role,
                company=x.company_name,
                city=x.city,
                photo_url=media.url(x.photo),
            )
        )
    return PublicTestimonials(items=out)
