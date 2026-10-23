from pydantic_settings import BaseSettings, SettingsConfigDict

class Setting(BaseSettings):
    gemini_key: str

    model_config = SettingsConfigDict(
        extra="ignore"
    )