import uuid
from datetime import UTC, datetime

import pytest
from sqlalchemy import text

from app.core.db import SessionLocal
from app.providers.ai import AIProvider, Transcript, set_ai_for_tests
from app.services.evidence import lock_job_evidence
from tests.conftest import auth, invite_and_join, make_owner
from tests.test_customers_jobs import new_customer, new_job
from tests.test_evidence import add_photo, jpeg, upload

TECH = "+919812345678"
TECH2 = "+919898989898"


def now_iso() -> str:
    return datetime.now(UTC).isoformat()


class FakeAI(AIProvider):
    def __init__(self, text="Gas was low, I filled it and cleaned the filter", language="hi", confidence=0.9):
        self.text, self.language, self.confidence = text, language, confidence
        self.translations: list[tuple[list[str], str]] = []

    async def transcribe(self, data, filename, content_type, language_hint):
        return Transcript(self.text, self.language, self.confidence)

    async def translate(self, texts, target, source=None):
        self.translations.append((texts, target))
        return [f"[{target}] {t}" for t in texts]


@pytest.fixture
def fake_ai():
    ai = FakeAI()
    set_ai_for_tests(ai)
    yield ai
    set_ai_for_tests(None)


@pytest.fixture
async def setup(client):
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, TECH)
    c = await new_customer(client, owner)
    return {"owner": owner, "tech": tech, "customer": c}


async def global_template(client, who, key_word="Split AC service"):
    lst = (await client.get("/api/v1/checklist-templates?trade=hvac", headers=auth(who))).json()
    return next(t for t in lst["data"] if t["name"] == key_word)


async def started_job_with(client, s, template_ids):
    j = await new_job(
        client,
        s["owner"],
        s["customer"],
        assigned_to=s["tech"]["user"]["id"],
        checklist_template_ids=template_ids,
    )
    assert (await client.post(f"/api/v1/jobs/{j['id']}/start", headers=auth(s["tech"]))).status_code == 200
    lst = (await client.get(f"/api/v1/jobs/{j['id']}/checklists", headers=auth(s["tech"]))).json()
    return j, lst["data"]


async def answer(client, who, checklist_id, question_id, **body):
    return await client.put(
        f"/api/v1/checklist-submissions/{checklist_id}/answers/{question_id}", json=body, headers=auth(who)
    )


# ---- ready-made templates ------------------------------------------------------------------------
async def test_ready_made_hvac_templates_in_five_languages(client, setup):
    owner = setup["owner"]
    lst = (await client.get("/api/v1/checklist-templates?trade=hvac", headers=auth(owner))).json()
    assert lst["meta"]["counts"]["global"] == 4
    assert {t["name"] for t in lst["data"]} == {
        "Split AC service", "AC not cooling – repair", "AC installation", "Preventive maintenance – commercial unit",
    }  # fmt: skip
    hi = (await client.get("/api/v1/checklist-templates?trade=hvac&lang=gu", headers=auth(owner))).json()
    assert "સ્પ્લિટ એસી સર્વિસ" in {t["name"] for t in hi["data"]}
    t = await global_template(client, owner)
    detail = (await client.get(f"/api/v1/checklist-templates/{t['id']}", headers=auth(owner))).json()
    assert detail["question_count"] == 9 and not detail["editable"]
    q = detail["questions"][0]
    assert q["text_status"] == {
        "en": "ready",
        "hi": "needs_review",
        "gu": "needs_review",
        "es": "needs_review",
        "fr": "needs_review",
    }
    # technicians don't browse templates
    assert (await client.get("/api/v1/checklist-templates", headers=auth(setup["tech"]))).status_code == 403


async def test_global_templates_are_read_only_but_can_be_copied(client, setup):
    owner = setup["owner"]
    t = await global_template(client, owner)
    r = await client.patch(
        f"/api/v1/checklist-templates/{t['id']}", json={"name": "Mine"}, headers=auth(owner)
    )
    assert r.status_code == 403 and r.json()["error"]["code"] == "global_template_read_only"
    copy = (await client.post(f"/api/v1/checklist-templates/{t['id']}/copy", headers=auth(owner))).json()
    assert copy["scope"] == "company" and copy["editable"] and copy["question_count"] == 9
    r = await client.patch(
        f"/api/v1/checklist-templates/{copy['id']}",
        json={"name": "BrightAir AC service"},
        headers=auth(owner),
    )
    assert r.status_code == 200 and r.json()["name"] == "BrightAir AC service"


