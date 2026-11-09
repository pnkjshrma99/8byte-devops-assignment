def test_create_list_and_get_item(client):
    created = client.post("/api/items", json={"name": "demo", "description": "hello"})
    assert created.status_code == 201
    item = created.get_json()
    assert item["name"] == "demo"
    assert created.headers["Location"].endswith(f"/api/items/{item['id']}")

    listed = client.get("/api/items")
    assert listed.status_code == 200
    assert listed.get_json()["count"] == 1

    fetched = client.get(f"/api/items/{item['id']}")
    assert fetched.status_code == 200
    assert fetched.get_json()["description"] == "hello"


def test_update_item(client, item):
    response = client.put(f"/api/items/{item['id']}", json={"name": "updated"})
    assert response.status_code == 200
    assert response.get_json()["name"] == "updated"


def test_delete_item(client, item):
    response = client.delete(f"/api/items/{item['id']}")
    assert response.status_code == 204
    assert client.get(f"/api/items/{item['id']}").status_code == 404


def test_create_requires_non_empty_name(client):
    response = client.post("/api/items", json={"name": "  "})
    assert response.status_code == 400
    assert "name" in response.get_json()["error"]


def test_create_rejects_invalid_payload(client):
    assert client.post("/api/items", json=["not-an-object"]).status_code == 400
    assert client.post("/api/items", json={"name": "x" * 121}).status_code == 400


def test_missing_item_returns_404(client):
    response = client.get("/api/items/9999")
    assert response.status_code == 404
    assert response.get_json()["error"] == "not_found"


def test_unknown_route_returns_json_404(client):
    response = client.get("/does-not-exist")
    assert response.status_code == 404
    assert response.is_json
