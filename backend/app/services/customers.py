"""Customers with their contacts, sites and equipment (M16 search, M18 details, M35 contact fix).

Owners and managers manage customers. A technician can read a customer only through a job assigned
to them, and can name a brand-new customer when making a quick job.
"""

import uuid

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal
from app.core.errors import AppError, NotFound
from app.core.paging import check_version, decode_cursor, next_cursor
from app.core.security import normalize_phone, now
from app.models import Customer, CustomerContact, Equipment, Job, Site
from app.schemas.identity import ListMeta
from app.schemas.work import (
    ContactBrief,
    ContactIn,
    ContactOut,
    ContactPatch,
    CustomerCreate,
    CustomerList,
    CustomerListItem,
    CustomerOut,
    CustomerPatch,
    EquipmentIn,
    EquipmentOut,
    EquipmentPatch,
    SiteBrief,
    SiteIn,
    SiteOut,
    SitePatch,
)
from app.services import audit


# ---- shapes ---------------------------------------------------------------------------------
def contact_out(c: CustomerContact) -> ContactOut:
    return ContactOut(
        id=c.id, name=c.name, title=c.title, phone=c.phone, email=c.email, is_primary=c.is_primary,
        review_opted_out=c.review_opt_out_at is not None,
    )  # fmt: skip


def equipment_out(e: Equipment) -> EquipmentOut:
    return EquipmentOut(
        id=e.id, type=e.type, brand=e.brand, model=e.model, capacity=e.capacity, location=e.location,
        last_service_at=e.last_service_at,
    )  # fmt: skip


def site_out(s: Site, equipment: list[Equipment] | None = None) -> SiteOut:
    return SiteOut(
        id=s.id, label=s.label, address_line1=s.address_line1, address_line2=s.address_line2, city=s.city,
        state=s.state, postcode=s.postcode, country=s.country, lat=s.lat, lng=s.lng,
        equipment=[equipment_out(e) for e in equipment or []],
    )  # fmt: skip


def _phone(p: Principal, raw: str | None) -> str | None:
    return normalize_phone(raw, p.company.country) if raw else None


# ---- reading ------------------------------------------------------------------------------
async def get_customer(db: AsyncSession, company_id: uuid.UUID, customer_id: uuid.UUID) -> Customer:
    c = (
        await db.execute(
            select(Customer).where(
                Customer.id == customer_id, Customer.company_id == company_id, Customer.deleted_at.is_(None)
            )
        )
    ).scalar_one_or_none()
    if not c:
        raise NotFound("customer_not_found", "Customer not found.")
    return c


async def can_read(db: AsyncSession, p: Principal, customer_id: uuid.UUID) -> None:
    if "customers.manage" in p.permissions:
        return
    has_job = (
        await db.execute(
            select(Job.id).where(
                Job.company_id == p.company_id,
                Job.customer_id == customer_id,
                Job.assigned_to == p.user.id,
                Job.deleted_at.is_(None),
            )
        )
    ).first()
    if not has_job:
        raise NotFound("customer_not_found", "Customer not found.")


async def customer_detail(db: AsyncSession, c: Customer) -> CustomerOut:
    contacts = (
        (
            await db.execute(
                select(CustomerContact)
                .where(CustomerContact.customer_id == c.id, CustomerContact.deleted_at.is_(None))
                .order_by(CustomerContact.is_primary.desc(), CustomerContact.created_at)
            )
        )
        .scalars()
        .all()
    )
    sites = (
        (
            await db.execute(
                select(Site)
                .where(Site.customer_id == c.id, Site.deleted_at.is_(None))
                .order_by(Site.created_at)
            )
        )
        .scalars()
        .all()
    )
    equipment = (
        (
            await db.execute(
                select(Equipment)
                .where(
                    Equipment.site_id.in_([s.id for s in sites] or [uuid.uuid4()]),
                    Equipment.deleted_at.is_(None),
                )
                .order_by(Equipment.created_at)
            )
        )
        .scalars()
        .all()
    )
    job_count = (
        await db.execute(select(func.count()).where(Job.customer_id == c.id, Job.deleted_at.is_(None)))
    ).scalar_one()
    return CustomerOut(
        id=c.id, name=c.name, notes=c.notes, customer_since=c.created_at, job_count=job_count,
        contacts=[contact_out(x) for x in contacts],
        sites=[site_out(s, [e for e in equipment if e.site_id == s.id]) for s in sites],
        version=c.version, updated_at=c.updated_at,
    )  # fmt: skip