# ---- checklist builder (M26) -----------------------------------------------------------------------
async def test_builder_questions_rules_and_order(client, setup, fake_ai):
    owner = setup["owner"]
    t = (
        await client.post(
            "/api/v1/checklist-templates", json={"name": "Duct cleaning", "minutes": 8}, headers=auth(owner)
        )
    ).json()
    assert t["status"] == "draft" and t["trade"] == "hvac"
    base = f"/api/v1/checklist-templates/{t['id']}/questions"
    q1 = (
        await client.post(base, json={"type": "yes_no", "text": "Ducts dusty?"}, headers=auth(owner))
    ).json()["questions"][0]
    # automatic translation (fake) fills the other 4 languages, marked for review
    assert q1["text_status"]["hi"] == "needs_review" and q1["text_all"]["hi"] == "[hi] Ducts dusty?"
    bad = await client.post(
        base, json={"type": "number", "text": "Temp", "photo_rule": "if_no"}, headers=auth(owner)
    )
    assert bad.status_code == 400 and bad.json()["error"]["fields"] == {"photo_rule": "type"}
    bad = await client.post(
        base, json={"type": "choice", "text": "Which?", "options": [{"label": "One"}]}, headers=auth(owner)
    )
    assert bad.json()["error"]["fields"] == {"options": "too_few"}
    bad = await client.post(
        base, json={"type": "number", "text": "x", "min_value": 5, "max_value": 1}, headers=auth(owner)
    )
    assert bad.json()["error"]["fields"] == {"min_value": "range"}
    r = await client.post(
        base,
        json={"type": "text", "text": "Where?", "condition": {"question_id": q1["id"], "equals": "yes"}},
        headers=auth(owner),
    )
    assert r.status_code == 201 and r.json()["questions"][1]["condition"]["equals"] == "yes"
    r = await client.post(
        base, json={"type": "pass_fail", "text": "Airflow OK", "position": 1}, headers=auth(owner)
    )
    texts = [q["text"] for q in r.json()["questions"]]
    assert texts == ["Airflow OK", "Ducts dusty?", "Where?"] and r.json()["version"] == 4
    # removing a question frees the ones that depended on it
    await client.delete(f"{base}/{q1['id']}", headers=auth(owner))
    d = (await client.get(f"/api/v1/checklist-templates/{t['id']}", headers=auth(owner))).json()
    assert [q["position"] for q in d["questions"]] == [1, 2] and d["questions"][1]["condition"] is None
    pub = await client.patch(
        f"/api/v1/checklist-templates/{t['id']}", json={"status": "published"}, headers=auth(owner)
    )
    assert pub.json()["status"] == "published"


