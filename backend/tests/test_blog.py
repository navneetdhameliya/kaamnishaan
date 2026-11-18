"""Website blog (W25/W26) and newsletter sign-up."""


async def test_blog_list_has_a_featured_post_and_the_rest(client) -> None:
    r = await client.get("/api/v1/public/blog?locale=hi")
    assert r.status_code == 200
    assert r.headers["cache-control"] == "public, max-age=300"
    body = r.json()
    f = body["featured"]
    assert f and f["slug"] == "how-to-write-a-service-report-customers-trust" and f["language"] == "hi"
    assert all(p["slug"] != f["slug"] for p in body["items"])
    dates = [p["published_on"] for p in body["items"]]
    assert dates == sorted(dates, reverse=True) and len(dates) >= 6
    assert all(p["read_minutes"] >= 1 and p["cover"].startswith("/img/") for p in body["items"])
    assert "reports" in body["categories"] and "hvac" in body["categories"]
    hvac = (await client.get("/api/v1/public/blog?category=hvac")).json()
    assert hvac["featured"] is None and {p["category"] for p in hvac["items"]} == {"hvac"}
    assert (await client.get("/api/v1/public/blog?category=cars")).status_code == 422


async def test_blog_article_with_blocks_and_related(client) -> None:
    r = await client.get("/api/v1/public/blog/how-photo-proof-wins-hvac-disputes?locale=gu")
    assert r.status_code == 200
    post = r.json()
    assert post["language"] == "gu" and post["author"] and post["blocks"]
    assert {b["type"] for b in post["blocks"]} >= {"p", "h2", "list"}
    assert len(post["related"]) == 3 and all(p["slug"] != post["slug"] for p in post["related"])
    missing = await client.get("/api/v1/public/blog/nope")
    assert missing.status_code == 404 and missing.json()["error"]["code"] == "post_not_found"


async def test_newsletter_signup_is_stored_once(client) -> None:
    for _ in range(2):
        r = await client.post("/api/v1/public/newsletter", json={"email": "Asha@Example.com", "lang": "hi"})
        assert r.status_code == 201 and r.json() == {"subscribed": True}
    bad = await client.post("/api/v1/public/newsletter", json={"email": "not-an-email"})
    assert bad.status_code == 422