async def list_customers(
    db: AsyncSession, p: Principal, q: str | None, cursor: str | None, limit: int
) -> CustomerList:
    offset = decode_cursor(cursor)
    base = select(Customer).where(Customer.company_id == p.company_id, Customer.deleted_at.is_(None))
    if q:
        like = f"%{q.strip()}%"
        digits = "".join(ch for ch in q if ch.isdigit())
        match = [CustomerContact.name.ilike(like)]
        if len(digits) >= 4:
            match.append(CustomerContact.phone.like(f"%{digits}%"))
        by_contact = select(CustomerContact.customer_id).where(
            CustomerContact.company_id == p.company_id, CustomerContact.deleted_at.is_(None), or_(*match)
        )
        base = base.where(or_(Customer.name.ilike(like), Customer.id.in_(by_contact)))
    total = (await db.execute(select(func.count()).select_from(base.subquery()))).scalar_one()
    rows = (
        (
            await db.execute(
                base.order_by(func.lower(Customer.name), Customer.id).offset(offset).limit(limit + 1)
            )
        )
        .scalars()
        .all()
    )
    page = list(rows[:limit])
    ids = [c.id for c in page] or [uuid.uuid4()]

    contacts: dict = {}
    for x in (
        await db.execute(
            select(CustomerContact)
            .where(CustomerContact.customer_id.in_(ids), CustomerContact.deleted_at.is_(None))
            .order_by(CustomerContact.is_primary.desc(), CustomerContact.created_at)
        )
    ).scalars():
        contacts.setdefault(x.customer_id, x)
    sites: dict = {}
    for s in (
        await db.execute(
            select(Site).where(Site.customer_id.in_(ids), Site.deleted_at.is_(None)).order_by(Site.created_at)
        )
    ).scalars():
        sites.setdefault(s.customer_id, s)
    jobs = {
        cid: (n, last)
        for cid, n, last in (
            await db.execute(
                select(Job.customer_id, func.count(), func.max(Job.scheduled_at))
                .where(Job.customer_id.in_(ids), Job.deleted_at.is_(None))
                .group_by(Job.customer_id)
            )
        ).all()
    }
    items = []
    for c in page:
        pc = contacts.get(c.id)
        n, last = jobs.get(c.id, (0, None))
        items.append(
            CustomerListItem(
                id=c.id,
                name=c.name,
                primary_contact=ContactBrief(name=pc.name, phone=pc.phone) if pc else None,
                city=sites[c.id].city if c.id in sites else None,
                site=_site_brief(sites.get(c.id)),
                job_count=n,
                last_job_at=last,
            )  # fmt: skip
        )
    return CustomerList(
        data=items, meta=ListMeta(counts={"all": total}, next_cursor=next_cursor(offset, limit, len(rows)))
    )


def _site_brief(s: Site | None) -> SiteBrief | None:
    if s is None:
        return None
    return SiteBrief(
        id=s.id, label=s.label, city=s.city, lat=s.lat, lng=s.lng,
        address=", ".join(filter(None, [s.address_line1, s.address_line2])),
    )  # fmt: skip


# ---- writing ------------------------------------------------------------------------------
def _new_site(p: Principal, customer_id: uuid.UUID, body: SiteIn) -> Site:
    data = body.model_dump()
    data["country"] = data.get("country") or p.company.country
    return Site(company_id=p.company_id, customer_id=customer_id, **data)


async def _new_contact(
    db: AsyncSession, p: Principal, customer_id: uuid.UUID, body: ContactIn
) -> CustomerContact:
    if body.is_primary:
        await _clear_primary(db, customer_id)
    data = body.model_dump()
    data["phone"] = _phone(p, body.phone)
    data["email"] = str(body.email).lower() if body.email else None
    return CustomerContact(company_id=p.company_id, customer_id=customer_id, **data)


async def _clear_primary(db: AsyncSession, customer_id: uuid.UUID) -> None:
    for c in (
        await db.execute(
            select(CustomerContact).where(
                CustomerContact.customer_id == customer_id, CustomerContact.is_primary
            )
        )
    ).scalars():
        c.is_primary = False


async def create_customer(db: AsyncSession, p: Principal, body: CustomerCreate) -> tuple[Customer, bool]:
    """Returns (customer, created). A repeated client_uuid returns the first result."""
    if body.client_uuid:
        existing = (
            await db.execute(
                select(Customer).where(
                    Customer.company_id == p.company_id, Customer.client_uuid == body.client_uuid
                )
            )
        ).scalar_one_or_none()
        if existing:
            return existing, False
    c = Customer(
        company_id=p.company_id,
        name=body.name,
        notes=body.notes,
        created_by=p.user.id,
        client_uuid=body.client_uuid,
    )
    db.add(c)
    await db.flush()
    if body.site:
        db.add(_new_site(p, c.id, body.site))
    if body.contact:
        contact = await _new_contact(db, p, c.id, body.contact)
        contact.is_primary = True  # the first contact is the main one
        db.add(contact)
    await audit.record(
        db, "customer.created", company_id=p.company_id, actor_id=p.user.id, actor_role=p.role,
        target_type="customer", target_id=c.id, data={"name": c.name},
    )  # fmt: skip
    await db.flush()
    return c, True