async def test_show_if_rules_survive_choice_edits_and_moves(client, setup):
    owner = setup["owner"]
    t = (
        await client.post("/api/v1/checklist-templates", json={"name": "Filters"}, headers=auth(owner))
    ).json()
    base = f"/api/v1/checklist-templates/{t['id']}/questions"
    opts = [{"label": "Clean"}, {"label": "Dusty"}, {"label": "Torn"}]
    q1 = (
        await client.post(
            base, json={"type": "choice", "text": "Filter state", "options": opts}, headers=auth(owner)
        )
    ).json()["questions"][0]
    assert [o["key"] for o in q1["options"]] == ["clean", "dusty", "torn"]
    r = await client.post(
        base,
        json={
            "type": "photo",
            "text": "Photo of the tear",
            "required": False,
            "condition": {"question_id": q1["id"], "equals": "torn"},
        },
        headers=auth(owner),
    )
    q2 = r.json()["questions"][1]
    assert q2["condition"]["equals"] == "torn" and q2["required"] is False
    # renaming a choice keeps its key, so the rule stays
    keep = [
        {"key": "clean", "label": "Clean"},
        {"key": "dusty", "label": "Dusty"},
        {"key": "torn", "label": "Ripped"},
    ]
    r = await client.patch(f"{base}/{q1['id']}", json={"options": keep}, headers=auth(owner))
    assert r.json()["questions"][1]["condition"]["equals"] == "torn"
    # removing the choice frees the question that waited for it
    r = await client.patch(f"{base}/{q1['id']}", json={"options": keep[:2]}, headers=auth(owner))
    assert r.status_code == 200 and r.json()["questions"][1]["condition"] is None
    # moving a question above the one it waits for drops its rule instead of failing
    await client.patch(
        f"{base}/{q2['id']}",
        json={"condition": {"question_id": q1["id"], "equals": "dusty"}},
        headers=auth(owner),
    )
    r = await client.patch(f"{base}/{q2['id']}", json={"position": 1}, headers=auth(owner))
    assert r.status_code == 200
    assert [q["id"] for q in r.json()["questions"]] == [q2["id"], q1["id"]]
    assert r.json()["questions"][0]["condition"] is None
    r = await client.patch(f"{base}/{q2['id']}", json={"clear_condition": True}, headers=auth(owner))
    assert r.status_code == 200


async def test_hand_fixed_translation_is_kept(client, setup, fake_ai):
    owner = setup["owner"]
    t = (await client.post("/api/v1/checklist-templates", json={"name": "X"}, headers=auth(owner))).json()
    q = (
        await client.post(
            f"/api/v1/checklist-templates/{t['id']}/questions",
            json={"type": "yes_no", "text": "Leak?"},
            headers=auth(owner),
        )
    ).json()["questions"][0]
    r = await client.patch(
        f"/api/v1/checklist-templates/{t['id']}/questions/{q['id']}",
        json={"translations": {"hi": "रिसाव है?"}},
        headers=auth(owner),
    )
    q2 = r.json()["questions"][0]
    assert q2["text_all"]["hi"] == "रिसाव है?" and q2["text_status"]["hi"] == "ready"


async def test_without_ai_translations_wait(client, setup):
    owner = setup["owner"]
    t = (
        await client.post(
            "/api/v1/checklist-templates", json={"name": "X", "language": "gu"}, headers=auth(owner)
        )
    ).json()
    r = await client.post(
        f"/api/v1/checklist-templates/{t['id']}/questions",
        json={"type": "yes_no", "text": "લીક છે?"},
        headers=auth(owner),
    )
    q = r.json()["questions"][0]
    assert q["text_status"] == {
        "en": "missing",
        "hi": "missing",
        "gu": "ready",
        "es": "missing",
        "fr": "missing",
    }
    assert q["text"] == "લીક છે?"  # shown in the source language until translated


