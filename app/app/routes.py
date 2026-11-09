"""HTTP API routes."""

from __future__ import annotations

from flask import Blueprint, current_app, jsonify, request, url_for
from sqlalchemy.exc import SQLAlchemyError

from .db import Item, check_db, db

api = Blueprint("api", __name__)


def _validate_item(payload: object, partial: bool = False) -> tuple[dict, str | None]:
    if not isinstance(payload, dict):
        return {}, "request body must be a JSON object"

    name = payload.get("name")
    description = payload.get("description")

    if not partial or "name" in payload:
        if not isinstance(name, str) or not name.strip():
            return {}, "name is required and must be a non-empty string"
        if len(name.strip()) > 120:
            return {}, "name must be at most 120 characters"

    if description is not None and not isinstance(description, str):
        return {}, "description must be a string"
    if isinstance(description, str) and len(description) > 1000:
        return {}, "description must be at most 1000 characters"

    cleaned = {}
    if "name" in payload:
        cleaned["name"] = name.strip()
    if "description" in payload:
        cleaned["description"] = description
    if not cleaned:
        return {}, "at least one field is required"
    return cleaned, None


@api.get("/")
def index():
    return jsonify(
        {
            "service": current_app.config["SERVICE_NAME"],
            "version": current_app.config["APP_VERSION"],
            "environment": current_app.config["APP_ENV"],
            "status": "ok",
            "endpoints": [
                "GET /health/live",
                "GET /health/ready",
                "GET /metrics",
                "GET /api/items",
                "POST /api/items",
                "GET /api/items/<id>",
                "PUT /api/items/<id>",
                "DELETE /api/items/<id>",
            ],
        }
    )


@api.get("/health/live")
def liveness():
    return jsonify({"status": "ok"})


@api.get("/health/ready")
def readiness():
    try:
        check_db()
    except Exception:
        current_app.logger.exception("readiness check failed")
        return jsonify({"status": "unavailable", "database": "unreachable"}), 503
    return jsonify({"status": "ok", "database": "reachable"})


@api.get("/api/items")
def list_items():
    items = db.session.execute(db.select(Item).order_by(Item.id)).scalars().all()
    return jsonify({"items": [item.to_dict() for item in items], "count": len(items)})


@api.post("/api/items")
def create_item():
    data, error = _validate_item(request.get_json(silent=True))
    if error:
        return jsonify({"error": error}), 400

    item = Item(name=data["name"], description=data.get("description"))
    try:
        db.session.add(item)
        db.session.commit()
    except SQLAlchemyError:
        db.session.rollback()
        current_app.logger.exception("failed to create item")
        return jsonify({"error": "database_error"}), 500

    response = jsonify(item.to_dict())
    response.status_code = 201
    response.headers["Location"] = url_for("api.get_item", item_id=item.id)
    return response


@api.get("/api/items/<int:item_id>")
def get_item(item_id: int):
    item = db.session.get(Item, item_id)
    if item is None:
        return jsonify({"error": "not_found"}), 404
    return jsonify(item.to_dict())


@api.put("/api/items/<int:item_id>")
def update_item(item_id: int):
    item = db.session.get(Item, item_id)
    if item is None:
        return jsonify({"error": "not_found"}), 404

    data, error = _validate_item(request.get_json(silent=True), partial=True)
    if error:
        return jsonify({"error": error}), 400

    for key, value in data.items():
        setattr(item, key, value)

    try:
        db.session.commit()
    except SQLAlchemyError:
        db.session.rollback()
        current_app.logger.exception("failed to update item")
        return jsonify({"error": "database_error"}), 500
    return jsonify(item.to_dict())


@api.delete("/api/items/<int:item_id>")
def delete_item(item_id: int):
    item = db.session.get(Item, item_id)
    if item is None:
        return jsonify({"error": "not_found"}), 404

    try:
        db.session.delete(item)
        db.session.commit()
    except SQLAlchemyError:
        db.session.rollback()
        current_app.logger.exception("failed to delete item")
        return jsonify({"error": "database_error"}), 500
    return "", 204


@api.app_errorhandler(404)
def not_found(_error):
    return jsonify({"error": "not_found"}), 404


@api.app_errorhandler(405)
def method_not_allowed(_error):
    return jsonify({"error": "method_not_allowed"}), 405


@api.app_errorhandler(413)
def payload_too_large(_error):
    return jsonify({"error": "payload_too_large"}), 413


@api.app_errorhandler(500)
def internal_error(_error):
    return jsonify({"error": "internal_server_error"}), 500
