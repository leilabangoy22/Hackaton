from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    db_string: str
    map_key: str

    model_config = SettingsConfigDict(
        extra="ignore"
    )