# ---- answering (M24, M25) ---------------------------------------------------------------------------
async def test_answer_flow_with_photo_rule_and_progress(client, setup):
    tech = setup["tech"]
    t = await global_template(client, setup["owner"])
    job, lists = await started_job_with(client, setup, [t["id"]])
    assert [(x["name"], x["answered"], x["total"], x["status"]) for x in lists] == [
        ("Split AC service", 0, 9, "not_started")
    ]
    cid = lists[0]["id"]
    sub = (await client.get(f"/api/v1/checklist-submissions/{cid}", headers=auth(tech))).json()
    qs = {q["position"]: q for q in sub["questions"]}

    r = await answer(client, tech, cid, qs[1]["id"], value=True)  # true -> yes
    assert (
        r.status_code == 200
        and r.json()["questions"][0]["answer"]["value"] == "yes"
        and r.json()["answered"] == 1
    )
    # "filters cleaned" always needs a photo
    r = await answer(client, tech, cid, qs[3]["id"], value="pass")
    assert r.status_code == 400 and r.json()["error"]["code"] == "photo_required"
    photo = (await add_photo(client, tech, job["id"], "during")).json()
    r = await answer(client, tech, cid, qs[3]["id"], value="pass", photo_id=photo["id"])
    assert r.status_code == 200 and r.json()["questions"][2]["answer"]["photo"]["id"] == photo["id"]
    # drain: a photo only if it fails
    assert (await answer(client, tech, cid, qs[5]["id"], value="pass")).status_code == 200
    assert (await answer(client, tech, cid, qs[5]["id"], value="fail")).json()["error"][
        "code"
    ] == "photo_required"
    # numbers are checked against the allowed range
    r = await answer(client, tech, cid, qs[6]["id"], value=9000)
    assert (
        r.json()["error"]["fields"] == {"value": "out_of_range"}
        and r.json()["error"]["details"]["max_value"] == 600
    )
    assert (await answer(client, tech, cid, qs[6]["id"], value="68.5")).json()["questions"][5]["answer"][
        "value"
    ] == 68.5
    bad = await answer(client, tech, cid, qs[4]["id"], value="maybe")
    assert bad.json()["error"]["fields"] == {"value": "pass_fail"}

    proof = (await client.get(f"/api/v1/jobs/{job['id']}/proof", headers=auth(tech))).json()
    checklist_step = next(s for s in proof["steps"] if s["key"] == "checklist")
    assert checklist_step == {
        "key": "checklist",
        "count": 0,
        "total": 1,
        "required": True,
        "done": False,
        "thumbs": [],
    }
    assert {p["key"] for p in proof["shot_prompts"]} == {
        "indoor_unit",
        "dirty_filter",
        "clean_filter",
        "outdoor_unit",
    }


async def test_finishing_a_checklist_unlocks_the_report(client, setup):
    tech = setup["tech"]
    t = await global_template(client, setup["owner"], "AC not cooling – repair")
    job, lists = await started_job_with(client, setup, [t["id"]])
    cid = lists[0]["id"]
    qs = {
        q["position"]: q
        for q in (await client.get(f"/api/v1/checklist-submissions/{cid}", headers=auth(tech))).json()[
            "questions"
        ]
    }
    await add_photo(client, tech, job["id"], "before")
    await add_photo(client, tech, job["id"], "after")
    proof = (await client.get(f"/api/v1/jobs/{job['id']}/proof", headers=auth(tech))).json()
    assert proof["blocked_by"] == "need_checklist"

    # "what was the problem?" only shows when the answer is "something else"
    assert qs[3]["visible"] is False
    assert qs[3]["condition"]["equals"] is not None  # the app follows the rule offline
    assert (await answer(client, tech, cid, qs[3]["id"], value="x")).json()["error"][
        "code"
    ] == "question_hidden"
    await answer(client, tech, cid, qs[1]["id"], value="Not cooling at all")
    r = await answer(client, tech, cid, qs[2]["id"], value="other")
    assert r.json()["questions"][2]["visible"] is True and r.json()["total"] == 7  # q3 shown, q6 still hidden
    await answer(client, tech, cid, qs[3]["id"], value="Loose wire")
    photo = (await add_photo(client, tech, job["id"], "during")).json()
    await answer(client, tech, cid, qs[4]["id"], photo_id=photo["id"])
    await answer(client, tech, cid, qs[5]["id"], value="no")
    await answer(client, tech, cid, qs[7]["id"], value="pass")
    r = await answer(client, tech, cid, qs[8]["id"], value=14)
    assert r.json()["status"] == "done" and r.json()["answered"] == r.json()["total"] == 7
    proof = (await client.get(f"/api/v1/jobs/{job['id']}/proof", headers=auth(tech))).json()
    assert proof["can_make_report"] and proof["steps"][3]["done"]
    # changing an answer can re-open it: "part replaced? yes" now needs the part name
    r = await answer(client, tech, cid, qs[5]["id"], value="yes")
    assert r.json()["status"] == "in_progress" and r.json()["total"] == 8


