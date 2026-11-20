"""A39 Message templates: staff edit the texts customers get; the next messages use them."""

from sqlalchemy import text

from app.core.db import engine
from app.providers.messaging import outbox
from tests.conftest import auth
from tests.test_admin_ai_calls import due, run
from tests.test_admin_auth import _setup
from tests.test_reports import ready  # noqa: F401 - the `ready` fixture

A = "/api/v1/admin/message-templates"


def find(d, key, channel, lang):
    t = next(x for x in d["templates"] if x["key"] == key)
    return next(x for x in t["texts"] if x["channel"] == channel and x["language"] == lang)


async def test_list_and_defaults(client):
    s, _ = await _setup(client)
    d = (await client.get(A, headers=auth(s))).json()
    assert [t["key"] for t in d["templates"]] == [
        "report_review",
        "review_reminder",
        "day5_sms",
        "report_link",
    ]
    day0 = find(d, "report_review", "sms", "en")
    assert (
        day0["text"] == "{{company}}: report {{report_number}} is ready. Rate the job here: {{link}}"
        and "{{link}}" in day0["text"]
    )
    assert day0["checked"] and not day0["edited"] and not find(d, "report_review", "sms", "hi")["checked"]
    email = find(d, "report_link", "email", "en")
    assert email["subject"] == "Your service report {{report_number}} from {{company}}"
    assert email["body"].startswith("Hello {{customer}},")
    assert d["stop"]["en"] == "Reply STOP to opt out." and d["sms_live"] is False and d["can_act"]
    day5 = next(t for t in d["templates"] if t["key"] == "day5_sms")
    assert day5["channels"] == ["sms"] and "expires" not in day5["placeholders"]


async def test_edit_is_used_for_the_next_day0_and_day5_messages(client, ready):
    s, _ = await _setup(client)
    new = "Hi {{customer}}, {{company}} finished {{job}}. Report and rating: {{link}}"
    r = await client.put(f"{A}/report_review/sms/en", json={"text": new}, headers=auth(s))
    assert r.status_code == 200, r.text
    assert find({"templates": [r.json()]}, "report_review", "sms", "en")["edited"]
    r = await client.put(f"{A}/day5_sms/sms/en", json={"text": "{{company}}: one tap to rate {{job}}: {{link}}"},
                         headers=auth(s))  # fmt: skip
    assert r.status_code == 200
    await due(client, ready)  # approve + ask for a review: the Day 0 SMS goes out
    day0 = next(m for m in outbox.sms if "?rate=1" in m["body"])
    assert day0["body"].startswith("Hi Mr Sharma, BrightAir finished") and day0["body"].endswith(
        "Reply STOP to opt out."
    )
    outbox.clear()
    assert await run(12) == 1  # no voice provider: the Day 5 SMS goes instead
    assert outbox.sms[-1]["body"].startswith("BrightAir: one tap to rate")
    async with engine.begin() as c:
        n = (
            await c.execute(text("SELECT count(*) FROM audit_logs WHERE action = 'staff.template_updated'"))
        ).scalar_one()
    assert n == 2


async def test_checks_mark_reset_and_test(client):
    s, _ = await _setup(client)

    async def put(path, body):
        return await client.put(f"{A}/{path}", json=body, headers=auth(s))

    bad = await put("report_link/sms/en", {"text": "{{company}} {{price}} {{link}}"})
    assert bad.status_code == 422 and bad.json()["error"]["fields"] == {"text": "unknown_placeholder"}
    assert (await put("report_link/sms/en", {"text": "Your report is ready."})).json()["error"]["fields"] == {
        "text": "needs_link"
    }
    assert (await put("report_link/sms/en", {"text": "Report: {{link}} Reply STOP"})).json()["error"]["fields"] == {
        "text": "stop_added_automatically"}  # fmt: skip
    assert (await put("report_link/sms/en", {"text": "Until {{expires}}: {{link}}"})).json()["error"]["fields"] == {
        "text": "unknown_placeholder"}  # fmt: skip
    assert (await put("report_link/email/en", {"subject": "", "body": "{{link}}"})).json()["error"]["fields"] == {
        "subject": "required"}  # fmt: skip
    assert (await put("day5_sms/email/en", {"subject": "x", "body": "{{link}}"})).status_code == 404

    r = await client.post(f"{A}/report_review/sms/hi/check", headers=auth(s))
    assert find({"templates": [r.json()]}, "report_review", "sms", "hi")["checked"]
    await put("report_review/sms/hi", {"text": "{{company}}: रिपोर्ट {{link}}"})
    r = await client.delete(f"{A}/report_review/sms/hi", headers=auth(s))
    hi = find({"templates": [r.json()]}, "report_review", "sms", "hi")
    assert not hi["edited"] and not hi["checked"] and "{{report_number}}" in hi["text"]

    link = next(
        x for x in (await client.get(A, headers=auth(s))).json()["templates"] if x["key"] == "report_review"
    )["sample"]["link"]
    assert link.endswith("?rate=1") and len(link) > 60
    t = await client.post(f"{A}/test", json={"template": "report_review", "channel": "sms", "language": "en",
                                            "to": "98250 22222", "text": "Hello {{customer}}: {{link}}"},
                          headers=auth(s))  # fmt: skip
    assert t.status_code == 200 and t.json() == {
        "sent": False, "to": "+919825022222", "text": f"Hello Anita Rao: {link} Reply STOP to opt out.",
        "subject": None, "body": None,
    }  # fmt: skip
    e = await client.post(f"{A}/test", json={"template": "report_link", "channel": "email", "language": "fr",
                                            "to": "me@kaamnishaan.com"}, headers=auth(s))  # fmt: skip
    assert (
        e.status_code == 200
        and e.json()["subject"] == "Votre rapport d'intervention R-1042 de BrightAir Services"
    )
    assert "Anita Rao" in e.json()["body"] and outbox.email[-1]["subject"].startswith("[Test] Votre rapport")
    assert (await client.post(f"{A}/test", json={"template": "report_link", "channel": "email", "language": "en",
                                                 "to": "nope"}, headers=auth(s))).status_code == 422  # fmt: skip

    async with engine.begin() as c:
        await c.execute(text("UPDATE staff_users SET role = 'support'"))
    assert (await client.get(A, headers=auth(s))).json()["can_act"] is False
    assert (await put("report_link/sms/en", {"text": "Report {{link}}"})).status_code == 403


async def test_english_texts_fit_in_one_sms_with_a_real_link(client):
    """SMS over 160 plain characters is billed as 2 or more; with typical names and a real-length link
    (about 76 characters on kaamnishaan.com) the built-in English texts stay within one."""
    from app.services import admin_messages, messages

    for key in messages.TEMPLATES:
        link = admin_messages.sample(key)["link"].replace("http://web.test", "https://kaamnishaan.com")
        values = {**admin_messages.sample(key), "company": "BrightAir", "job": "AC service", "link": link}
        text_ = messages.render({}, key, "sms", "en", **values)["text"]
        assert len(text_) <= 160, (key, len(text_), text_)
