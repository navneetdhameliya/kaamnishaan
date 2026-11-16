import pytest
from sqlalchemy import text

from app.core.db import SessionLocal
from app.providers.ai import AIProvider, Draft, set_ai_for_tests
from tests.conftest import auth, invite_and_join, make_owner
from tests.test_customers_jobs import new_customer, new_job
from tests.test_evidence import TECH, add_photo

TECH2 = "+919898989898"


class FakeAI(AIProvider):
    """Writes a short draft that links to the first photo it sees; can be told to fail."""

    def __init__(self):
        self.fail = False
        self.calls: list[str] = []

    async def draft_report(self, system_prompt, evidence):
        self.calls.append(system_prompt)
        if self.fail:
            raise RuntimeError("AI is down")
        photo = evidence["photos"][0]["id"]
        return Draft(
            data={
                "summary": "AC serviced and cooling well.",
                "work_done": ["Cleaned the filters.", "Checked the gas pressure."],
                "advice": ["Service again in 6 months."],
                "links": [
                    {"section": "work_done", "text": "Cleaned the filters.", "refs": [f"photo:{photo}"]},
                    {"section": "work_done", "text": "Checked the gas pressure.", "refs": ["photo:made-up"]},
                ],
                "flags": [],
            },
            model="gpt-4o-mini",
            tokens_in=1200,
            tokens_out=300,
        )


@pytest.fixture
def fake_ai():
    ai = FakeAI()
    set_ai_for_tests(ai)
    yield ai
    set_ai_for_tests(None)


@pytest.fixture
async def ready(client):
    """A started job with before and after photos, ready for its report."""
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, TECH)
    c = await new_customer(client, owner)
    j = await new_job(client, owner, c, assigned_to=tech["user"]["id"])
    assert (await client.post(f"/api/v1/jobs/{j['id']}/start", headers=auth(tech))).status_code == 200
    for stage in ("before", "after"):
        assert (await add_photo(client, tech, j["id"], stage)).status_code == 201
    return {"owner": owner, "tech": tech, "job": j, "customer": c}


async def make_report(client, who, job_id):
    r = await client.post(f"/api/v1/jobs/{job_id}/reports", headers=auth(who))
    assert r.status_code == 202, r.text
    started = r.json()
    task = (await client.get(f"/api/v1/tasks/{started['task_id']}", headers=auth(who))).json()
    rep = (await client.get(f"/api/v1/reports/{started['report_id']}", headers=auth(who))).json()
    return started, task, rep


# ---- making the draft ------------------------------------------------------------------------------
async def test_ai_draft_links_sentences_to_evidence(client, ready, fake_ai):
    tech = ready["tech"]
    started, task, rep = await make_report(client, tech, ready["job"]["id"])
    assert task["status"] == "done" and [s["status"] for s in task["steps"]] == ["done"] * 3
    assert [s["key"] for s in task["steps"]] == ["collect_evidence", "write_report", "check_evidence"]
    assert rep["status"] == "draft" and rep["number"] == "R-1001" and rep["drafted_by"] == "ai"
    assert rep["work_done"] == "Cleaned the filters.\nChecked the gas pressure."
    assert rep["evidence"]["photos"] == {"before": 1, "during": 0, "after": 1}
    good, bad = rep["links"]
    assert good["refs"] and bad["refs"] == []  # an id the AI made up is dropped...
    assert {"kind": "unsupported_claim", "text": "Checked the gas pressure.", "ref": None} in rep["flags"]
    assert set(rep["actions"]) == {"edit", "regenerate", "redraft", "submit"}
    assert "English" in fake_ai.calls[0] and "{language}" not in fake_ai.calls[0]
    async with SessionLocal() as db:
        cost = (await db.execute(text("SELECT sum(cost_usd) FROM ai_usage"))).scalar_one()
    assert cost > 0
    # asking again while it's done and still a draft makes a new draft (redraft)
    again = (await client.post(f"/api/v1/jobs/{ready['job']['id']}/reports", headers=auth(tech))).json()
    assert again["report_id"] == started["report_id"] and again["task_id"] != started["task_id"]


