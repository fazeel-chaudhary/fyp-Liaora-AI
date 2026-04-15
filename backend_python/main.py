from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from services.gemini_services import GeminiService
from services.supabase_services import SupabaseService
from models.models import (
    Signup,
    Login,
    UserProfile,
    Message,
    StoredChat,
    BotList,
    CustomBot,
    CustomBotList,
    JournalEntry,
    JournalList,
    DailyCheckIn,
    MemoryFile,
    MemoryFileList,
)
from typing import List, Dict, Optional

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
async def chat_with_bot(
    user_id: str,
    bot_name: str,
    payload: Message,
    authorization: str = Header(...),
):
    token = authorization.split(" ", 1)[1] if authorization.lower().startswith("bearer ") else authorization
    result = await gemini_service.chat_with_bot(
        user_id, bot_name, payload.content, access_token=token
    )
    if result["success"]:
        return {"bot_response": result["bot_response"]}
    else:
        raise HTTPException(status_code=400, detail=result.get("error", "Chat failed"))


@app.post("/chat-live/{user_id}/{bot_name}")
async def live_chat_with_bot(
    user_id: str,
    bot_name: str,
    payload: Message,
    authorization: str = Header(...),
):
    token = authorization.split(" ", 1)[1] if authorization.lower().startswith("bearer ") else authorization
    result = await gemini_service.live_chat_with_bot(
        user_id, bot_name, payload.content, access_token=token
    )
    if result["success"]:
        return {"bot_response": result["bot_response"]}
    else:
        raise HTTPException(status_code=400, detail=result.get("error", "Live chat failed"))


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


# Feature Routes
@app.post("/custom-bots/{user_id}")
async def upsert_custom_bot(user_id: str, payload: CustomBot):
    if payload.user_id != user_id:
        raise HTTPException(status_code=400, detail="Payload user_id mismatch")
    ok, err = await supabase_service.upsert_custom_bot(payload)
    if ok:
        return {"message": "Custom bot saved"}
    raise HTTPException(status_code=400, detail=err or "Failed to save custom bot")


@app.get("/custom-bots/{user_id}", response_model=CustomBotList)
async def get_custom_bots(user_id: str):
    bots = await supabase_service.get_custom_bots(user_id)
    return CustomBotList(bots=bots)


@app.post("/journal/{user_id}")
async def add_journal_entry(user_id: str, payload: JournalEntry):
    if payload.user_id != user_id:
        raise HTTPException(status_code=400, detail="Payload user_id mismatch")
    ok, err = await supabase_service.add_journal_entry(payload)
    if ok:
        return {"message": "Journal entry saved"}
    raise HTTPException(status_code=400, detail=err or "Failed to save journal entry")


@app.get("/journal/{user_id}", response_model=JournalList)
async def get_journal_entries(user_id: str):
    entries = await supabase_service.get_journal_entries(user_id)
    return JournalList(entries=entries)


@app.post("/checkins/{user_id}")
async def upsert_daily_checkin(user_id: str, payload: DailyCheckIn):
    if payload.user_id != user_id:
        raise HTTPException(status_code=400, detail="Payload user_id mismatch")
    ok, err = await supabase_service.upsert_daily_checkin(payload)
    if ok:
        return {"message": "Check-in saved"}
    raise HTTPException(status_code=400, detail=err or "Failed to save daily check-in")


@app.get("/checkins/{user_id}", response_model=Optional[DailyCheckIn])
async def get_latest_checkin(user_id: str):
    return await supabase_service.get_latest_daily_checkin(user_id)


@app.post("/memory-files/{user_id}")
async def add_memory_file(user_id: str, payload: MemoryFile):
    if payload.user_id != user_id:
        raise HTTPException(status_code=400, detail="Payload user_id mismatch")
    ok, err = await supabase_service.add_memory_file(payload)
    if ok:
        return {"message": "Memory file metadata saved"}
    raise HTTPException(status_code=400, detail=err or "Failed to save memory file")


@app.get("/memory-files/{user_id}", response_model=MemoryFileList)
async def get_memory_files(user_id: str):
    files = await supabase_service.get_memory_files(user_id)
    return MemoryFileList(files=files)


@app.get("/memory-dashboard/{user_id}")
async def memory_dashboard(user_id: str) -> Dict[str, int]:
    chats = await supabase_service.get_messages(user_id)
    journal_entries = await supabase_service.get_journal_entries(user_id)
    memory_files = await supabase_service.get_memory_files(user_id)

    message_count = 0
    if isinstance(chats, list):
        for chat in chats:
            message_count += len(chat.chat)

    return {
        "messages": message_count,
        "journal_entries": len(journal_entries),
        "uploaded_files": len(memory_files),
    }
