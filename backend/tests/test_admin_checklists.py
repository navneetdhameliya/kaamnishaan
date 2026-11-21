"""A23: KaamNishaan's own checklist templates from the admin panel."""

from app.core.db import SessionLocal
from app.models import StaffUser
from tests.conftest import auth, make_owner
from tests.test_admin_auth import _setup

A = "/api/v1/admin/checklist-templates"


async def _new(client, s, name="Solar install"):
    r = await client.post(A, json={"name": name, "trade": "solar", "minutes": 10}, headers=auth(s))
    assert r.status_code == 201, r.text
    return r.json()


async def test_build_publish_and_companies_see_it(client):
    s, _ = await _setup(client)
    t = await _new(client, s)
    assert t["status"] == "draft" and t["source_language"] == "en" and t["questions"] == []
    # can't publish an empty checklist
    r = await client.patch(f"{A}/{t['id']}", json={"status": "published"}, headers=auth(s))
    assert r.status_code == 400 and r.json()["error"]["fields"] == {"status": "no_questions"}
    r = await client.post(
        f"{A}/{t['id']}/questions",
        json={"type": "yes_no", "text": "Panels cleaned?", "photo_rule": "if_no"},
        headers=auth(s),
    )
    assert r.status_code == 201, r.text
    q1 = r.json()["questions"][0]
    r = await client.post(
        f"{A}/{t['id']}/questions",
        json={"type": "choice", "text": "Roof type", "options": [{"label": "Tin"}, {"label": "Concrete"}],
              "condition": {"question_id": q1["id"], "equals": "yes"}},
        headers=auth(s),
    )  # fmt: skip
    d = r.json()
    assert len(d["questions"]) == 2 and d["questions"][1]["options"][0]["key"] == "tin"
    # app rules apply: "photo if No" only on yes/no
    bad = await client.post(
        f"{A}/{t['id']}/questions",
        json={"type": "text", "text": "Notes", "photo_rule": "if_no"},
        headers=auth(s),
    )
    assert bad.status_code == 400 and bad.json()["error"]["fields"] == {"photo_rule": "type"}
    # without an AI key nothing is machine-translated: other languages are missing
    assert (
        d["languages"]["en"] == "ready" and d["languages"]["hi"] == "missing" and d["ai_available"] is False
    )
    out = (await client.post(f"{A}/{t['id']}/translate", headers=auth(s))).json()
    assert out == {"queued": 0, "ai_available": False}

    r = await client.patch(
        f"{A}/{t['id']}", json={"status": "published", "names": {"hi": "सोलर इंस्टॉल"}}, headers=auth(s)
    )
    assert r.json()["status"] == "published" and r.json()["name"]["hi"] == "सोलर इंस्टॉल"
    site = (
        await client.get("/api/v1/public/checklist-templates", params={"trade": "solar", "locale": "hi"})
    ).json()
    assert any(x["name"] == "सोलर इंस्टॉल" and x["question_count"] == 2 for x in site["items"])
    owner = await make_owner(client)
    seen = (await client.get("/api/v1/checklist-templates", headers=auth(owner))).json()
    assert any(i["id"] == t["id"] for i in seen["data"])


async def test_hand_translation_and_list_tabs(client):
    s, _ = await _setup(client)
    t = await _new(client, s, "Panel check")
    d = (
        await client.post(
            f"{A}/{t['id']}/questions", json={"type": "pass_fail", "text": "Inverter OK?"}, headers=auth(s)
        )
    ).json()
    qid = d["questions"][0]["id"]
    for lg, txt in {
        "hi": "इन्वर्टर ठीक?",
        "gu": "ઇન્વર્ટર બરાબર?",
        "es": "¿Inversor bien?",
        "fr": "Onduleur OK ?",
    }.items():
        d = (
            await client.patch(
                f"{A}/{t['id']}/questions/{qid}", json={"translations": {lg: txt}}, headers=auth(s)
            )
        ).json()
    assert all(v == "ready" for v in d["languages"].values())
    lst = (await client.get(A, headers=auth(s))).json()
    mine = next(i for i in lst["items"] if i["id"] == t["id"])
    assert mine["question_count"] == 1 and mine["status"] == "draft" and mine["trade_name"]
    drafts = (await client.get(A, params={"tab": "drafts"}, headers=auth(s))).json()
    assert [i["id"] for i in drafts["items"]] == [t["id"]] and lst["counts"]["drafts"] == 1
    # the seeded HVAC checklists are there, and new words in English send the question back to "missing"
    d = (
        await client.patch(
            f"{A}/{t['id']}/questions/{qid}", json={"text": "Inverter working?"}, headers=auth(s)
        )
    ).json()
    assert d["languages"]["hi"] == "missing"
    assert (await client.delete(f"{A}/{t['id']}/questions/{qid}", headers=auth(s))).json()["questions"] == []


