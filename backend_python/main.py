from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from services.gemini_services import GeminiService
from services.supabase_services import SupabaseService
from models.models import Signup, Login, UserProfile, Message, StoredChat, BotList
from typing import List

# Initialize FastAPI app
app = FastAPI(title="Liora AI")

# Enable CORS 
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize services
supabase_service = SupabaseService()
gemini_service = GeminiService()


# Authentication Routes
@app.post("/auth/signup")
async def signup(signup_data: Signup):
    result = await supabase_service.signup_user(signup_data)
    if result["success"]:
        return {"message": "Signup successful , please check your email for verification link", "user_id": result["user_id"]}
    else:
        raise HTTPException(status_code=400, detail=result.get("error", "Signup failed"))

@app.post("/auth/login")
async def login(login_data: Login):
    result = await supabase_service.login_user(login_data)
    if result["success"]:
        return {
            "message": "Login successful",
            "user_id": result["user_id"],
            "access_token": result["access_token"],
        }
    else:
        raise HTTPException(status_code=401, detail=result.get("error", "Login failed"))
    
@app.post("/auth/logout")
async def logout():
    result = await supabase_service.logout_user()
    if result["success"]:
        return {"message": "Logout successful"}
    else:
        raise HTTPException(status_code=400, detail=result.get("error", "Logout failed"))
    
@app.get("/auth/gate")
async def auth_gate(authorization: str = Header(...)):
    # Only this gateway validates the Authorization header
    token = authorization.split(" ")[1] if " " in authorization else authorization
    result = await supabase_service.auth_gate(token)
    if result["success"]:
        return result
    else:
        raise HTTPException(status_code=401, detail=result.get("error", "Unauthorized"))
          

@app.get("/profile/{user_id}", response_model=UserProfile)
async def get_profile(user_id: str):
    # No token required here; server uses service client
    profile = await supabase_service.get_user_profile(user_id)
    if profile:
        return profile
    else:
        raise HTTPException(status_code=404, detail="User not found")


# Bot Routes
@app.get("/bots", response_model=BotList)
async def get_bots():
    return await gemini_service.display_all_bots()


@app.post("/chat/{user_id}/{bot_name}")
async def chat_with_bot(user_id: str, bot_name: str, payload: Message):
    result = await gemini_service.chat_with_bot(user_id, bot_name, payload.content)
    if result["success"]:
        return {"bot_response": result["bot_response"]}
    else:
        raise HTTPException(status_code=400, detail=result.get("error", "Chat failed"))


# Messages Routes
@app.get("/messages/{user_id}/{bot_name}", response_model=StoredChat)
async def get_messages(user_id: str, bot_name: str):
    messages = await supabase_service.get_messages(user_id, bot_name)
    return messages if messages else StoredChat(user_id=user_id, bot_name=bot_name, chat=[])


@app.delete("/messages/{user_id}/all")
async def delete_all_messages(user_id: str):
    success = await supabase_service.delete_all_conversations(user_id)
    if success:
        return {"message": "All conversations deleted"}
    else:
        raise HTTPException(status_code=400, detail="Failed to delete conversations")


@app.delete("/messages/{user_id}/{bot_name}")
async def delete_bot_messages(user_id: str, bot_name: str):
    success = await supabase_service.delete_bot_chat(user_id, bot_name)
    if success:
        return {"message": f"Conversation with {bot_name} deleted"}
    else:
        raise HTTPException(status_code=400, detail="Failed to delete conversation")
