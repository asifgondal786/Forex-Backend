from app.config.validate_env import validate_environment


def _base_env() -> dict[str, str]:
    return {
        "ENVIRONMENT": "development",
        "NODE_ENV": "development",
        "DEBUG": "true",
        "FIREBASE_PROJECT_ID": "forexcompanion-e5a28",
        "FRONTEND_APP_URL": "http://localhost:3000",
        "EMAIL_VERIFICATION_CONTINUE_URL": "http://localhost:3000/verify",
        "PASSWORD_RESET_CONTINUE_URL": "http://localhost:3000/reset",
        "EMAIL_PROVIDER": "brevo",
        "BREVO_FROM_EMAIL": "forexcompanionauto@gmail.com",
        "CORS_ALLOW_ALL": "true",
        "CORS_ORIGINS": "http://localhost:3000",
        "AUTH_RATE_LIMIT_ENABLED": "false",
        "RATE_LIMIT_ENABLED": "false",
    }


def test_validate_environment_accepts_development_defaults():
    result = validate_environment(_base_env())
    assert result.ok


def test_validate_environment_flags_debug_in_production():
    env = _base_env()
    env.update(
        {
            "ENVIRONMENT": "production",
            "NODE_ENV": "production",
            "DEBUG": "true",
            "CORS_ALLOW_ALL": "false",
            "CORS_ORIGINS": "https://forexcompanion-e5a28.web.app",
            "FRONTEND_APP_URL": "https://forexcompanion-e5a28.web.app",
            "EMAIL_VERIFICATION_CONTINUE_URL": "https://forexcompanion-e5a28.web.app/verify",
            "PASSWORD_RESET_CONTINUE_URL": "https://forexcompanion-e5a28.web.app/reset",
            "AUTH_RATE_LIMIT_ENABLED": "true",
            "RATE_LIMIT_ENABLED": "true",
            "FIREBASE_API_KEY": "AIzaSyExampleFirebaseKey1234567890",
            "BREVO_API_KEY": "xkeysib-example",
        }
    )
    result = validate_environment(env)
    assert any(issue.code == "debug_enabled_in_production" for issue in result.errors)


def test_validate_environment_flags_frontend_typo():
    env = _base_env()
    env["FRONTEND_APP_URL"] = "https://forexcompanione5a28.web.app"
    result = validate_environment(env)
    assert any(issue.code == "frontend_domain_typo" for issue in result.errors)


def test_validate_environment_requires_secrets_in_production():
    env = _base_env()
    env.update(
        {
            "ENVIRONMENT": "production",
            "NODE_ENV": "production",
            "DEBUG": "false",
            "CORS_ALLOW_ALL": "false",
            "CORS_ORIGINS": "https://forexcompanion-e5a28.web.app",
            "FRONTEND_APP_URL": "https://forexcompanion-e5a28.web.app",
            "EMAIL_VERIFICATION_CONTINUE_URL": "https://forexcompanion-e5a28.web.app/verify",
            "PASSWORD_RESET_CONTINUE_URL": "https://forexcompanion-e5a28.web.app/reset",
            "AUTH_RATE_LIMIT_ENABLED": "true",
            "RATE_LIMIT_ENABLED": "true",
            "FIREBASE_API_KEY": "your_firebase_web_api_key",
            "BREVO_API_KEY": "your_brevo_api_key",
        }
    )
    result = validate_environment(env)
    missing_secret_errors = [e for e in result.errors if e.code == "missing_required_secret"]
    assert missing_secret_errors


def test_validate_environment_accepts_hardened_production_values():
    env = _base_env()
    env.update(
        {
            "ENVIRONMENT": "production",
            "NODE_ENV": "production",
            "DEBUG": "false",
            "CORS_ALLOW_ALL": "false",
            "CORS_ORIGINS": "https://forexcompanion-e5a28.web.app,https://forexcompanion-e5a28.firebaseapp.com",
            "FRONTEND_APP_URL": "https://forexcompanion-e5a28.web.app",
            "EMAIL_VERIFICATION_CONTINUE_URL": "https://forexcompanion-e5a28.web.app/verify",
            "PASSWORD_RESET_CONTINUE_URL": "https://forexcompanion-e5a28.web.app/reset",
            "AUTH_RATE_LIMIT_ENABLED": "true",
            "RATE_LIMIT_ENABLED": "true",
            "FIREBASE_API_KEY": "AIzaSyExampleFirebaseKey1234567890",
            "BREVO_API_KEY": "xkeysib-example",
            "AI_ROUTES_AVAILABLE": "false",
        }
    )
    result = validate_environment(env)
    assert result.ok
