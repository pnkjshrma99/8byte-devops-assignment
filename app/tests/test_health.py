def test_index_reports_service_metadata(client):
    response = client.get("/")
    assert response.status_code == 200
    body = response.get_json()
    assert body["status"] == "ok"
    assert body["service"] == "8byte-app"


def test_liveness_does_not_require_database(client):
    response = client.get("/health/live")
    assert response.status_code == 200
    assert response.get_json()["status"] == "ok"


def test_readiness_checks_database(client):
    response = client.get("/health/ready")
    assert response.status_code == 200
    assert response.get_json()["database"] == "reachable"


def test_request_id_is_echoed(client):
    response = client.get("/", headers={"X-Request-ID": "test-request-123"})
    assert response.headers["X-Request-ID"] == "test-request-123"


def test_prometheus_metrics_are_exposed(client):
    client.get("/api/items")
    response = client.get("/metrics")
    assert response.status_code == 200
    assert b"http_requests_total" in response.data
