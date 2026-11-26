from datetime import timedelta
from urllib.parse import urlparse

import jwt
import pytest
from sqlalchemy import text

from app.core.db import SessionLocal, engine
from app.providers.messaging import outbox
from tests.conftest import auth, invite_and_join, make_owner
from tests.test_reports import make_report, ready  # noqa: F401 - the `ready` fixture

TECH2 = "+919898989898"


async def approved(client, s) -> dict:
    """Make, submit and approve the report of the `ready` job."""
    _, _, rep = await make_report(client, s["tech"], s["job"]["id"])
    assert (
        await client.post(f"/api/v1/reports/{rep['id']}/submit", headers=auth(s["tech"]))
    ).status_code == 200
    r = await client.post(f"/api/v1/reports/{rep['id']}/approve", headers=auth(s["owner"]))
    assert r.status_code == 200, r.text
    return r.json()


def token_of(url: str) -> str:
    return urlparse(url).path.rsplit("/", 1)[-1]


async def get_file(client, url: str):
    u = urlparse(url)
    return await client.get(f"{u.path}?{u.query}")


async def shared_link(client, s) -> tuple[dict, str]:
    rep = await approved(client, s)
    r = await client.post(
        f"/api/v1/reports/{rep['id']}/share-links", json={"channel": "copy"}, headers=auth(s["owner"])
    )
    assert r.status_code == 201, r.text
    return rep, token_of(r.json()["url"])


# ---- PDF (M34) --------------------------------------------------------------------------------------
async def test_approval_builds_the_pdf(client, ready):
    rep = await approved(client, ready)
    assert rep["pdf_status"] == "ready" and "share" in rep["actions"]
    pdf = (await client.get(f"/api/v1/reports/{rep['id']}/pdf", headers=auth(ready["tech"]))).json()
    assert pdf["status"] == "ready" and pdf["filename"] == "R-1001.pdf" and pdf["pages"] >= 1
    assert len(pdf["sha256"]) == 64 and pdf["size"] > 1000
    f = await get_file(client, pdf["url"])
    assert f.status_code == 200 and f.content.startswith(b"%PDF")


async def test_pdf_in_gujarati_and_hindi(client, ready):
    for lang in ("gu", "hi"):
        async with (
            SessionLocal() as db
        ):  # the report text stays as written; the PDF's words follow its language
            await db.execute(text("UPDATE reports SET language = :l, pdf_status = NULL"), {"l": lang})
            await db.commit()
        if lang == "gu":
            rep = await approved(client, ready)
        r = (await client.get(f"/api/v1/reports/{rep['id']}/pdf", headers=auth(ready["owner"]))).json()
        assert r["status"] == "ready", r


async def test_pdf_only_after_approval(client, ready):
    _, _, rep = await make_report(client, ready["tech"], ready["job"]["id"])
    r = await client.get(f"/api/v1/reports/{rep['id']}/pdf", headers=auth(ready["tech"]))
    assert r.status_code == 409 and r.json()["error"]["code"] == "report_not_approved"


# ---- share screen and sending (M35) -----------------------------------------------------------------
async def test_nothing_reaches_the_customer_before_approval(client, ready):
    owner = ready["owner"]
    _, _, rep = await make_report(client, ready["tech"], ready["job"]["id"])
    info = (await client.get(f"/api/v1/reports/{rep['id']}/share", headers=auth(owner))).json()
    assert info["can_share"] is False and info["blocked_by"] == "not_approved" and info["preview"] is None
    r = await client.post(
        f"/api/v1/reports/{rep['id']}/send", json={"channels": ["sms"]}, headers=auth(owner)
    )
    assert r.status_code == 409 and r.json()["error"]["code"] == "report_not_approved"
    r = await client.post(f"/api/v1/reports/{rep['id']}/share-links", headers=auth(owner))
    assert r.status_code == 409
    # the database refuses too
    async with SessionLocal() as db:
        with pytest.raises(Exception, match="not approved"):
            await db.execute(
                text(
                    "INSERT INTO share_links (id, company_id, report_id, token_hash, channel, expires_at, open_count,"
                    " created_at, updated_at) SELECT gen_random_uuid(), company_id, id, 'x', 'copy', now(), 0, now(),"
                    " now() FROM reports"
                )
            )


