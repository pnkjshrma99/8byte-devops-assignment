"""Integration tests require PostgreSQL.

Set TEST_DATABASE_URL to a disposable database, for example:
  postgresql+psycopg://app:app@localhost:5432/app_test
"""

import os

import pytest

from app import create_app
from app.db import db

pytestmark = pytest.mark.integration


def _test_database_url() -> str:
    url = os.getenv("TEST_DATABASE_URL", "")
    if not url:
        pytest.skip("TEST_DATABASE_URL is not set")
    if "test" not in url:
        pytest.skip("refusing to run destructive integration tests against a non-test database")
    return url


def test_postgres_round_trip():
    application = create_app(
        {
            "TESTING": True,
            "SQLALCHEMY_DATABASE_URI": _test_database_url(),
            "EMF_ENABLED": False,
            "LOG_LEVEL": "ERROR",
        }
    )

    with application.app_context():
        db.drop_all()
        db.create_all()
        try:
            client = application.test_client()
            assert client.get("/health/ready").status_code == 200

            created = client.post(
                "/api/items", json={"name": "postgres", "description": "integration"}
            )
            assert created.status_code == 201
            item_id = created.get_json()["id"]

            fetched = client.get(f"/api/items/{item_id}")
            assert fetched.status_code == 200
            assert fetched.get_json()["name"] == "postgres"
        finally:
            db.session.remove()
            db.drop_all()
