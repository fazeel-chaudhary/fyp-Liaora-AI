from supabase import create_async_client
from core.config import (
    SUPABASE_URL,
    SUPABASE_ANON_KEY,
    SUPABASE_PUBLISHABLE_KEY,
    SUPABASE_SERVICE_KEY,
)
from models.models import (
    Signup,
    Login,
    UserProfile,
    Message,
    StoredChat,
    CustomBot,
    JournalEntry,
    DailyCheckIn,
    MemoryFile,
)
from datetime import datetime
from typing import List, Optional


class SupabaseService:

    def __init__(self):
        self._server_client = None
        self._auth_client = None

    async def get_server_client(self):
        # Server-side DB client (prefer service-role key)
        if self._server_client is None:
            self._server_client = await create_async_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        return self._server_client

    async def get_auth_client(self):
        # Auth client for signup/login/get_user with anon key
        if self._auth_client is None:
            key = SUPABASE_ANON_KEY or SUPABASE_PUBLISHABLE_KEY or SUPABASE_SERVICE_KEY
            if not SUPABASE_URL or not key:
                raise ValueError("Supabase auth configuration is missing")
            if str(key).startswith("sb_publishable_"):
                raise ValueError(
                    "SUPA_API (anon JWT key) is required for Python auth; "
                    "SUPA_PUBLISHABLE is not supported by supabase-py auth yet"
                )
            self._auth_client = await create_async_client(SUPABASE_URL, key)
        return self._auth_client

    # ---------- Auth ----------
    async def signup_user(self, signup_data: Signup) -> dict:
        try:
            auth_client = await self.get_auth_client()
            db_client = await self.get_server_client()
            auth_response = await auth_client.auth.sign_up({
                "email": signup_data.email,
                "password": signup_data.password
            })

            if auth_response.user:
                # Always insert profile row immediately using server client (service key bypasses RLS)
                user_data = {
                    "id": auth_response.user.id,
                    "email": signup_data.email,
                    "name": signup_data.username,
                    "created_at": datetime.now().isoformat()
                }
                # Use upsert to avoid duplicate errors on retries
                await db_client.table("users").upsert(user_data, on_conflict="id").execute()

                access_token = auth_response.session.access_token if auth_response.session else None

                return {
                    "success": True,
                    "user_id": auth_response.user.id,
                    "access_token": access_token,
                    "message": "Signup successful and profile created"
                }

            return {"success": False, "error": "Signup failed"}

        except Exception as e:
            return {"success": False, "error": str(e)}

    async def login_user(self, login_data: Login) -> dict:
        try:
            auth_client = await self.get_auth_client()
            db_client = await self.get_server_client()
            auth_response = await auth_client.auth.sign_in_with_password({
                "email": login_data.email,
                "password": login_data.password
            })

            if auth_response.user and auth_response.session:
                access_token = auth_response.session.access_token
                uid = str(auth_response.user.id)
                # Auth users created outside this app (or before `public.users` existed) have no profile row;
                # `messages.user_id` FK requires a row in `public.users`.
                try:
                    existing = await db_client.table("users").select("id").eq("id", uid).execute()
                    if not existing.data:
                        meta = getattr(auth_response.user, "user_metadata", None) or {}
                        display_name = (
                            meta.get("name")
                            or meta.get("full_name")
                            or login_data.email.split("@", 1)[0]
                        )
                        await db_client.table("users").insert(
                            {
                                "id": uid,
                                "email": login_data.email,
                                "name": str(display_name),
                                "created_at": datetime.now().isoformat(),
                            }
                        ).execute()
                except Exception as profile_err:
                    print(f"ensure public.users row on login: {profile_err}")

                return {
                    "success": True,
                    "user_id": auth_response.user.id,
                    "access_token": access_token,
                }

            if auth_response.user and not auth_response.session:
                return {
                    "success": False,
                    "error": "Email not verified — check your inbox or resend confirmation.",
                }

            return {"success": False, "error": "Invalid email or password"}

        except Exception as e:
            return {"success": False, "error": str(e)}

    async def logout_user(self) -> dict:
        try:
            auth_client = await self.get_auth_client()
            await auth_client.auth.sign_out()
            return {"success": True}
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def ensure_profile_row_for_access_token(
        self, access_token: str, expected_user_id: str
    ) -> dict:
        """Upsert public.users using the caller's JWT so messages.user_id FK can succeed."""
        try:
            auth_client = await self.get_auth_client()
            db_client = await self.get_server_client()
            user_response = await auth_client.auth.get_user(access_token)
            user = user_response.user if user_response else None
            if user is None:
                return {"success": False, "error": "Invalid or expired session"}

            uid = str(user.id)
            if uid != str(expected_user_id):
                return {"success": False, "error": "User id does not match access token"}

            email = user.email or f"{uid[:8]}@session.local"
            meta = getattr(user, "user_metadata", None) or {}
            if not isinstance(meta, dict):
                meta = {}
            display_name = (
                meta.get("name")
                or meta.get("full_name")
                or email.split("@", 1)[0]
            )

            await db_client.table("users").upsert(
                {
                    "id": uid,
                    "email": email,
                    "name": str(display_name),
                    "created_at": datetime.now().isoformat(),
                },
                on_conflict="id",
            ).execute()
            return {"success": True}
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def auth_gate(self, access_token: str) -> dict:
        try:
            auth_client = await self.get_auth_client()
            user_response = await auth_client.auth.get_user(access_token)
            if user_response.user:
                return {
                    "success": True,
                    "user_id": user_response.user.id,
                    "email": user_response.user.email
                }
            return {"success": False, "error": "Invalid or expired session"}
        except Exception as e:
            return {"success": False, "error": str(e)}

    # ---------- Profile ----------
    async def get_user_profile(self, user_id: str) -> Optional[UserProfile]:
        try:
            # Server-side read; no access token required here by design
            supabase = await self.get_server_client()
            response = await supabase.table("users").select("*").eq("id", user_id).single().execute()

            if response.data:
                return UserProfile(
                    name=response.data.get("name"),
                    email=response.data.get("email"),
                )
            return None
        except Exception as e:
            print(f"Error fetching user profile: {e}")
            return None

    # ---------- Messages ----------
    async def save_message(self, message_data: Message) -> tuple[bool, str | None]:
        try:
            # Server-side write; no access token required here by design
            supabase = await self.get_server_client()
            message_dict = {
                "user_id": message_data.user_id,
                "sender": message_data.sender,
                "content": message_data.content,
                "timestamp": message_data.timestamp.isoformat(),
            }
            await supabase.table("messages").insert(message_dict).execute()
            return (True, None)
        except Exception as e:
            err = str(e)
            print(f"Error saving message: {err}")
            return (False, err)

    async def get_messages(self, user_id: str, bot_name: str = None) -> StoredChat | List[StoredChat]:
        try:
            # Server-side read; no access token required here by design
            supabase = await self.get_server_client()
            query = supabase.table("messages").select("*").eq("user_id", user_id)

            if bot_name:
                query = query.in_("sender", [f"user::{bot_name}", bot_name])

            response = await query.order("timestamp").execute()
            messages = []

            for row in response.data:
                msg = Message(
                    user_id=row["user_id"],
                    sender=row["sender"],
                    content=row["content"],
                    timestamp=datetime.fromisoformat(row["timestamp"])
                )
                messages.append(msg)

            if bot_name:
                return StoredChat(user_id=user_id, bot_name=bot_name, chat=messages)
            else:
                # Group by bot
                chats_by_bot = {}
                for msg in messages:
                    if msg.sender != user_id and not str(msg.sender).startswith("user::"):
                        bot = msg.sender
                        chats_by_bot.setdefault(bot, []).append(msg)

                return [
                    StoredChat(user_id=user_id, bot_name=bot, chat=chats)
                    for bot, chats in chats_by_bot.items()
                ]

        except Exception as e:
            print(f"Error getting messages: {e}")
            return [] if not bot_name else StoredChat(user_id=user_id, bot_name=bot_name, chat=[])

    async def delete_all_conversations(self, user_id: str) -> bool:
        try:
            # Server-side delete; no access token required here by design
            supabase = await self.get_server_client()
            await supabase.table("messages").delete().eq("user_id", user_id).execute()
            return True
        except Exception as e:
            print(f"Error deleting conversations: {e}")
            return False

    async def delete_bot_chat(self, user_id: str, bot_name: str) -> bool:
        try:
            # Server-side delete; no access token required here by design
            supabase = await self.get_server_client()
            user_sender_tag = f"user::{bot_name}"
            await supabase.table("messages").delete().eq("user_id", user_id).or_(
                f"sender.eq.{user_sender_tag},sender.eq.{bot_name}"
            ).execute()
            return True
        except Exception as e:
            print(f"Error deleting conversation with {bot_name}: {e}")
            return False

    # ---------- Feature tables ----------
    async def upsert_custom_bot(self, custom_bot: CustomBot) -> tuple[bool, str | None]:
        try:
            supabase = await self.get_server_client()
            payload = {
                "user_id": custom_bot.user_id,
                "bot_name": custom_bot.bot_name,
                "personality": custom_bot.personality,
                "description": custom_bot.description,
                "avatar_emoji": custom_bot.avatar_emoji,
                "created_at": custom_bot.created_at.isoformat(),
            }
            await supabase.table("custom_bots").upsert(
                payload,
                on_conflict="user_id,bot_name",
            ).execute()
            return (True, None)
        except Exception as e:
            return (False, str(e))

    async def get_custom_bots(self, user_id: str) -> List[CustomBot]:
        try:
            supabase = await self.get_server_client()
            response = (
                await supabase.table("custom_bots")
                .select("*")
                .eq("user_id", user_id)
                .order("created_at")
                .execute()
            )
            return [
                CustomBot(
                    user_id=row["user_id"],
                    bot_name=row["bot_name"],
                    personality=row.get("personality", ""),
                    description=row.get("description", ""),
                    avatar_emoji=row.get("avatar_emoji"),
                    created_at=datetime.fromisoformat(row["created_at"]),
                )
                for row in (response.data or [])
            ]
        except Exception:
            return []

    async def add_journal_entry(self, entry: JournalEntry) -> tuple[bool, str | None]:
        try:
            supabase = await self.get_server_client()
            await supabase.table("journal_entries").insert(
                {
                    "user_id": entry.user_id,
                    "content": entry.content,
                    "timestamp": entry.timestamp.isoformat(),
                }
            ).execute()
            return (True, None)
        except Exception as e:
            return (False, str(e))

    async def get_journal_entries(self, user_id: str) -> List[JournalEntry]:
        try:
            supabase = await self.get_server_client()
            response = (
                await supabase.table("journal_entries")
                .select("*")
                .eq("user_id", user_id)
                .order("timestamp", desc=True)
                .execute()
            )
            return [
                JournalEntry(
                    user_id=row["user_id"],
                    content=row.get("content", ""),
                    timestamp=datetime.fromisoformat(row["timestamp"]),
                )
                for row in (response.data or [])
            ]
        except Exception:
            return []

    async def upsert_daily_checkin(self, checkin: DailyCheckIn) -> tuple[bool, str | None]:
        try:
            supabase = await self.get_server_client()
            await supabase.table("daily_checkins").upsert(
                {
                    "user_id": checkin.user_id,
                    "mood": checkin.mood,
                    "check_in_date": checkin.check_in_date,
                    "updated_at": checkin.updated_at.isoformat(),
                },
                on_conflict="user_id,check_in_date",
            ).execute()
            return (True, None)
        except Exception as e:
            return (False, str(e))

    async def get_latest_daily_checkin(self, user_id: str) -> Optional[DailyCheckIn]:
        try:
            supabase = await self.get_server_client()
            response = (
                await supabase.table("daily_checkins")
                .select("*")
                .eq("user_id", user_id)
                .order("check_in_date", desc=True)
                .limit(1)
                .execute()
            )
            data = response.data or []
            if not data:
                return None
            row = data[0]
            return DailyCheckIn(
                user_id=row["user_id"],
                mood=row.get("mood", "neutral"),
                check_in_date=row.get("check_in_date", ""),
                updated_at=datetime.fromisoformat(row["updated_at"]),
            )
        except Exception:
            return None

    async def add_memory_file(self, file_entry: MemoryFile) -> tuple[bool, str | None]:
        try:
            supabase = await self.get_server_client()
            await supabase.table("memory_files").insert(
                {
                    "user_id": file_entry.user_id,
                    "file_name": file_entry.file_name,
                    "uploaded_at": file_entry.uploaded_at.isoformat(),
                }
            ).execute()
            return (True, None)
        except Exception as e:
            return (False, str(e))

    async def get_memory_files(self, user_id: str) -> List[MemoryFile]:
        try:
            supabase = await self.get_server_client()
            response = (
                await supabase.table("memory_files")
                .select("*")
                .eq("user_id", user_id)
                .order("uploaded_at", desc=True)
                .execute()
            )
            return [
                MemoryFile(
                    user_id=row["user_id"],
                    file_name=row.get("file_name", ""),
                    uploaded_at=datetime.fromisoformat(row["uploaded_at"]),
                )
                for row in (response.data or [])
            ]
        except Exception:
            return []
