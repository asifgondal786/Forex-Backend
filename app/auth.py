from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import firebase_admin
from firebase_admin import auth as firebase_auth, credentials
import os, base64, json

# Initialize Firebase app once
if not firebase_admin._apps:
    b64 = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON_B64", "")
    if b64:
        svc = json.loads(base64.b64decode(b64).decode("utf-8"))
        cred = credentials.Certificate(svc)
        firebase_admin.initialize_app(cred)
    else:
        firebase_admin.initialize_app()  # will use ADC if available

_bearer = HTTPBearer(auto_error=True)

async def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(_bearer),
) -> dict:
    token = creds.credentials
    try:
        decoded = firebase_auth.verify_id_token(token)
        return decoded          # dict with uid, email, etc.
    except firebase_auth.ExpiredIdTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Token expired")
    except firebase_auth.InvalidIdTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Invalid token")
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail=f"Auth error: {exc}")