async def test_signature_answer(client, setup):
    tech = setup["tech"]
    t = await global_template(client, setup["owner"])
    job, lists = await started_job_with(client, setup, [t["id"]])
    cid = lists[0]["id"]
    q9 = next(
        q
        for q in (await client.get(f"/api/v1/checklist-submissions/{cid}", headers=auth(tech))).json()[
            "questions"
        ]
        if q["type"] == "signature"
    )
    r = await answer(client, tech, cid, q9["id"])
    assert r.json()["error"]["fields"] == {"signature_upload_id": "required"}
    sig = await upload(client, tech, b"\x89PNG fake signature", kind="signature", content_type="image/png")
    r = await answer(client, tech, cid, q9["id"], signature_upload_id=sig)
    a = next(q for q in r.json()["questions"] if q["type"] == "signature")["answer"]
    assert a["signature_url"]


async def test_snapshot_keeps_running_jobs_unchanged(client, setup):
    owner, tech = setup["owner"], setup["tech"]
    t = (
        await client.post("/api/v1/checklist-templates", json={"name": "Quick check"}, headers=auth(owner))
    ).json()
    base = f"/api/v1/checklist-templates/{t['id']}/questions"
    await client.post(base, json={"type": "yes_no", "text": "Unit on?"}, headers=auth(owner))
    await client.patch(
        f"/api/v1/checklist-templates/{t['id']}", json={"status": "published"}, headers=auth(owner)
    )
    job, lists = await started_job_with(client, setup, [t["id"]])
    await client.post(base, json={"type": "yes_no", "text": "Added later"}, headers=auth(owner))
    sub = (await client.get(f"/api/v1/checklist-submissions/{lists[0]['id']}", headers=auth(tech))).json()
    assert [q["text"] for q in sub["questions"]] == ["Unit on?"]


async def test_attach_rules(client, setup):
    owner = setup["owner"]
    t = await global_template(client, owner)
    job, lists = await started_job_with(client, setup, [t["id"]])
    dup = await client.post(
        f"/api/v1/jobs/{job['id']}/checklists", json={"template_id": t["id"]}, headers=auth(owner)
    )
    assert dup.status_code == 409 and dup.json()["error"]["code"] == "checklist_already_added"
    draft = (
        await client.post("/api/v1/checklist-templates", json={"name": "Draft"}, headers=auth(owner))
    ).json()
    r = await client.post(
        f"/api/v1/jobs/{job['id']}/checklists", json={"template_id": draft["id"]}, headers=auth(owner)
    )
    assert r.json()["error"]["fields"] == {"template_id": "draft"}
    other = await global_template(client, owner, "AC installation")
    r = await client.post(
        f"/api/v1/jobs/{job['id']}/checklists", json={"template_id": other["id"]}, headers=auth(owner)
    )
    assert r.status_code == 201
    assert (
        await client.delete(f"/api/v1/jobs/{job['id']}/checklists/{r.json()['id']}", headers=auth(owner))
    ).status_code == 204


async def test_answers_need_a_started_job_and_lock_with_the_report(client, setup):
    owner, tech = setup["owner"], setup["tech"]
    t = await global_template(client, owner)
    j = await new_job(
        client, owner, setup["customer"], assigned_to=tech["user"]["id"], checklist_template_ids=[t["id"]]
    )
    cid = (await client.get(f"/api/v1/jobs/{j['id']}/checklists", headers=auth(tech))).json()["data"][0]["id"]
    q1 = (await client.get(f"/api/v1/checklist-submissions/{cid}", headers=auth(tech))).json()["questions"][0]
    r = await answer(client, tech, cid, q1["id"], value="yes")
    assert r.status_code == 409 and r.json()["error"]["code"] == "job_not_started"
    await client.post(f"/api/v1/jobs/{j['id']}/start", headers=auth(tech))
    assert (await answer(client, tech, cid, q1["id"], value="yes")).status_code == 200
    async with SessionLocal() as db:
        await lock_job_evidence(db, uuid.UUID(j["id"]))
        await db.commit()
    r = await answer(client, tech, cid, q1["id"], value="no")
    assert r.status_code == 409 and r.json()["error"]["code"] == "evidence_locked"
    sub = (await client.get(f"/api/v1/checklist-submissions/{cid}", headers=auth(tech))).json()
    assert sub["locked"] and sub["questions"][0]["answer"]["locked"]
    async with SessionLocal() as db:  # the database refuses too
        with pytest.raises(Exception, match="evidence_locked"):
            await db.execute(text('UPDATE checklist_answers SET value = \'{"v": "no"}\''))
            await db.commit()