async def test_without_ai_a_plain_draft_is_written(client, ready):
    proof_url = f"/api/v1/jobs/{ready['job']['id']}/proof"
    assert (await client.get(proof_url, headers=auth(ready["tech"]))).json()["report"] is None
    _, _, rep = await make_report(client, ready["tech"], ready["job"]["id"])
    # the proof screen now knows the report, so the app opens it instead of making a new one
    ref = (await client.get(proof_url, headers=auth(ready["tech"]))).json()["report"]
    assert ref == {"id": rep["id"], "number": "R-1001", "status": "draft"}
    assert rep["status"] == "draft" and rep["drafted_by"] == "template"
    assert rep["summary"].startswith(ready["job"]["title"])
    assert "2 photos were taken" in rep["work_done"]
    assert rep["section_sources"] == {"summary": "template", "work_done": "template", "advice": "template"}


async def test_report_needs_before_and_after_photos(client):
    owner = await make_owner(client)
    tech = await invite_and_join(client, owner, TECH)
    c = await new_customer(client, owner)
    j = await new_job(client, owner, c, assigned_to=tech["user"]["id"])
    await client.post(f"/api/v1/jobs/{j['id']}/start", headers=auth(tech))
    await add_photo(client, tech, j["id"], "before")
    r = await client.post(f"/api/v1/jobs/{j['id']}/reports", headers=auth(tech))
    assert r.status_code == 409 and r.json()["error"]["code"] == "report_not_ready"
    assert r.json()["error"]["details"]["blocked_by"] == "need_after_photo"


async def test_ai_failure_keeps_evidence_and_allows_retry(client, ready, fake_ai):
    fake_ai.fail = True
    started, task, rep = await make_report(client, ready["tech"], ready["job"]["id"])
    assert task["status"] == "failed" and task["steps"][1]["status"] == "failed"
    assert rep["status"] == "generation_failed" and "AI is down" in rep["error"]
    fake_ai.fail = False
    _, task2, rep2 = await make_report(client, ready["tech"], ready["job"]["id"])
    assert task2["status"] == "done" and rep2["status"] == "draft" and rep2["error"] is None
    assert rep2["id"] == started["report_id"]


# ---- editing and versions ----------------------------------------------------------------------------
async def test_edit_with_version_check_and_history(client, ready):
    tech = ready["tech"]
    _, _, rep = await make_report(client, tech, ready["job"]["id"])
    url = f"/api/v1/reports/{rep['id']}"
    r = await client.patch(
        url, json={"summary": "Serviced the AC."}, headers={**auth(tech), "If-Match": "999"}
    )
    assert r.status_code == 409 and r.json()["error"]["code"] == "version_conflict"
    r = await client.patch(
        url, json={"summary": "Serviced the AC."}, headers={**auth(tech), "If-Match": str(rep["version"])}
    )
    assert r.status_code == 200 and r.json()["summary"] == "Serviced the AC."
    assert r.json()["section_sources"]["summary"] == "technician"
    regen = await client.post(f"{url}/sections/advice/regenerate", headers=auth(tech))
    assert regen.status_code == 202
    after = (await client.get(url, headers=auth(tech))).json()
    assert after["summary"] == "Serviced the AC."  # only advice was rewritten
    assert (await client.get(f"{url}/versions", headers=auth(tech))).status_code == 403  # managers only
    v = (await client.get(f"{url}/versions", headers=auth(ready["owner"]))).json()["data"]
    assert [x["event"] for x in v] == ["drafted", "edited", "regenerated"]
    assert v[1]["edited_by"]["id"] == tech["user"]["id"]
    # the work done can't be left empty
    r = await client.patch(url, json={"work_done": " "}, headers=auth(tech))
    assert r.status_code == 400 and r.json()["error"]["code"] == "section_empty"
    assert r.json()["error"]["fields"] == {"work_done": "empty"}


