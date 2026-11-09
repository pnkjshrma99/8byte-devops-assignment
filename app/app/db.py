"""Database models and helpers."""

from __future__ import annotations

import time
from datetime import datetime

from flask import Flask
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()


class Item(db.Model):
    __tablename__ = "items"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(120), nullable=False)
    description = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime(timezone=True), nullable=False, server_default=db.func.now())
    updated_at = db.Column(
        db.DateTime(timezone=True),
        nullable=False,
        server_default=db.func.now(),
        onupdate=db.func.now(),
    )

    def to_dict(self) -> dict:
        created_at: datetime | None = self.created_at
        updated_at: datetime | None = self.updated_at
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "created_at": created_at.isoformat() if created_at else None,
            "updated_at": updated_at.isoformat() if updated_at else None,
        }


def init_db(app: Flask, attempts: int = 30, delay_seconds: int = 2) -> None:
    """Create the schema, retrying while the database is still starting."""
    with app.app_context():
        for attempt in range(1, attempts + 1):
            try:
                db.create_all()
                app.logger.info("database schema is ready")
                return
            except Exception:
                app.logger.warning("database not ready (attempt %s/%s)", attempt, attempts)
                if attempt == attempts:
                    raise
                time.sleep(delay_seconds)


def check_db() -> None:
    """Run a cheap query used by the readiness probe."""
    db.session.execute(db.text("SELECT 1"))