async def test_send_by_sms_whatsapp_and_email(client, ready):
    owner, tech = ready["owner"], ready["tech"]
    rep = await approved(client, ready)
    info = (await client.get(f"/api/v1/reports/{rep['id']}/share", headers=auth(owner))).json()
    assert info["recipient"] == {"name": "Mr Sharma", "phone": "+919825011111", "email": "sharma@x.in"}
    assert all(c["available"] for c in info["channels"]) and info["link"] is None
    outbox.clear()
    r = await client.post(
        f"/api/v1/reports/{rep['id']}/send",
        json={"channels": ["sms", "whatsapp", "email"]},
        headers=auth(owner),
    )
    assert r.status_code == 200, r.text
    out = r.json()
    assert out["report_status"] == "shared" and out["link"]["status"] == "active"
    assert sorted(m["channel"] for m in out["sent"]) == ["email", "sms", "whatsapp"]
    assert all(m["status"] == "sent" for m in out["sent"])
    url = out["link"]["url"]
    sms = outbox.sms[-1]
    assert (
        sms["to"] == "+919825011111" and url in sms["body"] and sms["body"].endswith("Reply STOP to opt out.")
    )
    assert url in outbox.whatsapp[-1]["body"] and url in outbox.email[-1]["body"]
    assert outbox.email[-1]["subject"] == "Your service report R-1001 from BrightAir"
    # counted on the profile and the dashboard
    me = (await client.get("/api/v1/me/stats", headers=auth(tech))).json()
    assert me["reports_sent"] == 1
    dash = (await client.get("/api/v1/dashboard", headers=auth(owner))).json()
    assert dash["onboarding"]["first_report_sent"] and dash["week"][-1]["reports_sent"] == 1
    # sending again keeps the same link
    again = (
        await client.post(
            f"/api/v1/reports/{rep['id']}/send", json={"channels": ["sms"]}, headers=auth(owner)
        )
    ).json()
    assert again["link"]["url"] == url and len(again["sent"]) == 4


async def test_contact_missing(client, ready):
    owner = ready["owner"]
    rep = await approved(client, ready)
    async with SessionLocal() as db:
        await db.execute(text("UPDATE customer_contacts SET email = NULL"))
        await db.commit()
    info = (await client.get(f"/api/v1/reports/{rep['id']}/share", headers=auth(owner))).json()
    assert {c["key"]: c["reason"] for c in info["channels"]}["email"] == "no_email"
    r = await client.post(
        f"/api/v1/reports/{rep['id']}/send", json={"channels": ["email"]}, headers=auth(owner)
    )
    assert r.status_code == 400 and r.json()["error"] == {
        "code": "contact_missing",
        "message": r.json()["error"]["message"],
        "fields": {"email": "missing"},
        "details": {},
    }
    r = await client.post(
        f"/api/v1/reports/{rep['id']}/send",
        json={"channels": ["email"], "email": "accounts@sharma.in"},
        headers=auth(owner),
    )
    assert r.status_code == 200 and r.json()["sent"][0]["to"] == "accounts@sharma.in"


async def test_technicians_share_only_when_the_company_allows(client, ready):
    tech, owner = ready["tech"], ready["owner"]
    rep = await approved(client, ready)
    assert (
        "share"
        not in (await client.get(f"/api/v1/reports/{rep['id']}", headers=auth(tech))).json()["actions"]
    )
    r = await client.post(f"/api/v1/reports/{rep['id']}/send", json={"channels": ["sms"]}, headers=auth(tech))
    assert r.status_code == 403
    r = await client.patch(
        "/api/v1/company/settings", json={"technicians_can_share": True}, headers=auth(owner)
    )
    assert r.status_code == 200, r.text
    r = await client.post(f"/api/v1/reports/{rep['id']}/send", json={"channels": ["sms"]}, headers=auth(tech))
    assert r.status_code == 200
    # turning a link off stays with owners and managers
    link = r.json()["link"]["id"]
    assert (await client.delete(f"/api/v1/share-links/{link}", headers=auth(tech))).status_code == 403


