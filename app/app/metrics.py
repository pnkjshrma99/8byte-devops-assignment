"""Prometheus metrics + CloudWatch Embedded Metric Format (EMF)."""

import logging
import time
import uuid

from flask import Flask, Response, g, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency",
    ["method", "endpoint"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10),
)

LOGGER = logging.getLogger("app.requests")
SKIP_PATHS = {"/metrics", "/health/live", "/health/ready"}


def _emf_payload(app: Flask, method: str, endpoint: str, status: int, latency_ms: float) -> dict:
    now_ms = int(time.time() * 1000)
    return {
        "_aws": {
            "Timestamp": now_ms,
            "CloudWatchMetrics": [
                {
                    "Namespace": app.config["METRICS_NAMESPACE"],
                    "Dimensions": [["Service", "Environment"]],
                    "Metrics": [
                        {"Name": "RequestCount", "Unit": "Count"},
                        {"Name": "ErrorCount", "Unit": "Count"},
                        {"Name": "ClientErrorCount", "Unit": "Count"},
                        {"Name": "Latency", "Unit": "Milliseconds"},
                    ],
                }
            ],
        },
        "Service": app.config["SERVICE_NAME"],
        "Environment": app.config["APP_ENV"],
        "RequestCount": 1,
        "ErrorCount": 1 if status >= 500 else 0,
        "ClientErrorCount": 1 if 400 <= status < 500 else 0,
        "Latency": round(latency_ms, 3),
        "Method": method,
        "Path": endpoint,
        "StatusCode": status,
    }


def register_observability(app: Flask) -> None:
    @app.before_request
    def start_request() -> None:
        g.request_id = (request.headers.get("X-Request-ID") or uuid.uuid4().hex)[:64]
        g.request_start = time.perf_counter()

    @app.after_request
    def finish_request(response: Response) -> Response:
        response.headers["X-Request-ID"] = g.get("request_id", "")
        if request.path in SKIP_PATHS:
            return response

        elapsed = time.perf_counter() - g.get("request_start", time.perf_counter())
        endpoint = request.url_rule.rule if request.url_rule else request.path
        status = response.status_code

        REQUEST_COUNT.labels(request.method, endpoint, str(status)).inc()
        REQUEST_LATENCY.labels(request.method, endpoint).observe(elapsed)

        extra = {"request_id": g.get("request_id")}
        if app.config.get("EMF_ENABLED", True):
            extra["emf"] = _emf_payload(app, request.method, endpoint, status, elapsed * 1000)

        LOGGER.info(
            "request completed method=%s path=%s status=%s duration_ms=%.2f",
            request.method,
            request.path,
            status,
            elapsed * 1000,
            extra=extra,
        )
        return response

    @app.get("/metrics")
    def prometheus_metrics() -> Response:
        return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)
