#!/bin/sh
set -eu

if [ "${AUTO_MIGRATE:-false}" = "true" ]; then
  echo "running database bootstrap"
  python -m app.init_db
fi

exec gunicorn --config /app/gunicorn.conf.py "app:create_app()"
