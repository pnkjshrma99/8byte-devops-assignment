"""JSON logging so CloudWatch Logs can index every field."""

import json
import logging
import sys
from datetime import datetime, timezone


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "service": getattr(record, "service", None),
            "environment": getattr(record, "environment", None),
            "request_id": getattr(record, "request_id", None),
        }

        # Embedded Metric Format fields are merged at the root of the JSON
        # object, which is what CloudWatch Logs expects.
        emf = getattr(record, "emf", None)
        if isinstance(emf, dict):
            payload.update(emf)

        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)

        return json.dumps({k: v for k, v in payload.items() if v is not None}, default=str)


def configure_logging(level: str = "INFO") -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())

    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(level.upper())

    # Gunicorn's default access log is unstructured and duplicates the
    # middleware request log.
    logging.getLogger("gunicorn.access").setLevel(logging.WARNING)
    logging.getLogger("werkzeug").setLevel(logging.WARNING)
