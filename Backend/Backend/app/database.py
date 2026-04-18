from dotenv import load_dotenv
load_dotenv()
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os
import logging

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL is not set")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

# Supabase client
from supabase import create_client as _create_client

_supabase_url = os.getenv("SUPABASE_URL")
_supabase_key = (
    os.getenv("SUPABASE_ANON_KEY")
    or os.getenv("SUPABASE_KEY")
    or os.getenv("SUPABASE_SERVICE_ROLE_KEY")
)

if _supabase_url and _supabase_key:
    supabase = _create_client(_supabase_url, _supabase_key)
else:
    supabase = None
    logging.warning(
        "Supabase not initialized. URL=%s, KEY=%s",
        "set" if _supabase_url else "MISSING",
        "set" if _supabase_key else "MISSING",
    )

