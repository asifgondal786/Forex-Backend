# Security Hardening Guide for Tajir App

**Status**: Pre-production security checklist  
**Date**: February 27, 2026  
**Goal**: Enterprise-grade security before public launch  

---

## 🔐 SECURITY ASSESSMENT

### Current Status
| Layer | Status | Priority |
|-------|--------|----------|
| Frontend | ⚠️ Basic | HIGH |
| Backend Auth | ⚠️ Partial | HIGH |
| HTTPS/SSL | ✅ Complete | Done |
| Firestore Rules | ✅ Basic | Done |
| CORS Config | ✅ Set | Done |
| Rate Limiting | ✅ Partial | MEDIUM |
| Input Validation | ⚠️ Basic | HIGH |
| Data Encryption | ⚠️ Partial | HIGH |

---

## 🎯 SECURITY HARDENING CHECKLIST

### 1️⃣ FRONTEND SECURITY

#### 1.1 Content Security Policy (CSP)
```html
<!-- Add to Frontend/web/index.html -->
<meta http-equiv="Content-Security-Policy" 
      content="default-src 'self'; 
               script-src 'self' https://www.gstatic.com/firebasejs/ https://cdn.jsdelivr.net; 
               style-src 'self' 'unsafe-inline'; 
               img-src 'self' data: https:; 
               font-src 'self' https:; 
               connect-src 'self' https://firestore.googleapis.com https://identitytoolkit.googleapis.com https://www.googleapis.com https://forex-backend-production-bc44.up.railway.app; 
               frame-ancestors 'none'; 
               form-action 'self';">
```

**Status**: ⚠️ NOT YET IMPLEMENTED

#### 1.2 XSS Prevention
```dart
// Frontend: lib/services/sanitization_service.dart
class SanitizationService {
  static String sanitizeInput(String input) {
    // Remove dangerous characters
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }
  
  static String sanitizeEmail(String email) {
    // Email should only have safe characters
    return email.toLowerCase().trim();
  }
}
```

**Status**: ⚠️ NEEDS IMPLEMENTATION

#### 1.3 Local Storage Security
```dart
// Never store sensitive data in localStorage
// DO NOT:
localStorage.setItem('password', password);      // ❌ NEVER
localStorage.setItem('apiKey', apiKey);         // ❌ NEVER
localStorage.setItem('token', jwtToken);        // ⚠️ RISKY

// DO:
// Use session storage or memory only
// Firebase handles token storage securely
```

**Status**: ⚠️ NEEDS VERIFICATION

#### 1.4 HTTPS Enforcement
```html
<!-- Add to Frontend/web/index.html -->
<meta http-equiv="Strict-Transport-Security" 
      content="max-age=31536000; includeSubDomains; preload">
```

**Status**: ✅ Firebase Hosting enforces HTTPS

#### 1.5 Disable Autocomplete for Sensitive Fields
```dart
// Frontend: lib/screens/login_screen.dart
TextField(
  obscureText: true,
  autocorrect: false,
  enableSuggestions: false,
  autofillHints: const [AutofillHints.password], // Use autofillHints
  controller: passwordController,
  decoration: InputDecoration(
    labelText: 'Password',
    hintText: 'Enter your password',
  ),
)
```

**Status**: ⚠️ NEEDS VERIFICATION

#### 1.6 Clickjacking Protection
```html
<!-- Add to Frontend/web/index.html -->
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<!-- Firebase hosting adds X-Frame-Options: DENY automatically -->
```

**Status**: ✅ Firebase Hosting includes this

---

### 2️⃣ BACKEND AUTHENTICATION & AUTHORIZATION

#### 2.1 Verify Auth on All Endpoints
```python
# Backend: app/main.py

from fastapi import Depends, HTTPException, status
from app.services.auth_service import AuthService

auth_service = AuthService()

# Dependency for protected routes
async def verify_token(authorization: str = Header(None)):
    """Verify JWT token from request headers"""
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authorization header"
        )
    
    try:
        scheme, token = authorization.split()
        if scheme.lower() != "bearer":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authorization scheme"
            )
        
        user_id = await auth_service.verify_token(token)
        return user_id
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e)
        )

# Use on protected routes
@app.post("/api/trading/start")
async def start_trading(
    request: TradeRequest,
    user_id: str = Depends(verify_token)  # ✅ PROTECTED
):
    """Start a new trade (requires authentication)"""
    # Only authenticated users can access
    return await trading_service.start_trade(user_id, request)
```

