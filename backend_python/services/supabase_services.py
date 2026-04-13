from supabase import create_async_client
from core.config import SUPABASE_URL, SUPABASE_KEY
from models.models import Signup, Login, UserProfile, Message, StoredChat
from datetime import datetime
from typing import List, Optional


class SupabaseService:

    def __init__(self):
        self._server_client = None

    async def get_server_client(self):
        # Use service-role key if available; acts as central server-side client bypassing per-request tokens
        if self._server_client is None:
            self._server_client = await create_async_client(SUPABASE_URL, SUPABASE_KEY)
        return self._server_client

    # ---------- Auth ----------
    async def signup_user(self, signup_data: Signup) -> dict:
        try:
            supabase = await self.get_server_client()
            auth_response = await supabase.auth.sign_up({
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
                await supabase.table("users").upsert(user_data, on_conflict="id").execute()

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
            supabase = await self.get_server_client()
            auth_response = await supabase.auth.sign_in_with_password({
                "email": login_data.email,
                "password": login_data.password
            })

            if auth_response.user and auth_response.session:
                access_token = auth_response.session.access_token
                uid = str(auth_response.user.id)
                # Auth users created outside this app (or before `public.users` existed) have no profile row;
                # `messages.user_id` FK requires a row in `public.users`.
                try:
                    existing = await supabase.table("users").select("id").eq("id", uid).execute()
                    if not existing.data:
                        meta = getattr(auth_response.user, "user_metadata", None) or {}
                        display_name = (
                            meta.get("name")
                            or meta.get("full_name")
                            or login_data.email.split("@", 1)[0]
                        )
                        await supabase.table("users").insert(
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
            supabase = await self.get_server_client()
            await supabase.auth.sign_out()
            return {"success": True}
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def ensure_profile_row_for_access_token(
        self, access_token: str, expected_user_id: str
    ) -> dict:
        """Upsert public.users using the caller's JWT so messages.user_id FK can succeed."""
        try:
            supabase = await self.get_server_client()
            user_response = await supabase.auth.get_user(access_token)
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

            await supabase.table("users").upsert(
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
            supabase = await self.get_server_client()
            user_response = await supabase.auth.get_user(access_token)
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
                query = query.in_("sender", [user_id, bot_name])

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
                    if msg.sender != user_id:
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
            await supabase.table("messages").delete().eq("user_id", user_id).or_(f"sender.eq.{user_id},sender.eq.{bot_name}").execute()
            return True
        except Exception as e:
            print(f"Error deleting conversation with {bot_name}: {e}")
            return False