# ---- customer report page (W27) -----------------------------------------------------------------------
async def test_customer_page_shows_the_report_without_gps(client, ready):
    rep, token = await shared_link(client, ready)
    r = await client.get(f"/api/v1/public/reports/{token}")
    assert r.status_code == 200, r.text
    page = r.json()
    assert page["number"] == "R-1001" and page["company"]["name"] == "BrightAir"
    assert page["customer"] == "Sharma Textiles" and page["address"] == "12 Ring Road, Surat"
    assert page["approved_by"] == "Asha Patel" and page["work_done"] and page["pdf_ready"]
    assert len(page["photos"]) == 2 and page["acknowledged"] is None
    for photo in page["photos"]:
        key = jwt.decode(urlparse(photo["url"]).path.rsplit("/", 1)[-1], options={"verify_signature": False})[
            "sub"
        ]
        assert key.endswith("_web.jpg")  # the EXIF-free copy, never the original
        assert (await get_file(client, photo["url"])).status_code == 200
    page2 = (await client.get(f"/api/v1/public/reports/{token}?lang=hi")).json()
    assert page2["lang"] == "hi" and page2["language"] == "en"
    link = (await client.get(f"/api/v1/reports/{rep['id']}/share", headers=auth(ready["owner"]))).json()[
        "link"
    ]
    assert link["open_count"] == 2 and link["first_opened_at"]
    # PDF download
    r = await client.get(f"/api/v1/public/reports/{token}/pdf", follow_redirects=False)
    assert r.status_code == 307 and (await get_file(client, r.headers["location"])).content.startswith(
        b"%PDF"
    )


async def test_acknowledge_once(client, ready):
    rep, token = await shared_link(client, ready)
    r = await client.post(
        f"/api/v1/public/reports/{token}/acknowledge",
        json={"name": "R. Sharma", "organisation": "Sharma Textiles"},
    )
    assert r.status_code == 200 and r.json()["name"] == "R. Sharma"
    r = await client.post(f"/api/v1/public/reports/{token}/acknowledge", json={"name": "Someone else"})
    assert r.json()["name"] == "R. Sharma"  # the first answer stays
    full = (await client.get(f"/api/v1/reports/{rep['id']}", headers=auth(ready["owner"]))).json()
    assert full["status"] == "acknowledged" and full["acknowledged_at"]
    page = (await client.get(f"/api/v1/public/reports/{token}")).json()
    assert page["acknowledged"]["organisation"] == "Sharma Textiles"


async def test_bad_and_turned_off_links(client, ready):
    rep, token = await shared_link(client, ready)
    assert (await client.get("/api/v1/public/reports/not-a-real-token")).status_code == 404
    forged = token[:-4] + ("AAAA" if not token.endswith("AAAA") else "BBBB")
    assert (await client.get(f"/api/v1/public/reports/{forged}")).status_code == 404
    link = (await client.get(f"/api/v1/reports/{rep['id']}/share", headers=auth(ready["owner"]))).json()[
        "link"
    ]
    assert (
        await client.delete(f"/api/v1/share-links/{link['id']}", headers=auth(ready["owner"]))
    ).status_code == 204
    r = await client.get(f"/api/v1/public/reports/{token}")
    assert r.status_code == 410 and r.json()["error"]["code"] == "link_revoked"
    assert (await client.post(f"/api/v1/public/reports/{token}/request-link")).status_code == 410
    # sharing again makes a new link; the old one stays off
    new = (await client.post(f"/api/v1/reports/{rep['id']}/share-links", headers=auth(ready["owner"]))).json()
    assert token_of(new["url"]) != token
    assert (await client.get(f"/api/v1/public/reports/{token_of(new['url'])}")).status_code == 200


