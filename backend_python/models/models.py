from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import List

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