async def test_offline_retry_of_an_answer(client, setup):
    tech = setup["tech"]
    t = await global_template(client, setup["owner"])
    job, lists = await started_job_with(client, setup, [t["id"]])
    cid = lists[0]["id"]
    q1 = (await client.get(f"/api/v1/checklist-submissions/{cid}", headers=auth(tech))).json()["questions"][0]
    key = str(uuid.uuid4())
    a = await answer(client, tech, cid, q1["id"], value="yes", client_uuid=key)
    b = await answer(client, tech, cid, q1["id"], value="yes", client_uuid=key)
    assert a.status_code == b.status_code == 200 and b.json()["answered"] == 1


# ---- manager questions ----------------------------------------------------------------------------
async def test_ask_your_manager(client, setup):
    owner, tech = setup["owner"], setup["tech"]
    t = await global_template(client, owner)
    job, lists = await started_job_with(client, setup, [t["id"]])
    photo = (await add_photo(client, tech, job["id"], "during")).json()
    r = await client.post(
        f"/api/v1/jobs/{job['id']}/manager-questions",
        json={"text": "Is this rust a problem?", "job_checklist_id": lists[0]["id"], "photo_id": photo["id"]}, headers=auth(tech),
    )  # fmt: skip
    assert r.status_code == 201 and r.json()["photo"]["id"] == photo["id"] and r.json()["answer"] is None
    mq = r.json()["id"]
    assert (
        await client.post(f"/api/v1/manager-questions/{mq}/answer", json={"answer": "x"}, headers=auth(tech))
    ).status_code == 403
    r = await client.post(
        f"/api/v1/manager-questions/{mq}/answer",
        json={"answer": "Clean it and paint it"},
        headers=auth(owner),
    )
    assert r.json()["answered_by"]["name"] == "Asha Patel"
    lst = (await client.get(f"/api/v1/jobs/{job['id']}/manager-questions", headers=auth(tech))).json()
    assert lst["meta"]["counts"] == {"all": 1, "open": 0, "answered": 1}


# ---- voice notes (M27–M29) ------------------------------------------------------------------------------
async def _voice(client, who, job_id, **extra):
    up = await upload(client, who, b"fake m4a audio bytes", kind="audio", content_type="audio/mp4")
    return await client.post(
        f"/api/v1/jobs/{job_id}/voice-notes",
        json={"upload_id": up, "duration_s": 42, "recorded_at": now_iso(), **extra},
        headers=auth(who),
    )


async def test_voice_note_waits_without_ai(client, setup):
    tech = setup["tech"]
    job, _ = await started_job_with(client, setup, [])
    r = await _voice(client, tech, job["id"], language_hint="hi")
    v = r.json()
    assert r.status_code == 201 and v["status"] == "uploaded" and v["waiting_for"] == "transcription_service"
    assert v["audio_url"] and v["duration_s"] == 42 and v["language"] == "hi" and v["can_edit"]


async def test_voice_note_transcribed_and_translated(client, setup, fake_ai):
    tech, owner = setup["tech"], setup["owner"]
    job, _ = await started_job_with(client, setup, [])
    v = (await _voice(client, tech, job["id"])).json()
    # company reports are in English; the technician spoke Hindi
    assert v["status"] == "transcribed" and v["language"] == "hi" and v["translated_to"] == "en"
    assert v["transcript_original"] == "Gas was low, I filled it and cleaned the filter"
    assert v["text_for_report"].startswith("[en]") and v["waiting_for"] is None
    async with SessionLocal() as db:  # both AI calls are counted for A20
        used = (await db.execute(text("SELECT task, ok FROM ai_usage ORDER BY at"))).all()
    assert [tuple(u) for u in used] == [("transcription", True), ("translation", True)]
    r = await client.patch(
        f"/api/v1/voice-notes/{v['id']}",
        json={"transcript_edited": "Gas topped up, filter cleaned."},
        headers=auth(tech),
    )
    assert r.json()["text_for_report"] == "Gas topped up, filter cleaned."
    lst = (await client.get(f"/api/v1/jobs/{job['id']}/voice-notes", headers=auth(owner))).json()
    assert (
        lst["meta"]["counts"] == {"all": 1, "audio": 1, "typed": 0}
        and lst["data"][0]["excerpt"] == "Gas topped up, filter cleaned."
    )
    proof = (await client.get(f"/api/v1/jobs/{job['id']}/proof", headers=auth(tech))).json()
    assert next(s for s in proof["steps"] if s["key"] == "voice")["count"] == 1


