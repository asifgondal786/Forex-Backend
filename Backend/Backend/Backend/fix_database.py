import re

db_path = r"D:\Tajir\Backend\app\database.py"
with open(db_path, "r", encoding="utf-8") as f:
    content = f.read()

# Add supabase client at the end if not already present
if "supabase" not in content:
    addition = """
# Supabase client
import os as _os
from supabase import create_client as _create_client
supabase = _create_client(
    _os.environ["SUPABASE_URL"],
    _os.environ["SUPABASE_KEY"]
)
"""
    content += addition
    with open(db_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Supabase client added to database.py")
else:
    print("Supabase already present - no change needed")