# ---- review ----------------------------------------------------------------------------------------
async def test_submit_locks_evidence_then_manager_approves(client, ready):
    tech, owner, job = ready["tech"], ready["owner"], ready["job"]
    _, _, rep = await make_report(client, tech, job["id"])
    r = await client.post(f"/api/v1/reports/{rep['id']}/submit", headers=auth(tech))
    assert r.status_code == 200 and r.json()["status"] == "pending_review" and r.json()["actions"] == []
    j = (await client.get(f"/api/v1/jobs/{job['id']}", headers=auth(owner))).json()
    assert j["status"] == "in_review"
    assert (await add_photo(client, tech, job["id"], "after")).status_code == 409  # evidence locked
    r = await client.patch(f"/api/v1/reports/{rep['id']}", json={"summary": "x"}, headers=auth(tech))
    assert r.status_code == 409 and r.json()["error"]["code"] == "report_locked"
    # technicians can't approve
    assert (await client.post(f"/api/v1/reports/{rep['id']}/approve", headers=auth(tech))).status_code == 403
    queue = (await client.get("/api/v1/reports?status=pending_review", headers=auth(owner))).json()
    assert queue["data"][0]["id"] == rep["id"] and queue["data"][0]["waiting_minutes"] == 0
    assert queue["meta"]["counts"]["pending_review"] == 1
    brief = queue["data"][0]["job"]
    assert brief["photos"] >= 2 and brief["cover_url"]  # M13 "6 photos" and the picture
    r = await client.post(f"/api/v1/reports/{rep['id']}/approve", headers=auth(owner))
    assert r.status_code == 200 and r.json()["status"] == "approved"
    assert r.json()["approved_by"]["id"] == owner["user"]["id"]
    j = (await client.get(f"/api/v1/jobs/{job['id']}", headers=auth(owner))).json()
    assert j["status"] == "completed"
    r = await client.post(f"/api/v1/reports/{rep['id']}/approve", headers=auth(owner))
    assert r.status_code == 409 and r.json()["error"]["code"] == "invalid_transition"


async def test_changes_requested_then_fixed_and_resent(client, ready):
    tech, owner, job = ready["tech"], ready["owner"], ready["job"]
    _, _, rep = await make_report(client, tech, job["id"])
    url = f"/api/v1/reports/{rep['id']}"
    await client.post(f"{url}/submit", headers=auth(tech))
    r = await client.post(f"{url}/request-changes", json={"reasons": ["other"]}, headers=auth(owner))
    assert r.status_code == 400 and r.json()["error"]["fields"] == {"note": "required"}
    r = await client.post(
        f"{url}/request-changes",
        json={"reasons": ["missing_photos"], "note": "Add a photo of the outdoor unit"},
        headers=auth(owner),
    )
    assert r.status_code == 200 and r.json()["status"] == "changes_requested"
    mine = (await client.get("/api/v1/reports?mine=true", headers=auth(tech))).json()["data"][0]
    assert mine["change_note"] == "Add a photo of the outdoor unit"
    # new proof can be added and the report made again
    assert (await add_photo(client, tech, job["id"], "after")).status_code == 201
    _, _, again = await make_report(client, tech, job["id"])
    assert again["status"] == "changes_requested" and again["evidence"]["photos"]["after"] == 2
    r = await client.post(f"{url}/submit", headers=auth(tech))
    assert r.status_code == 200 and r.json()["status"] == "pending_review"
    assert r.json()["change_requests"][0]["resolved_at"] is not None


# ---- who can see what --------------------------------------------------------------------------------
async def test_other_technicians_and_companies_cannot_see(client, ready):
    tech, owner = ready["tech"], ready["owner"]
    _, _, rep = await make_report(client, tech, ready["job"]["id"])
    other = await invite_and_join(client, owner, TECH2)
    assert (await client.get(f"/api/v1/reports/{rep['id']}", headers=auth(other))).status_code == 404
    assert (await client.get("/api/v1/reports", headers=auth(other))).json()["data"] == []
    assert (
        await client.post(f"/api/v1/jobs/{ready['job']['id']}/reports", headers=auth(other))
    ).status_code == 404
    stranger = await make_owner(client, email="boss@coolbreeze.in", company="Cool Breeze")
    assert (await client.get(f"/api/v1/reports/{rep['id']}", headers=auth(stranger))).status_code == 404
    assert (await client.get(f"/api/v1/reports/{rep['id']}", headers=auth(owner))).status_code == 200