async def update_customer(
    db: AsyncSession, p: Principal, customer_id: uuid.UUID, body: CustomerPatch, if_match: str | None
) -> Customer:
    c = await get_customer(db, p.company_id, customer_id)
    check_version(if_match, c.version, await customer_detail(db, c))
    changes = body.model_dump(exclude_unset=True)
    if "name" in changes and not changes["name"]:
        raise AppError("validation_error", "Name is required.", fields={"name": "required"})
    before = {k: getattr(c, k) for k in changes}
    for k, v in changes.items():
        setattr(c, k, v)
    if changes:
        c.version += 1
        await audit.record(
            db, "customer.updated", company_id=p.company_id, actor_id=p.user.id, actor_role=p.role,
            target_type="customer", target_id=c.id, data={"before": before, "after": changes},
        )  # fmt: skip
    await db.flush()
    return c


async def _touch(c: Customer) -> None:
    c.version += 1
    c.updated_at = now()


async def add_contact(
    db: AsyncSession, p: Principal, customer_id: uuid.UUID, body: ContactIn
) -> CustomerContact:
    c = await get_customer(db, p.company_id, customer_id)
    has_any = (
        await db.execute(
            select(CustomerContact.id).where(
                CustomerContact.customer_id == c.id, CustomerContact.deleted_at.is_(None)
            )
        )
    ).first()
    contact = await _new_contact(db, p, c.id, body)
    if not has_any:
        contact.is_primary = True
    db.add(contact)
    await _touch(c)
    await db.flush()
    return contact


async def _contact(
    db: AsyncSession, p: Principal, customer_id: uuid.UUID, contact_id: uuid.UUID
) -> CustomerContact:
    x = (
        await db.execute(
            select(CustomerContact).where(
                CustomerContact.id == contact_id,
                CustomerContact.customer_id == customer_id,
                CustomerContact.company_id == p.company_id,
                CustomerContact.deleted_at.is_(None),
            )
        )
    ).scalar_one_or_none()
    if not x:
        raise NotFound("contact_not_found", "Contact not found.")
    return x


async def update_contact(
    db: AsyncSession, p: Principal, customer_id: uuid.UUID, contact_id: uuid.UUID, body: ContactPatch
) -> CustomerContact:
    c = await get_customer(db, p.company_id, customer_id)
    x = await _contact(db, p, customer_id, contact_id)
    changes = body.model_dump(exclude_unset=True)
    if changes.get("is_primary"):
        await _clear_primary(db, customer_id)
    if "phone" in changes:
        changes["phone"] = _phone(p, changes["phone"])
    if changes.get("email"):
        changes["email"] = str(changes["email"]).lower()
    for k, v in changes.items():
        setattr(x, k, v)
    await _touch(c)
    await db.flush()
    return x


async def delete_contact(
    db: AsyncSession, p: Principal, customer_id: uuid.UUID, contact_id: uuid.UUID
) -> None:
    c = await get_customer(db, p.company_id, customer_id)
    x = await _contact(db, p, customer_id, contact_id)
    x.deleted_at, x.is_primary = now(), False
    await _touch(c)


async def add_site(db: AsyncSession, p: Principal, customer_id: uuid.UUID, body: SiteIn) -> Site:
    c = await get_customer(db, p.company_id, customer_id)
    s = _new_site(p, c.id, body)
    db.add(s)
    await _touch(c)
    await db.flush()
    return s


async def get_site(db: AsyncSession, company_id: uuid.UUID, site_id: uuid.UUID, customer_id=None) -> Site:
    q = select(Site).where(Site.id == site_id, Site.company_id == company_id, Site.deleted_at.is_(None))
    if customer_id:
        q = q.where(Site.customer_id == customer_id)
    s = (await db.execute(q)).scalar_one_or_none()
    if not s:
        raise NotFound("site_not_found", "Address not found.")
    return s


async def update_site(
    db: AsyncSession, p: Principal, customer_id: uuid.UUID, site_id: uuid.UUID, body: SitePatch
) -> Site:
    c = await get_customer(db, p.company_id, customer_id)
    s = await get_site(db, p.company_id, site_id, customer_id)
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(s, k, v)
    await _touch(c)
    await db.flush()
    return s


async def add_equipment(
    db: AsyncSession, p: Principal, customer_id: uuid.UUID, site_id: uuid.UUID, body: EquipmentIn
) -> Equipment:
    c = await get_customer(db, p.company_id, customer_id)
    s = await get_site(db, p.company_id, site_id, customer_id)
    e = Equipment(company_id=p.company_id, site_id=s.id, **body.model_dump())
    db.add(e)
    await _touch(c)
    await db.flush()
    return e


async def update_equipment(
    db: AsyncSession, p: Principal, customer_id: uuid.UUID, site_id: uuid.UUID, equipment_id: uuid.UUID,
    body: EquipmentPatch,
) -> Equipment:  # fmt: skip
    c = await get_customer(db, p.company_id, customer_id)
    await get_site(db, p.company_id, site_id, customer_id)
    e = (
        await db.execute(
            select(Equipment).where(
                Equipment.id == equipment_id,
                Equipment.site_id == site_id,
                Equipment.company_id == p.company_id,
                Equipment.deleted_at.is_(None),
            )
        )
    ).scalar_one_or_none()
    if not e:
        raise NotFound("equipment_not_found", "Equipment not found.")
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(e, k, v)
    await _touch(c)
    await db.flush()
    return e