async def test_review_approve_and_support_is_read_only(client):
    s, _ = await _setup(client)
    t = await _new(client, s, "Approve me")
    d = (
        await client.post(
            f"{A}/{t['id']}/questions", json={"type": "yes_no", "text": "Done?"}, headers=auth(s)
        )
    ).json()
    qid = d["questions"][0]["id"]
    # pretend a machine translation arrived
    from app.models import ChecklistQuestion

    async with SessionLocal() as db:
        q = await db.get(ChecklistQuestion, qid)
        q.text = {**q.text, "fr": "Fini ?"}
        q.text_status = {**q.text_status, "fr": "needs_review"}
        await db.commit()
    d = (await client.get(f"{A}/{t['id']}", headers=auth(s))).json()
    assert d["languages"]["fr"] == "review" and d["languages"]["hi"] == "missing"
    lst = (await client.get(A, params={"language_state": "review"}, headers=auth(s))).json()
    assert t["id"] in [i["id"] for i in lst["items"]]
    d = (await client.post(f"{A}/{t['id']}/approve", json={"language": "fr"}, headers=auth(s))).json()
    assert d["questions"][0]["text_status"]["fr"] == "ready"
    async with SessionLocal() as db:
        await db.execute(StaffUser.__table__.update().values(role="support"))
        await db.commit()
    assert (await client.get(A, headers=auth(s))).status_code == 200
    assert (await client.patch(f"{A}/{t['id']}", json={"minutes": 5}, headers=auth(s))).status_code == 403


async def test_reference_photos(client):
    """Admin adds a "what good looks like" photo; companies that copy the checklist keep theirs."""
    png = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64
    s, _ = await _setup(client)
    t = await _new(client, s)
    r = await client.post(
        f"{A}/{t['id']}/questions", json={"type": "photo", "text": "Panel after cleaning"}, headers=auth(s)
    )
    q = r.json()["questions"][0]
    assert q["reference_image_url"] is None
    bad = await client.put(f"{A}/{t['id']}/questions/{q['id']}/reference", content=b"hello", headers=auth(s))
    assert bad.status_code == 400
    r = await client.put(f"{A}/{t['id']}/questions/{q['id']}/reference", content=png, headers=auth(s))
    assert r.status_code == 200 and r.json()["questions"][0]["reference_image_url"]

    await client.patch(f"{A}/{t['id']}", json={"status": "published"}, headers=auth(s))
    owner = await make_owner(client)
    mine = await client.post(f"/api/v1/checklist-templates/{t['id']}/copy", headers=auth(owner))
    assert mine.status_code == 201, mine.text
    copy = mine.json()
    assert copy["questions"][0]["reference_image_url"]

    r = await client.delete(f"{A}/{t['id']}/questions/{q['id']}/reference", headers=auth(s))
    assert r.json()["questions"][0]["reference_image_url"] is None
    again = (await client.get(f"/api/v1/checklist-templates/{copy['id']}", headers=auth(owner))).json()
    assert again["questions"][0]["reference_image_url"]

    # the company takes it off its own copy
    cq = copy["questions"][0]["id"]
    r = await client.patch(
        f"/api/v1/checklist-templates/{copy['id']}/questions/{cq}",
        json={"remove_reference": True},
        headers=auth(owner),
    )
    assert r.status_code == 200, r.text
    after = (await client.get(f"/api/v1/checklist-templates/{copy['id']}", headers=auth(owner))).json()
    assert after["questions"][0]["reference_image_url"] is None
