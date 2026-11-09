"""Application factory."""

from __future__ import annotations

from flask import Flask

from .config import Config
from .db import db
from .logging_config import configure_logging
from .metrics import register_observability
from .routes import api


def create_app(config_overrides: dict | None = None) -> Flask:
    app = Flask(__name__)
    app.config.from_object(Config)
    if config_overrides:
        app.config.update(config_overrides)

    configure_logging(app.config["LOG_LEVEL"])
    db.init_app(app)
    app.register_blueprint(api)
    register_observability(app)
    return app
