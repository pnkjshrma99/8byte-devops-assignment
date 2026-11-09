"""Application configuration loaded from environment variables."""

import os
from urllib.parse import quote_plus


def _database_uri() -> str:
    """Prefer an explicit DATABASE_URL, otherwise build one from DB_* values."""
    explicit = os.getenv("DATABASE_URL")
    if explicit:
        return explicit

    host = os.getenv("DB_HOST", "localhost")
    port = os.getenv("DB_PORT", "5432")
    name = os.getenv("DB_NAME", "app")
    user = quote_plus(os.getenv("DB_USER", "app"))
    password = quote_plus(os.getenv("DB_PASSWORD", "app"))
    sslmode = os.getenv("DB_SSLMODE", "")
    query = f"?sslmode={quote_plus(sslmode)}" if sslmode else ""
    return f"postgresql+psycopg://{user}:{password}@{host}:{port}/{name}{query}"


class Config:
    SECRET_KEY = os.getenv("SECRET_KEY", "local-dev-only-change-me")
    SQLALCHEMY_DATABASE_URI = _database_uri()
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        "pool_pre_ping": True,
        "pool_recycle": 300,
    }
    MAX_CONTENT_LENGTH = 1024 * 1024

    APP_ENV = os.getenv("APP_ENV", "local")
    APP_VERSION = os.getenv("APP_VERSION", "dev")
    SERVICE_NAME = os.getenv("SERVICE_NAME", "8byte-app")
    LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
    EMF_ENABLED = os.getenv("EMF_ENABLED", "true").lower() == "true"
    METRICS_NAMESPACE = os.getenv("METRICS_NAMESPACE", "8Byte/App")