async def expire_links():
    async with SessionLocal() as db:
        await db.execute(text("UPDATE share_links SET expires_at = now() - interval '1 day'"))
        await db.commit()


async def test_expired_link_and_new_link_to_the_same_phone(client, ready):
    owner = ready["owner"]
    rep = await approved(client, ready)
    sent = (
        await client.post(
            f"/api/v1/reports/{rep['id']}/send", json={"channels": ["sms"]}, headers=auth(owner)
        )
    ).json()
    token = token_of(sent["link"]["url"])
    await expire_links()
    r = await client.get(f"/api/v1/public/reports/{token}")
    assert r.status_code == 410 and r.json()["error"]["code"] == "link_expired"
    assert (
        r.json()["error"]["details"]["can_request_new_link"]
        and r.json()["error"]["details"]["company"] == "BrightAir"
    )
    outbox.clear()
    r = await client.post(f"/api/v1/public/reports/{token}/request-link")
    assert r.status_code == 200 and r.json() == {
        "sent_to": "+91982•••111",
        "channel": "sms",
        "company_notified": False,
    }
    assert outbox.sms[-1]["to"] == "+919825011111" and token in outbox.sms[-1]["body"]
    assert (await client.get(f"/api/v1/public/reports/{token}")).status_code == 200  # works again
    r = await client.post(f"/api/v1/public/reports/{token}/request-link")
    assert r.status_code == 409 and r.json()["error"]["code"] == "link_active"
    await expire_links()
    r = await client.post(f"/api/v1/public/reports/{token}/request-link")
    assert r.status_code == 429 and "resend_after" in r.json()["error"]["details"]


async def test_copied_link_expired_tells_the_company(client, ready):
    _, token = await shared_link(client, ready)
    await expire_links()
    outbox.clear()
    r = await client.post(f"/api/v1/public/reports/{token}/request-link")
    assert r.json() == {"sent_to": None, "channel": None, "company_notified": True}
    assert outbox.email[-1]["to"] == "owner@brightair.in" and not outbox.sms


async def test_report_a_problem(client, ready):
    _, token = await shared_link(client, ready)
    outbox.clear()
    r = await client.post(
        f"/api/v1/public/reports/{token}/issue",
        json={"message": "The AC is leaking again", "contact": "98250 11111"},
    )
    assert r.status_code == 201 and r.json()["id"]
    assert outbox.email[-1]["subject"] == "A customer reported a problem with report R-1001"
    assert "leaking" in outbox.email[-1]["body"]
    for _ in range(4):
        await client.post(f"/api/v1/public/reports/{token}/issue", json={"message": "Still leaking"})
    r = await client.post(f"/api/v1/public/reports/{token}/issue", json={"message": "Hello?"})
    assert r.status_code == 429
    # D-145: the office sees it in Messages too (no email service yet)
    items = (await client.get("/api/v1/notifications", headers=auth(ready["owner"]))).json()["data"]
    [first, *_] = [n for n in reversed(items) if n["kind"] == "customer_issue"]
    assert (
        first["params"]["message"] == "The AC is leaking again"
        and first["params"]["contact"] == "98250 11111"
    )
    assert first["params"]["report"] == "R-1001" and first["params"]["customer"] and first["job_id"]


async def test_report_page_shows_the_company_number_once_set(client, ready):
    _, token = await shared_link(client, ready)
    page = (await client.get(f"/api/v1/public/reports/{token}")).json()
    assert page["company"]["phone"] is None  # no Call button until the owner sets a number
    url = "/api/v1/company/settings"
    bad = await client.patch(url, json={"contact_phone": "call me"}, headers=auth(ready["owner"]))
    assert bad.status_code == 422
    r = await client.patch(url, json={"contact_phone": " +91 98250 22222 "}, headers=auth(ready["owner"]))
    assert r.status_code == 200 and r.json()["settings"]["contact_phone"] == "+91 98250 22222"
    page = (await client.get(f"/api/v1/public/reports/{token}")).json()
    assert page["company"]["phone"] == "+91 98250 22222"
    await client.patch(url, json={"contact_phone": ""}, headers=auth(ready["owner"]))
    assert (await client.get(f"/api/v1/public/reports/{token}")).json()["company"]["phone"] is None


