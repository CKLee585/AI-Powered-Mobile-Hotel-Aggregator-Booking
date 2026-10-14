from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Environment-backed settings kept outside the Flutter application."""

    app_name: str = "herewego API"
    environment: Literal["development", "test", "production"] = "development"
    data_mode: Literal["mock", "live"] = "mock"
    database_path: Path = (
        Path(__file__).resolve().parents[1] / "data" / "herewego.db"
    )
    allowed_origins: str = "http://localhost,http://127.0.0.1"
    google_vision_api_key: SecretStr | None = None
    google_places_api_key: SecretStr | None = None

    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="HEREWEGO_",
        case_sensitive=False,
        extra="ignore",
    )

    @property
    def cors_origins(self) -> list[str]:
        return [
            origin.strip()
            for origin in self.allowed_origins.split(",")
            if origin.strip()
        ]

    @property
    def docs_url(self) -> str | None:
        return None if self.environment == "production" else "/docs"

    @property
    def redoc_url(self) -> str | None:
        return None if self.environment == "production" else "/redoc"


@lru_cache
def get_settings() -> Settings:
    return Settings()
