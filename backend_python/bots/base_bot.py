class BaseBot:
    def __init__(self, name: str, system_prompt: str , description: str):
        self.name = name
        self.system_prompt = system_prompt
        self.description = description