async def test_unclear_note_can_be_retried(client, setup, fake_ai):
    tech = setup["tech"]
    job, _ = await started_job_with(client, setup, [])
    fake_ai.text, fake_ai.confidence = "uh", 0.2
    v = (await _voice(client, tech, job["id"])).json()
    assert v["status"] == "unclear"
    fake_ai.text, fake_ai.confidence, fake_ai.language = "Compressor makes a loud noise", 0.95, "en"
    r = await client.post(
        f"/api/v1/voice-notes/{v['id']}/retranscribe", json={"language_hint": "en"}, headers=auth(tech)
    )
    assert r.json()["status"] == "transcribed" and r.json()["transcript_translated"] is None


async def test_typed_note_when_mic_is_off(client, setup, fake_ai):
    tech = setup["tech"]
    async with SessionLocal() as db:  # technician uses the app in Gujarati
        await db.execute(
            text("UPDATE users SET app_language = 'gu' WHERE id = :id"), {"id": tech["user"]["id"]}
        )
        await db.commit()
    job, _ = await started_job_with(client, setup, [])
    r = await client.post(
        f"/api/v1/jobs/{job['id']}/notes", json={"text": "ફિલ્ટર સાફ કર્યું"}, headers=auth(tech)
    )
    v = r.json()
    assert (
        r.status_code == 201
        and v["kind"] == "typed"
        and v["status"] == "transcribed"
        and v["audio_url"] is None
    )
    v = (await client.get(f"/api/v1/voice-notes/{v['id']}", headers=auth(tech))).json()
    assert v["transcript_translated"] == "[en] ફિલ્ટર સાફ કર્યું"


async def test_voice_note_rules_and_lock(client, setup):
    owner, tech = setup["owner"], setup["tech"]
    other = await invite_and_join(client, owner, TECH2)
    j = await new_job(client, owner, setup["customer"], assigned_to=tech["user"]["id"])
    assert (await _voice(client, tech, j["id"])).json()["error"]["code"] == "job_not_started"
    await client.post(f"/api/v1/jobs/{j['id']}/start", headers=auth(tech))
    too_long = await client.post(
        f"/api/v1/jobs/{j['id']}/voice-notes",
        json={"upload_id": str(uuid.uuid4()), "duration_s": 601, "recorded_at": now_iso()},
        headers=auth(tech),
    )
    assert too_long.status_code == 422
    photo_slot = await upload(client, tech, jpeg())  # an upload made for a photo can't be a voice note
    r = await client.post(
        f"/api/v1/jobs/{j['id']}/voice-notes",
        json={"upload_id": photo_slot, "duration_s": 5, "recorded_at": now_iso()},
        headers=auth(tech),
    )
    assert r.status_code == 404
    key = str(uuid.uuid4())
    a = (await _voice(client, tech, j["id"], client_uuid=key)).json()
    b = await _voice(client, tech, j["id"], client_uuid=key)
    assert b.status_code == 200 and b.json()["id"] == a["id"]
    assert (await client.get(f"/api/v1/voice-notes/{a['id']}", headers=auth(other))).status_code == 404
    async with SessionLocal() as db:
        await lock_job_evidence(db, uuid.UUID(j["id"]))
        await db.commit()
    r = await client.patch(
        f"/api/v1/voice-notes/{a['id']}", json={"transcript_edited": "x"}, headers=auth(tech)
    )
    assert r.status_code == 409 and r.json()["error"]["code"] == "evidence_locked"
    assert (await client.delete(f"/api/v1/voice-notes/{a['id']}", headers=auth(tech))).status_code == 409
    async with SessionLocal() as db:  # transcription may still finish after lock, but nothing else changes
        await db.execute(
            text("UPDATE voice_notes SET status = 'transcribed', transcript_original = 'ok' WHERE id = :id"),
            {"id": a["id"]},
        )
        await db.commit()
        with pytest.raises(Exception, match="evidence_locked"):
            await db.execute(text("UPDATE voice_notes SET duration_s = 1 WHERE id = :id"), {"id": a["id"]})
            await db.commit()


