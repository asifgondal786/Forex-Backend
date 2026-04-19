from app.config.audit import build_config_snapshot, hash_config
from app.config.index import load_config


def _env() -> dict[str, str]:
    return {
        "ENVIRONMENT": "production",
        "NODE_ENV": "production",
        "DEBUG": "false",
        "CONFIG_VALIDATION_FAIL_FAST": "true",
        "FIREBASE_PROJECT_ID": "forexcompanion-e5a28",
        "FRONTEND_APP_URL": "https://forexcompanion-e5a28.web.app",
        "EMAIL_VERIFICATION_CONTINUE_URL": "https://forexcompanion-e5a28.web.app/verify",
        "PASSWORD_RESET_CONTINUE_URL": "https://forexcompanion-e5a28.web.app/reset",
        "EMAIL_PROVIDER": "brevo",
        "BREVO_FROM_EMAIL": "forexcompanionauto@gmail.com",
        "FIREBASE_API_KEY": "AIzaSyExampleFirebaseKey1234567890",
        "BREVO_API_KEY": "xkeysib-example",
        "CORS_ALLOW_ALL": "false",
        "AUTH_RATE_LIMIT_ENABLED": "true",
        "RATE_LIMIT_ENABLED": "true",
    }


def test_hash_config_changes_when_sensitive_flags_change():
    env_a = _env()
    env_b = _env()
    env_b["DEBUG"] = "true"
    config_a = load_config(env_a)
    config_b = load_config(env_b)

    assert hash_config(config_a) != hash_config(config_b)


def test_build_config_snapshot_contains_expected_fields():
    config = load_config(_env())
    snapshot = build_config_snapshot(config)
    assert snapshot["event"] == "config_snapshot"
    assert "config_hash" in snapshot
    assert "snapshot" in snapshot
    assert snapshot["snapshot"]["environment"] == "production"
