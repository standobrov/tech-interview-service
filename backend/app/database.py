import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Try to get credentials from systemd first, fallback to environment variable
CREDENTIALS_PATH = "/run/credentials/tech-interview-stand-api.service/db-url"
if os.path.exists(CREDENTIALS_PATH):
    with open(CREDENTIALS_PATH) as f:
        DATABASE_URL = f.read().strip()
else:
    DATABASE_URL = os.getenv("DATABASE_URL")

engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine)

def get_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
