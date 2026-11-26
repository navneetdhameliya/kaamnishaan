"""D-147: the plan switches on the AI assistant, your own checklists and the company's logo on the PDF;
a company on trial has them all."""

from types import SimpleNamespace as N

from sqlalchemy import text

from app.core.db import engine
from app.services import plan_features
from tests.conftest import auth, invite_and_join
from tests.test_reports import ready  # noqa: F401 - the `ready` fixture


async def _on_plan(company_id: str, plan: str) -> None:
    async with engine.begin() as c:
        await c.execute(
            text("update companies set status = 'active', plan_code = :p where id = :id"),
            {"p": plan, "id": company_id},
        )


async def test_trial_has_everything_then_the_plan_decides(client, ready):
    owner = ready["owner"]
    me = (await client.get("/api/v1/me", headers=auth(owner))).json()
    assert me["company"]["status"] == "trial"
    assert sorted(me["company"]["features"]) == [
        "ai_assistant",
        "branded_pdf",
        "custom_checklists",
        "manager_approvals",
    ]

    await _on_plan(me["company"]["id"], "starter")
    me = (await client.get("/api/v1/me", headers=auth(owner))).json()
    assert me["company"]["features"] == ["branded_pdf"]
    # D-148: on Starter only the owner approves; managers still see, edit and share
    manager = await invite_and_join(client, owner, "+919811100077", role="manager")
    perms = (await client.get("/api/v1/me", headers=auth(manager))).json()["permissions"]
    assert "reports.approve" not in perms and {"reports.edit", "reports.share"} <= set(perms)
    assert "reports.approve" in me["permissions"]

    r = await client.post("/api/v1/assistant/ask", json={"text": "How many jobs?"}, headers=auth(owner))
    assert r.status_code == 402
    assert r.json()["error"]["code"] == "plan_feature_needed"
    assert r.json()["error"]["details"] == {
        "feature": "ai_assistant",
        "plan": "starter",
        "needs_plan": "professional",
    }

    r = await client.post("/api/v1/checklist-templates", json={"name": "Filters"}, headers=auth(owner))
    assert r.status_code == 402 and r.json()["error"]["details"]["needs_plan"] == "business"
    # the built-in checklists are still there to use
    assert (await client.get("/api/v1/checklist-templates", headers=auth(owner))).status_code == 200

    await _on_plan(me["company"]["id"], "business")
    perms = (await client.get("/api/v1/me", headers=auth(manager))).json()["permissions"]
    assert "reports.approve" in perms
    r = await client.post("/api/v1/checklist-templates", json={"name": "Filters"}, headers=auth(owner))
    assert r.status_code == 201, r.text


def test_free_plan_pdf_is_not_branded():
    free = N(
        status="active",
        plan_code="free",
        plan=N(code="free", features={"ai_reports": True, "support": "email"}),
    )
    starter = N(status="active", plan_code="starter", plan=N(code="starter", features={"branded_pdf": True}))
    trial = N(status="trial", plan_code="free", plan=free.plan)
    assert not plan_features.has(free, "branded_pdf")
    assert plan_features.has(starter, "branded_pdf") and plan_features.has(trial, "custom_checklists")
    assert plan_features.features(N(status="active", plan_code="x", plan=None)) == []