# ---- isolation -------------------------------------------------------------------------------------------
async def test_companies_never_see_each_others_checklists_or_notes(client, setup):
    owner, tech = setup["owner"], setup["tech"]
    t = (
        await client.post("/api/v1/checklist-templates", json={"name": "Secret recipe"}, headers=auth(owner))
    ).json()
    job, lists = await started_job_with(client, setup, [(await global_template(client, owner))["id"]])
    note = (
        await client.post(f"/api/v1/jobs/{job['id']}/notes", json={"text": "hello"}, headers=auth(tech))
    ).json()
    b = await make_owner(client, "b@coolfix.in", "CoolFix")
    assert "Secret recipe" not in {
        x["name"] for x in (await client.get("/api/v1/checklist-templates", headers=auth(b))).json()["data"]
    }
    assert (await client.get(f"/api/v1/checklist-templates/{t['id']}", headers=auth(b))).status_code == 404
    assert (
        await client.post(f"/api/v1/checklist-templates/{t['id']}/copy", headers=auth(b))
    ).status_code == 404
    assert (
        await client.get(f"/api/v1/checklist-submissions/{lists[0]['id']}", headers=auth(b))
    ).status_code == 404
    assert (await client.get(f"/api/v1/jobs/{job['id']}/checklists", headers=auth(b))).status_code == 404
    assert (await client.get(f"/api/v1/voice-notes/{note['id']}", headers=auth(b))).status_code == 404
    assert (await client.get(f"/api/v1/jobs/{job['id']}/voice-notes", headers=auth(b))).status_code == 404


async def test_dictation_turns_a_recording_into_words(client, setup, fake_ai):
    owner = setup["owner"]
    fake_ai.text, fake_ai.language = "Is the condensate drain clear?", "en"
    up = await upload(client, owner, b"fake m4a audio bytes", kind="audio", content_type="audio/mp4")
    r = await client.post(
        "/api/v1/dictation", json={"upload_id": up, "language_hint": "en"}, headers=auth(owner)
    )
    assert r.status_code == 200, r.text
    assert r.json() == {"text": "Is the condensate drain clear?", "language": "en"}
    # an upload is used once
    again = await client.post("/api/v1/dictation", json={"upload_id": up}, headers=auth(owner))
    assert again.status_code == 409
    # nothing heard
    fake_ai.text = "  "
    up = await upload(client, owner, b"silence", kind="audio", content_type="audio/mp4")
    r = await client.post("/api/v1/dictation", json={"upload_id": up}, headers=auth(owner))
    assert r.status_code == 422 and r.json()["error"]["code"] == "unclear"
    # a photo upload is not a recording
    up = await upload(client, owner, jpeg())
    r = await client.post("/api/v1/dictation", json={"upload_id": up}, headers=auth(owner))
    assert r.status_code == 404
    async with SessionLocal() as db:
        n = (await db.execute(text("select count(*) from ai_usage where task = 'transcription'"))).scalar()
    assert n == 2


async def test_dictation_without_ai(client, setup):
    owner = setup["owner"]
    up = await upload(client, owner, b"fake m4a audio bytes", kind="audio", content_type="audio/mp4")
    r = await client.post("/api/v1/dictation", json={"upload_id": up}, headers=auth(owner))
    assert r.status_code == 503 and r.json()["error"]["code"] == "ai_unavailable"