async def test_other_companies_cannot_touch_sharing(client, ready):
    rep, _ = await shared_link(client, ready)
    link = (await client.get(f"/api/v1/reports/{rep['id']}/share", headers=auth(ready["owner"]))).json()[
        "link"
    ]
    stranger = await make_owner(client, email="boss@coolbreeze.in", company="Cool Breeze")
    assert (await client.get(f"/api/v1/reports/{rep['id']}/share", headers=auth(stranger))).status_code == 404
    assert (await client.get(f"/api/v1/reports/{rep['id']}/pdf", headers=auth(stranger))).status_code == 404
    assert (
        await client.delete(f"/api/v1/share-links/{link['id']}", headers=auth(stranger))
    ).status_code == 404
    other_tech = await invite_and_join(client, ready["owner"], TECH2)
    assert (await client.get(f"/api/v1/reports/{rep['id']}/pdf", headers=auth(other_tech))).status_code == 404


def test_link_expiry_is_30_days():
    from app.services.sharing import LINK_DAYS

    assert timedelta(days=LINK_DAYS) == timedelta(days=30)


async def test_customer_copy_has_no_gps(client, ready):
    import io

    from PIL import Image

    from app.providers.storage import get_storage
    from tests.test_evidence import add_photo

    img = Image.new("RGB", (2400, 1800), (90, 140, 200))
    exif = Image.Exif()
    exif[0x0110] = "Phone X"
    exif.get_ifd(0x8825).update({1: "N", 2: (21.0, 10.0, 0.0), 3: "E", 4: (72.0, 49.0, 0.0)})  # GPS
    buf = io.BytesIO()
    img.save(buf, "JPEG", exif=exif)
    r = await add_photo(client, ready["tech"], ready["job"]["id"], "during", data=buf.getvalue())
    assert r.status_code == 201
    async with SessionLocal() as db:
        keys = (await db.execute(text("SELECT file_key, web_key FROM evidence WHERE stage = 'during'"))).one()
    s = get_storage()
    with Image.open(io.BytesIO(await s.read(keys.file_key))) as original:
        assert original.getexif().get_ifd(0x8825)  # the evidence keeps its GPS
    with Image.open(io.BytesIO(await s.read(keys.web_key))) as web:
        assert not web.getexif() and max(web.size) == 1600


def test_unbranded_pdf_says_made_with_kaamnishaan():
    """D-147: on the Free plan the PDF has no company logo and carries KaamNishaan's line."""
    from app.services.report_labels import label

    assert label("en", "made_with") == "Made with KaamNishaan · kaamnishaan.com"
    assert "KaamNishaan" in label("hi", "made_with") and "KaamNishaan" in label("fr", "made_with")


async def test_a_number_typed_in_share_is_kept_for_next_time(client, ready):
    """D-151: Share fills a missing phone on the customer, and never changes one already saved."""
    rep = await approved(client, ready)
    async with engine.begin() as c:
        await c.execute(text("update customer_contacts set phone = null"))
    r = await client.post(
        f"/api/v1/reports/{rep['id']}/send",
        json={"channels": ["sms"], "phone": "98250 44444"},
        headers=auth(ready["owner"]),
    )
    assert r.status_code == 200, r.text
    async with engine.begin() as c:
        assert (await c.execute(text("select phone from customer_contacts"))).scalar_one() == "+919825044444"
    await client.post(
        f"/api/v1/reports/{rep['id']}/send",
        json={"channels": ["sms"], "phone": "98250 55555"},
        headers=auth(ready["owner"]),
    )
    async with engine.begin() as c:  # a one-off number doesn't replace the saved one
        assert (await c.execute(text("select phone from customer_contacts"))).scalar_one() == "+919825044444"
