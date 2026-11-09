import os
import tempfile

import pytest

from app import create_app
from app.db import db


@pytest.fixture()
def app():
    handle, path = tempfile.mkstemp(prefix="8byte-test-", suffix=".sqlite")
    os.close(handle)
    application = create_app(
        {
            "TESTING": True,
            "SQLALCHEMY_DATABASE_URI": f"sqlite:///{path}",
            "EMF_ENABLED": False,
            "LOG_LEVEL": "ERROR",
        }
    )
    with application.app_context():
        db.create_all()
        yield application
        db.session.remove()
        db.drop_all()
    os.unlink(path)


@pytest.fixture()
def client(app):
    return app.test_client()


@pytest.fixture()
def item(client):
    response = client.post(
        "/api/items", json={"name": "first item", "description": "created by a fixture"}
    )
    assert response.status_code == 201
    return response.get_json()
