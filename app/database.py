from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os


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
import os as _os
from supabase import create_client as _create_client
supabase = _create_client(
    _os.environ["SUPABASE_URL"],
    _os.environ["SUPABASE_KEY"]
)