**Status**: ⚠️ NEEDS IMPLEMENTATION ON ALL ENDPOINTS

#### 2.2 JWT Token Validation
```python
# Backend: app/services/auth_service.py

import jwt
from datetime import datetime, timedelta
import os

class AuthService:
    def __init__(self):
        self.secret_key = os.getenv('JWT_SECRET_KEY')
        self.algorithm = 'HS256'
        self.expiration_hours = 24
    
    def create_token(self, user_id: str) -> str:
        """Create JWT token"""
        expire = datetime.utcnow() + timedelta(hours=self.expiration_hours)
        payload = {
            'sub': user_id,
            'exp': expire,
            'iat': datetime.utcnow(),
            'type': 'access'
        }
        return jwt.encode(payload, self.secret_key, algorithm=self.algorithm)
    
    async def verify_token(self, token: str) -> str:
        """Verify JWT token and return user_id"""
        try:
            payload = jwt.decode(token, self.secret_key, algorithms=[self.algorithm])
            user_id = payload.get('sub')
            if user_id is None:
                raise ValueError('Invalid token')
            return user_id
        except jwt.ExpiredSignatureError:
            raise ValueError('Token expired')
        except jwt.InvalidTokenError:
            raise ValueError('Invalid token')
```

**Status**: ⚠️ NEEDS IMPLEMENTATION

#### 2.3 Rate Limiting
```python
# Backend: app/main.py
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

# Apply to sensitive endpoints
@app.post("/api/auth/login")
@limiter.limit("5/minute")  # Max 5 login attempts per minute
async def login(request: LoginRequest):
    """Login endpoint with rate limiting"""
    pass

@app.post("/api/auth/register")
@limiter.limit("3/hour")  # Max 3 registrations per hour per IP
async def register(request: RegisterRequest):
    """Sign up endpoint with rate limiting"""
    pass
```

**Status**: ⚠️ NEEDS VERIFICATION

#### 2.4 Input Validation
```python
# Backend: app/models/schemas.py
from pydantic import BaseModel, EmailStr, Field, validator

class RegisterRequest(BaseModel):
    email: EmailStr  # ✅ Validates email format
    password: str = Field(..., min_length=8, max_length=128)
    
    @validator('password')
    def validate_password(cls, v):
        # Password must have uppercase, lowercase, number, special char
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain number')
        if not any(c in '!@#$%^&*()_+-=[]{}|;:,.<>?' for c in v):
            raise ValueError('Password must contain special character')
        return v

class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1, max_length=128)
```

**Status**: ⚠️ NEEDS VERIFICATION

---

### 3️⃣ FIRESTORE SECURITY RULES

#### 3.1 User Data Isolation
```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ✅ Users can ONLY read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      
      // Trades subcollection
      match /trades/{tradeId} {
        allow read, write: if request.auth.uid == userId;
      }
      
      // Settings subcollection
      match /settings/{settingId} {
        allow read, write: if request.auth.uid == userId;
      }
    }
    
    // ⚠️ Public data (read-only for authenticated users)
    match /market_data/{document=**} {
      allow read: if request.auth != null;
      allow write: if false;  // ✅ PUBLIC DATA IS READ-ONLY
    }
    
    // ✅ Deny everything else
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**Status**: ⚠️ NEEDS VERIFICATION & DEPLOYMENT

#### 3.2 Admin Collection (Backend Only)
```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ✅ Admin configuration (read-only for frontend)
    match /admin/{document=**} {
      allow read: if request.auth.token.admin == true;
      allow write: if false;
    }
  }
}
```

**Status**: ⚠️ NEEDS IMPLEMENTATION

---

### 4️⃣ API SECURITY (CORS & Headers)

#### 4.1 CORS Configuration (Backend/.env)
```env
# ✅ Configured - Verify these are set
CORS_ORIGINS=https://forexcompanion-e5a28.web.app,https://forexcompanion-e5a28.firebaseapp.com
CORS_ALLOW_CREDENTIALS=true
CORS_ALLOW_METHODS=GET,POST,PUT,DELETE,OPTIONS
CORS_ALLOW_HEADERS=Authorization,Content-Type,X-CSRF-Token
```

**Status**: ✅ ALREADY CONFIGURED

#### 4.2 Security Headers (Backend)
```python
# Backend: app/main.py

