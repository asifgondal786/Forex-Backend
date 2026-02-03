"""
Authentication Service
Handles JWT token generation, validation, and user authentication
"""
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
import jwt  # This should come from PyJWT package
import secrets
import hashlib
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

# Configuration
SECRET_KEY = "your-secret-key-change-in-production"  # Change in production
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 hours
REFRESH_TOKEN_EXPIRE_DAYS = 30

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Security scheme
security = HTTPBearer()

class AuthService:
    """Authentication and JWT token management"""
    
    def __init__(self):
        # In production, use a real database
        self.users_db: Dict[str, Dict] = {}
        self.tokens_blacklist: set = set()
    
    def hash_password(self, password: str) -> str:
        """Hash password using bcrypt"""
        return pwd_context.hash(password)
    
    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        """Verify password against hash"""
        return pwd_context.verify(plain_password, hashed_password)
    
    def create_access_token(self, data: dict, expires_delta: Optional[timedelta] = None) -> str:
        """Create JWT access token"""
        to_encode = data.copy()
        
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        
        to_encode.update({"exp": expire})
        
        encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
        return encoded_jwt
    
    def verify_token(self, token: str) -> bool:
        """Verify JWT token validity"""
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            return token not in self.tokens_blacklist
        except jwt.ExpiredSignatureError:
            return False
        except jwt.InvalidTokenError:
            return False
    
    def decode_token(self, token: str) -> dict:
        """Decode and validate JWT token"""
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            return payload
        except jwt.ExpiredSignatureError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has expired"
            )
        except jwt.InvalidTokenError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token"
            )
    
    async def get_current_user(self, credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
        """Get current authenticated user from token"""
        token = credentials.credentials
        payload = self.decode_token(token)
        user_id: str = payload.get("sub")
        
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token"
            )
        
        # Fetch user from database (in production)
        if user_id not in self.users_db:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        return {"id": user_id, **self.users_db[user_id]}
    
    async def signup(self, email: str, username: str, password: str, full_name: str) -> dict:
        """Register new user"""
        # Check if user already exists
        for user_data in self.users_db.values():
            if user_data.get("email") == email:
                raise ValueError("Email already registered")
            if user_data.get("username") == username:
                raise ValueError("Username already taken")
        
        # Create new user
        user_id = secrets.token_hex(8)
        user_data = {
            "id": user_id,
            "email": email,
            "username": username,
            "full_name": full_name,
            "password_hash": self.hash_password(password),
            "created_at": datetime.utcnow().isoformat(),
            "is_verified": False,
            "avatar": None,
            "risk_profile": {
                "max_daily_loss": -2.0,  # -2%
                "max_trade_size": 100000,
                "max_open_positions": 5,
                "initial_investment": 10000,
            }
        }
        
        self.users_db[user_id] = user_data
        
        # Create access token
        access_token = self.create_access_token(data={"sub": user_id})
        
        return {
            "success": True,
            "message": "Account created successfully",
            "user": {
                "id": user_id,
                "email": email,
                "username": username,
                "full_name": full_name,
                "created_at": user_data["created_at"],
                "is_verified": False,
            },
            "token": access_token,
        }
    
    async def login(self, email: str, password: str) -> dict:
        """Authenticate user and return token"""
        # Find user by email
        user_data = None
        user_id = None
        
        for uid, data in self.users_db.items():
            if data.get("email") == email:
                user_id = uid
                user_data = data
                break
        
        if not user_data:
            raise ValueError("Invalid email or password")
        
        # Verify password
        if not self.verify_password(password, user_data["password_hash"]):
            raise ValueError("Invalid email or password")
        
        # Create access token
        access_token = self.create_access_token(data={"sub": user_id})
        
        return {
            "success": True,
            "message": "Login successful",
            "user": {
                "id": user_id,
                "email": user_data["email"],
                "username": user_data["username"],
                "full_name": user_data["full_name"],
                "created_at": user_data["created_at"],
                "is_verified": user_data.get("is_verified", False),
            },
            "token": access_token,
        }
    
    def invalidate_token(self, token: str):
        """Blacklist token on logout"""
        self.tokens_blacklist.add(token)
