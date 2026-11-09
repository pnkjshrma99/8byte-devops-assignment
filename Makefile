SHELL := /bin/bash
VENV := .venv
PY := $(VENV)/bin/python
PIP := $(VENV)/bin/pip

.PHONY: help venv install test test-integration lint compose-up compose-down run smoke tf-fmt tf-validate docs

help:
	@echo "make install             install Python dependencies"
	@echo "make test                unit tests + lint"
	@echo "make test-integration    integration tests (needs TEST_DATABASE_URL)"
	@echo "make lint                ruff"
	@echo "make compose-up          run app + PostgreSQL with Docker Compose"
	@echo "make compose-down        stop the local stack"
	@echo "make smoke               run the HTTP smoke test against localhost:8000"
	@echo "make tf-fmt              format Terraform"
	@echo "make tf-validate         validate both environment roots (no backend)"
	@echo "make docs                rebuild the challenges PDF/DOCX"

venv:
	python3 -m venv $(VENV)

install: venv
	$(PIP) install -r app/requirements-dev.txt

test: lint
	cd app && ../$(PY) -m pytest -m "not integration" --cov=app --cov-report=term-missing --cov-fail-under=70

test-integration:
	@test -n "$$TEST_DATABASE_URL" || (echo "set TEST_DATABASE_URL" && exit 1)
	cd app && ../$(PY) -m pytest -m integration -q

lint:
	cd app && ../$(VENV)/bin/ruff check app tests

compose-up:
	docker compose up --build

compose-down:
	docker compose down -v

run:
	cd app && ../$(PY) -m flask --app app run --port 8000

smoke:
	./scripts/smoke-test.sh http://localhost:8000

tf-fmt:
	terraform fmt -recursive infra

tf-validate:
	terraform -chdir=infra/environments/staging init -backend=false -input=false >/dev/null
	terraform -chdir=infra/environments/staging validate
	terraform -chdir=infra/environments/production init -backend=false -input=false >/dev/null
	terraform -chdir=infra/environments/production validate

docs:
	$(VENV)/bin/python scripts/build_challenges_doc.py