@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    
    # ✅ Prevent MIME type sniffing
    response.headers["X-Content-Type-Options"] = "nosniff"
    
    # ✅ Prevent clickjacking
    response.headers["X-Frame-Options"] = "DENY"
    
    # ✅ Enable XSS protection
    response.headers["X-XSS-Protection"] = "1; mode=block"
    
    # ✅ Content Security Policy
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; "
        "script-src 'self' https://www.gstatic.com/firebasejs/; "
        "style-src 'self' 'unsafe-inline'; "
        "img-src 'self' data: https:; "
        "connect-src 'self' https://firestore.googleapis.com https://forex-backend-production-bc44.up.railway.app"
    )
    
    # ✅ Enforce HTTPS
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
    
    # ✅ Referrer policy
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    
    return response
```

**Status**: ⚠️ NEEDS IMPLEMENTATION

---

### 5️⃣ DATA PROTECTION

#### 5.1 Password Hashing
```python
# Backend: NEVER store plain text passwords
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    """Hash password using bcrypt"""
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify hashed password"""
    return pwd_context.verify(plain_password, hashed_password)
```

**Status**: ⚠️ NEEDS VERIFICATION (Firebase Auth handles this)

#### 5.2 Sensitive Data Logging
```python
# Backend: NEVER log sensitive data

# ❌ DON'T DO THIS:
logger.info(f"User login: {password}")      # NEVER
logger.info(f"API key: {api_key}")         # NEVER
logger.info(f"Credit card: {cc_number}")   # NEVER

# ✅ DO THIS:
logger.info(f"User login: {email}")        # OK
logger.info(f"User created: {user_id}")    # OK
logger.info(f"Token created for: {user_id}")  # OK (don't log token itself)
```

**Status**: ⚠️ NEEDS AUDIT

#### 5.3 Encryption for Sensitive Fields
```python
# Backend: app/services/encryption_service.py
from cryptography.fernet import Fernet
import os

class EncryptionService:
    def __init__(self):
        self.cipher = Fernet(os.getenv('ENCRYPTION_KEY').encode())
    
    def encrypt(self, data: str) -> str:
        """Encrypt sensitive data"""
        return self.cipher.encrypt(data.encode()).decode()
    
    def decrypt(self, encrypted_data: str) -> str:
        """Decrypt sensitive data"""
        return self.cipher.decrypt(encrypted_data.encode()).decode()

# Use for:
# - API keys
# - Account numbers
# - Trading account credentials
```

**Status**: ⚠️ NEEDS IMPLEMENTATION

---

### 6️⃣ AUTHENTICATION FLOW SECURITY

#### 6.1 Password Requirements
```dart
// Frontend: lib/services/password_validator.dart
class PasswordValidator {
  static bool isStrong(String password) {
    // At least 8 characters
    if (password.length < 8) return false;
    
    // At least one uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    
    // At least one lowercase letter
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    
    // At least one number
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    
    // At least one special character
    if (!password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:,.<>?]'))) return false;
    
    return true;
  }
  
  static String getRequirements() {
    return '''
    Password must contain:
    • At least 8 characters
    • At least one UPPERCASE letter
    • At least one lowercase letter
    • At least one number (0-9)
    • At least one special character (!@#$%^&*)
    ''';
  }
}
```

**Status**: ⚠️ NEEDS VERIFICATION

#### 6.2 Session Management
```dart
// Frontend: lib/services/session_service.dart
class SessionService {
  static const SESSION_TIMEOUT = Duration(minutes: 30);
  
  Future<void> startSession() async {
    // Set timer to logout after inactivity
    Timer(SESSION_TIMEOUT, () {
      logout();
    });
  }
  
  Future<void> logout() async {
    // Clear all sensitive data
    await FirebaseAuth.instance.signOut();
    // Clear local cache
    // Redirect to login
  }
}
```

**Status**: ⚠️ NEEDS IMPLEMENTATION

---

### 7️⃣ THIRD-PARTY SECURITY

#### 7.1 API Key Management
```python
# Backend: NEVER hardcode API keys

# ❌ DON'T:
BREVO_API_KEY = "xkeysib-..."  # Hardcoded - DANGEROUS

# ✅ DO:
BREVO_API_KEY = os.getenv('BREVO_API_KEY')  # From environment
```

**Status**: ✅ ALREADY DONE

#### 7.2 API Key Rotation
```
Brevo API Key: Once per year minimum
Firebase API Key: Once per year minimum
Gemini API Key: Once per year minimum

Schedule:
- Jan: Brevo key rotation
- May: Firebase key rotation
- Sep: Gemini key rotation
```

**Status**: ⚠️ NEEDS PROCESS

---

### 8️⃣ MONITORING & LOGGING

#### 8.1 Security Event Logging
```python
# Backend: app/services/audit_logger.py
import logging

audit_logger = logging.getLogger('audit')

def log_security_event(event_type: str, user_id: str, details: dict):
    """Log security-related events"""
    audit_logger.info(f"{event_type} - User: {user_id} - Details: {details}")

# Events to log:
# - USER_SIGNUP
# - USER_SIGNIN
# - USER_SIGNOUT
# - PASSWORD_CHANGED
# - EMAIL_VERIFIED
# - UNAUTHORIZED_ACCESS_ATTEMPT
# - RATE_LIMIT_EXCEEDED
# - SUSPICIOUS_ACTIVITY
```

**Status**: ⚠️ NEEDS IMPLEMENTATION

#### 8.2 Error Handling
```python
# Backend: NEVER expose internal errors to clients

# ❌ DON'T:
raise HTTPException(status_code=500, detail=str(database_error))

# ✅ DO:
logger.error(f"Database error: {str(database_error)}", exc_info=True)
raise HTTPException(
    status_code=500, 
    detail="An error occurred. Please try again later."
)
```

**Status**: ⚠️ NEEDS AUDIT

---

## ✅ COMPLETE SECURITY CHECKLIST

### Before Public Launch
```
FRONTEND SECURITY:
□ CSP headers configured
□ XSS prevention implemented
□ Input sanitization active
□ HTTPS enforcement verified
□ No sensitive data in localStorage
□ Autocomplete disabled on password fields

BACKEND SECURITY:
□ Auth required on all endpoints
□ JWT tokens validated
□ Rate limiting enforced
□ Input validation on all endpoints
□ Security headers implemented
□ CORS properly configured

FIRESTORE SECURITY:
□ User data isolation enforced
□ Public data is read-only
□ No anonymous access
□ Rules tested and deployed

DATA PROTECTION:
□ Passwords hashed (bcrypt/Firebase)
□ Sensitive data encrypted
□ No sensitive data in logs
□ API keys in environment variables
□ SSL/TLS enforced

MONITORING:
□ Security events logged
□ Error messages don't expose details
□ Audit trail maintained
□ Suspicious activity detected
□ Alerts configured

TESTING:
□ Security penetration testing done
□ OWASP Top 10 vulnerabilities checked
□ SQL injection tested
□ XSS tested
□ CSRF tested
```

---

## 🚀 IMPLEMENTATION PRIORITY

### Phase 1 (Must Have - Before Launch)
1. CSP headers
2. Auth on all endpoints
3. Input validation
4. Firestore security rules
5. Rate limiting
6. XSS prevention

### Phase 2 (Should Have - Within 1 Week)
1. Security event logging
2. Encryption service
3. Session management
4. Password policy enforcement
5. Security headers

### Phase 3 (Nice to Have - Within 1 Month)
1. Penetration testing
2. Bug bounty program
3. Security audit
4. API key rotation schedule
5. Advanced threat detection

---

## 📞 SECURITY RESOURCES

| Resource | Link |
|----------|------|
| OWASP Top 10 | https://owasp.org/www-project-top-ten/ |
| Flutter Security | https://flutter.dev/docs/testing/security-best-practices |
| FastAPI Security | https://fastapi.tiangolo.com/tutorial/security/ |
| Firestore Security | https://firebase.google.com/docs/firestore/security |
| Firebase Auth Security | https://firebase.google.com/docs/auth/best-practices |

---

## 📋 STATUS SUMMARY

| Component | Status | Action |
|-----------|--------|--------|
| HTTPS/SSL | ✅ Complete | None |
| Firebase Auth | ✅ Complete | Verify token validation |
| CORS Config | ✅ Complete | Verify CORS headers |
| Firestore Rules | ⚠️ Partial | Deploy full rules |
| Backend Auth | ⚠️ Partial | Add to all endpoints |
| Input Validation | ⚠️ Partial | Add to all endpoints |
| Rate Limiting | ⚠️ Partial | Verify implementation |
| Security Headers | ❌ Missing | Implement |
| XSS Prevention | ❌ Missing | Implement |
| Data Encryption | ❌ Missing | Implement for sensitive data |
| Logging | ❌ Missing | Implement audit logging |

---

**Next Step**: Implement Phase 1 items before public launch 🔐
