"""SQLAlchemy 2.0 database engine and session management supporting MySQL 8
(mysql+pymysql://) in production and isolated SQLite databases in unit tests.
"""

from __future__ import annotations

from collections.abc import Generator

from sqlalchemy import create_engine, event
from sqlalchemy.engine import Engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker


class Base(DeclarativeBase):
    pass


def build_engine(database_url: str) -> Engine:
    is_sqlite = database_url.startswith("sqlite:")
    connect_args = {"check_same_thread": False} if is_sqlite else {}
    engine_kwargs: dict = {
        "pool_pre_ping": True,
        "connect_args": connect_args,
    }
    if not is_sqlite:
        # MySQL connection pool hardening
        engine_kwargs["pool_recycle"] = 1800
        engine_kwargs["pool_size"] = 10
        engine_kwargs["max_overflow"] = 20

    engine = create_engine(database_url, **engine_kwargs)

    if is_sqlite:
        @event.listens_for(engine, "connect")
        def _set_sqlite_pragma(dbapi_connection, _connection_record):
            cursor = dbapi_connection.cursor()
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.close()

    return engine


def create_session_factory(engine: Engine) -> sessionmaker[Session]:
    return sessionmaker(
        bind=engine,
        autoflush=False,
        autocommit=False,
        expire_on_commit=False,
    )


def session_dependency(session_factory: sessionmaker[Session]):
    def _get_db() -> Generator[Session, None, None]:
        db = session_factory()
        try:
            yield db
        finally:
            db.close()

    return _get_db
