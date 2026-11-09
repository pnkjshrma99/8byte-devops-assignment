"""Create the database schema; used by the container entrypoint."""

from . import create_app
from .db import init_db

app = create_app()
init_db(app)
