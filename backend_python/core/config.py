import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Supabase
SUPABASE_URL = os.getenv("SUPA_URL")
# Prefer service-role key for server-side operations; fallback to existing key if not provided
SUPABASE_KEY = os.getenv("SUPA_SERVICE_API") or os.getenv("SUPA_API")

# Gemini
GEMINI_API_KEY = os.getenv("GEMINI_API")