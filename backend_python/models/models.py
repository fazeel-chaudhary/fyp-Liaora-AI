from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import List, Optional

# Signup
class Signup(BaseModel):
    username: str
    email: EmailStr
    password: str 

# Login
class Login(BaseModel):
    email: EmailStr
    password: str

# User Profile
class UserProfile(BaseModel):
    name: str
    email: EmailStr

# Bot
class Bot(BaseModel):
    bot_name: str
    personality: str
    description: str

# Bots List
class BotList(BaseModel):
    bots: List[Bot] = []

# Message
class Message(BaseModel):
    user_id: str
    sender: str       # Either the user or the bot
    content: str
    timestamp: datetime = datetime.now() 

# User Stored Chat
class StoredChat(BaseModel):
    user_id: str
    bot_name: str
    chat: List[Message] = []


class CustomBot(BaseModel):
    user_id: str
    bot_name: str
    personality: str
    description: str
    avatar_emoji: Optional[str] = None
    created_at: datetime = datetime.now()


class CustomBotList(BaseModel):
    bots: List[CustomBot] = []


class JournalEntry(BaseModel):
    user_id: str
    content: str
    timestamp: datetime = datetime.now()


class JournalList(BaseModel):
    entries: List[JournalEntry] = []


class DailyCheckIn(BaseModel):
    user_id: str
    mood: str
    check_in_date: str
    updated_at: datetime = datetime.now()


class MemoryFile(BaseModel):
    user_id: str
    file_name: str
    uploaded_at: datetime = datetime.now()


class MemoryFileList(BaseModel):
    files: List[MemoryFile] = []
