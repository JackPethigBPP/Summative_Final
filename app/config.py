
import warnings
import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    SQLALCHEMY_DATABASE_URI = os.getenv("DATABASE_URL")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-key")
    SQLALCHEMY_ENGINE_OPTIONS = {
        "pool_pre_ping": True
    }

    if not SQLALCHEMY_DATABASE_URI:
        warnings.warn(
            "DATABASE_URL is not set. Falling back to local SQLite (sqlite:///local.db).",
            RuntimeWarning
        )
        SQLALCHEMY_DATABASE_URI = "sqlite:///local.db"
