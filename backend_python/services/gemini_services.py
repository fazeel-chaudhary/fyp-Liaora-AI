import google.generativeai as genai
from typing import Dict
from datetime import datetime
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

        # Register all available bots
        self.available_bots = {
            "Orion": OrionBot(),
            "Aura": AuraBot(),
            "Blaze": BlazeBot(),
            "Echo": EchoBot(),
            "Jovi": JoviBot(),
            "Lumen": LumenBot(),
            "Sera": SeraBot(),
            "Zippy": ZippyBot(),
        }

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
    async def chat_with_bot(self, user_id: str, bot_name: str, user_message: str) -> Dict:
        try:

            bot_instance = self.available_bots[bot_name]

            # Save user message in Supabase
            user_msg = Message(
                user_id=user_id,
                sender=user_id,  # sender is user
                content=user_message,
                timestamp=datetime.now(),
            )
            await self.supabase_service.save_message(user_msg)

            # Fetch last 20 messages for context
            stored_chat = await self.supabase_service.get_messages(user_id, bot_name)
            chat_history = stored_chat.chat[-20:] if stored_chat else []

            # Prepare a per-request model with system_instruction so persona isn't visible
            persona_instruction = f"You are {bot_instance.name}. {bot_instance.system_prompt}"
            model = genai.GenerativeModel("gemini-2.5-flash-lite", system_instruction=persona_instruction)

            # Conversation excluding persona from visible turns
            conversation = []

            for msg in chat_history:
                if msg.sender == user_id:
                    conversation.append({"role": "user", "parts": [msg.content]})
                else:
                    conversation.append({"role": "model", "parts": [msg.content]})

            # Add new user input at the end
            conversation.append({"role": "user", "parts": [user_message]})

            # Generate response from Gemini
            response = model.generate_content(conversation)
            # Normalize whitespace to avoid \n appearing in responses
            raw_text = (response.text or "").strip()
            bot_response = " ".join(raw_text.split())

            # Save bot response in DB
            bot_msg = Message(
                user_id=user_id,
                sender=bot_name,  # sender is bot
                content=bot_response,
                timestamp=datetime.now(),
            )
            await self.supabase_service.save_message(bot_msg)

            return {
                "success": True,
                "bot_response": bot_response,
            }

        except Exception as e:
            print(f"Error in chat_with_bot: {e}")
            return {"success": False, "error": str(e)}
