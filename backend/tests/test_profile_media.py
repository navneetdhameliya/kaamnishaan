"""M11 "Your work" + profile photo, and the company logo from M07 (step 2b)."""

from tests.conftest import auth, make_owner, phone_login
from tests.test_evidence import jpeg, upload

TECH = "+919812345678"


async def test_save_my_work_and_photo(client):
    s = await phone_login(client, TECH)
    up = await upload(client, s, jpeg(200, 200), kind="avatar")
    r = await client.patch(
        "/api/v1/me", json={"name": "Ravi", "trade": "hvac", "avatar_upload_id": up}, headers=auth(s)
    )
    assert r.status_code == 200, r.text
    me = r.json()
    assert (me["name"], me["trade"]) == ("Ravi", "hvac")
    assert me["avatar_url"]
    assert (await client.get("/api/v1/me", headers=auth(s))).json()["avatar_url"]

    # an upload can only be used once
    r = await client.patch("/api/v1/me", json={"avatar_upload_id": up}, headers=auth(s))
    assert r.status_code == 409

    r = await client.patch("/api/v1/me", json={"remove_avatar": True}, headers=auth(s))
    assert r.json()["avatar_url"] is None


async def test_my_work_must_be_a_known_trade(client):
    s = await phone_login(client, TECH)
    r = await client.patch("/api/v1/me", json={"trade": "plumbing"}, headers=auth(s))
    assert r.status_code == 400 and r.json()["error"]["fields"] == {"trade": "unknown"}


async def test_photo_upload_must_be_an_avatar(client):
    s = await phone_login(client, TECH)
    up = await upload(client, s, jpeg())  # kind photo
    r = await client.patch("/api/v1/me", json={"avatar_upload_id": up}, headers=auth(s))
    assert r.status_code == 404


async def test_owner_adds_company_logo(client):
    owner = await make_owner(client)
    up = await upload(client, owner, jpeg(300, 120), kind="logo", content_type="image/jpeg")
    r = await client.patch("/api/v1/company", json={"logo_upload_id": up}, headers=auth(owner))
    assert r.status_code == 200, r.text
    assert r.json()["logo_url"]
    assert (await client.get("/api/v1/me", headers=auth(owner))).json()["company"]["logo_url"]
