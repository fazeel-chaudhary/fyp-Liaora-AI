import google.generativeai as genai
from typing import Dict
from datetime import datetime
import re
from core.config import GEMINI_API_KEY
from models.models import Bot, Message, BotList
from services.supabase_services import SupabaseService
from bots.orion import OrionBot
from bots.aura import AuraBot
from bots.blaze import BlazeBot
from bots.echo import EchoBot
from bots.jovi import JoviBot
from bots.lumen import LumenBot
from bots.sera import SeraBot
from bots.zippy import ZippyBot


class GeminiService:
    def __init__(self):
        
        # Configure Gemini API
        genai.configure(api_key=GEMINI_API_KEY)
        self.model = genai.GenerativeModel("gemini-2.5-flash-lite")


        # Initialize Supabase service
        self.supabase_service = SupabaseService()

        # Keys must match each bot's `name` (e.g. OrionBot) — same as `/bots` and Flutter URLs.
        _instances = (
            OrionBot(),
            AuraBot(),
            BlazeBot(),
            EchoBot(),
            JoviBot(),
            LumenBot(),
            SeraBot(),
            ZippyBot(),
        )
        self.available_bots = {bot.name: bot for bot in _instances}

    #Return All Bots
    async def display_all_bots(self) -> BotList:
        try:
            bot_list = []
            for bot_instance in self.available_bots.values():
                bot = Bot(
                    bot_name=bot_instance.name,
                    personality=bot_instance.system_prompt,
                    description=bot_instance.description,
                )
                bot_list.append(bot)

            return BotList(bots=bot_list)

        except Exception as e:
            print(f"Error retrieving bots: {e}")
            return BotList(bots=[])

    # Chat with Bot
    async def chat_with_bot(
        self,
        user_id: str,
        bot_name: str,
        user_message: str,
        access_token: str,
    ) -> Dict:
        try:
            profile = await self.supabase_service.ensure_profile_row_for_access_token(
                access_token, user_id
            )
            if not profile["success"]:
                return {"success": False, "error": profile.get("error", "Profile sync failed")}

            bot_instance = self.available_bots[bot_name]

            # Save user message in Supabase
            user_msg = Message(
                user_id=user_id,
                sender=f"user::{bot_name}",  # bot-scoped user sender tag
                content=user_message,
                timestamp=datetime.now(),
            )
            ok, err = await self.supabase_service.save_message(user_msg)
            if not ok:
                return {
                    "success": False,
                    "error": f"Could not save user message: {err}",
                }

            # Keep a short memory window so old verbose replies do not dominate tone.
            stored_chat = await self.supabase_service.get_messages(user_id, bot_name)
            chat_history = stored_chat.chat[-8:] if stored_chat else []

            # Prepare a per-request model with system_instruction so persona isn't visible
            persona_instruction = (
                f"You are {bot_instance.name}. {bot_instance.system_prompt} "
                "CRITICAL RESPONSE STYLE: Keep replies conversational and human. "
                "Default to short chat messages (1-3 sentences max). "
                "Do not output numbered steps, markdown syntax, headings, bullet points, or lecture style unless user asks. "
                "Never sound like customer support, policy text, or a scripted assistant. "
                "Never say phrases like 'I am programmed' or 'Please state the problem'. "
                "Ask one gentle follow-up question when helpful."
            )
            model = genai.GenerativeModel("gemini-2.5-flash-lite", system_instruction=persona_instruction)

            # Conversation excluding persona from visible turns
            conversation = []

            for msg in chat_history:
                if msg.sender == user_id or msg.sender.startswith("user::"):
                    conversation.append({"role": "user", "parts": [msg.content]})
                else:
                    if self._is_legacy_verbose_text(msg.content):
                        continue
                    conversation.append({"role": "model", "parts": [msg.content]})

            # Add new user input at the end
            conversation.append({"role": "user", "parts": [user_message]})

            # Generate response from Gemini
            response = model.generate_content(
                conversation,
                generation_config={"temperature": 0.65, "max_output_tokens": 80},
            )
            raw_text = (response.text or "").strip()
            bot_response = self._sanitize_chat_reply(raw_text)

            # Save bot response in DB
            bot_msg = Message(
                user_id=user_id,
                sender=bot_name,  # sender is bot
                content=bot_response,
                timestamp=datetime.now(),
            )
            ok_bot, err_bot = await self.supabase_service.save_message(bot_msg)
            if not ok_bot:
                return {
                    "success": False,
                    "error": f"Could not save bot reply: {err_bot}",
                    "bot_response": bot_response,
                }

            return {
                "success": True,
                "bot_response": bot_response,
            }

        except Exception as e:
            err_text = str(e)
            print(f"Error in chat_with_bot: {err_text}")
            if self._is_quota_error(err_text):
                # Graceful fallback in normal chat too, so raw quota traces never leak to UI.
                fallback = self._quota_fallback_response(user_message)
                bot_msg = Message(
                    user_id=user_id,
                    sender=bot_name,
                    content=fallback,
                    timestamp=datetime.now(),
                )
                await self.supabase_service.save_message(bot_msg)
                return {"success": True, "bot_response": fallback}
            return {"success": False, "error": err_text}

    async def live_chat_with_bot(
        self,
        user_id: str,
        bot_name: str,
        user_message: str,
        access_token: str,
    ) -> Dict:
        """
        Real-time call-style chat:
        - validates user token
        - does NOT persist user/bot messages
        - returns a concise spoken-style reply in user's language
        """
        try:
            auth = await self.supabase_service.auth_gate(access_token)
            if not auth.get("success"):
                return {"success": False, "error": auth.get("error", "Unauthorized")}
            if str(auth.get("user_id")) != str(user_id):
                return {"success": False, "error": "User id does not match access token"}

            bot_instance = self.available_bots[bot_name]
            persona_instruction = (
                f"You are {bot_instance.name}. {bot_instance.system_prompt} "
                "You are in live voice call mode. Speak naturally and briefly. "
                "Use 1-3 short sentences only. "
                "Mirror the user's language automatically. "
                "If the user speaks Urdu (including Roman Urdu), reply in natural Urdu/Roman Urdu. "
                "No markdown, no lists, no headings, no lecture style."
            )
            model = genai.GenerativeModel(
                "gemini-2.5-flash-lite",
                system_instruction=persona_instruction,
            )

            response = model.generate_content(
                [{"role": "user", "parts": [user_message]}],
                generation_config={"temperature": 0.9, "max_output_tokens": 70},
            )
            raw_text = (response.text or "").strip()
            bot_response = self._sanitize_chat_reply(raw_text)

            return {"success": True, "bot_response": bot_response}
        except Exception as e:
            err_text = str(e)
            print(f"Error in live_chat_with_bot: {err_text}")
            if self._is_quota_error(err_text):
                return {
                    "success": True,
                    "bot_response": self._quota_fallback_response(user_message),
                }
            return {"success": False, "error": err_text}

    def _sanitize_chat_reply(self, text: str) -> str:
        cleaned = text.strip()
        # Remove common markdown emphasis and headings
        cleaned = cleaned.replace("**", "").replace("__", "")
        cleaned = re.sub(r"^#{1,6}\s*", "", cleaned, flags=re.MULTILINE)
        # Convert markdown bullets to plain lines
        cleaned = re.sub(r"^\s*[-*]\s+", "", cleaned, flags=re.MULTILINE)
        # Remove numbered-list prefixes that read like reports
        cleaned = re.sub(r"\b\d+\.\s+", "", cleaned)
        # Remove common lecture/list separators
        cleaned = cleaned.replace(" - ", " ")
        cleaned = cleaned.replace("•", " ")
        cleaned = re.sub(r"\bi am programmed to\b", "I can", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\bplease state the problem\b", "tell me what is going on", cleaned, flags=re.IGNORECASE)
        # Collapse excessive whitespace while preserving sentence spacing
        cleaned = re.sub(r"\s+", " ", cleaned).strip()
        # Hard cap by sentence count to keep replies conversational
        sentence_parts = re.split(r"(?<=[.!?])\s+", cleaned)
        if len(sentence_parts) > 3:
            cleaned = " ".join(sentence_parts[:3]).strip()
        # Hard cap by total words to prevent long blocks
        words = cleaned.split()
        if len(words) > 45:
            cleaned = " ".join(words[:45]).strip()
            if cleaned and cleaned[-1] not in ".!?":
                cleaned += "."
        return cleaned

    def _is_legacy_verbose_text(self, text: str) -> bool:
        lower = text.lower()
        legacy_signals = [
            "i understand you're feeling",
            "i apologize if my previous responses",
            "i'm still learning",
            "could you tell me more about what you mean",
            "it seems like there might be a misunderstanding",
        ]
        if any(sig in lower for sig in legacy_signals):
            return True
        return len(text.strip()) > 280

    def _is_quota_error(self, error_text: str) -> bool:
        lower = error_text.lower()
        return "429" in lower or "quota" in lower or "rate limit" in lower

    def _quota_fallback_response(self, user_message: str) -> str:
        if self._is_likely_urdu(user_message):
            return (
                "Mujhe temporary network/AI limit issue aa raha hai, lekin call continue hai. "
                "Aap dobara chhota sa jumla bol dein, main turant jawab dunga."
            )
        return (
            "I am hitting a temporary AI limit right now, but the call is still active. "
            "Please repeat that in one short sentence and I will respond right away."
        )

    def _is_likely_urdu(self, text: str) -> bool:
        if re.search(r"[\u0600-\u06FF]", text):
            return True
        lower = text.lower()
        hints = [
            "kya",
            "hain",
            "hai",
            "mein",
            "mera",
            "meri",
            "tum",
            "aap",
            "nahi",
            "kyun",
            "urdu",
            "bol",
            "sakte",
            "kar",
        ]
        return any(h in lower for h in hints)
