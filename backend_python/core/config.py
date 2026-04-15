import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Supabase
SUPABASE_URL = os.getenv("SUPA_URL")
# Use anon key for GoTrue auth endpoints (login/signup/auth checks)
SUPABASE_ANON_KEY = os.getenv("SUPA_API")
# Supabase newer projects may provide publishable keys instead of legacy anon keys
SUPABASE_PUBLISHABLE_KEY = os.getenv("SUPA_PUBLISHABLE")
# Use service-role key for server-side DB operations; fallback keeps legacy behavior
SUPABASE_SERVICE_KEY = os.getenv("SUPA_SERVICE_API") or SUPABASE_ANON_KEY
# Backward-compatible alias
SUPABASE_KEY = SUPABASE_SERVICE_KEY

# Gemini
GEMINI_API_KEY = os.getenv("GEMINI_API")