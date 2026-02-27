#!/usr/bin/env python3
"""
QUICK REFERENCE: Steps 1-3 Implementation
==========================================

Track what you've built and how to use it.
"""

# ============================================================================
# EXAMPLE 1: Enable Slack Alert Webhooks (Step 1)
# ============================================================================
"""
Setup:
1. Create a Slack webhook at https://api.slack.com/apps
2. Add to .env or environment:
   
   OPS_ALERT_HOOKS_ENABLED=true
   OPS_ALERT_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
   OPS_ALERT_WEBHOOK_PROVIDER=slack
   OPS_ALERT_WEBHOOK_MIN_SEVERITY=warning
   OPS_ALERT_WEBHOOK_TIMEOUT_SECONDS=5

3. Run your app - it will automatically post alerts to Slack on:
   - Queue depth > threshold
   - WebSocket connection issues
   - Forex stream delays
   
4. Alerts appear as:
   [OPS_ALERT_TRIGGERED] queue_depth_warning: Task queue depth is high
   [OPS_ALERT_WEBHOOK] posting to Slack...
   
5. When alert clears:
   [OPS_ALERT_RESOLVED] queue_depth_warning
   [OPS_ALERT_WEBHOOK] posting resolved event to Slack...
"""

# ============================================================================
# EXAMPLE 2: Enable Discord Webhooks (Step 1)
# ============================================================================
"""
Setup:
1. Create Discord webhook in Server Settings → Integrations → Webhooks
2. Copy webhook URL
3. Add to .env:
   
   OPS_ALERT_WEBHOOK_URL=https://discordapp.com/api/webhooks/YOUR/WEBHOOK
   OPS_ALERT_WEBHOOK_PROVIDER=discord  # or 'auto' for auto-detection
   
4. Alerts automatically format as Discord embeds
"""

# ============================================================================
# EXAMPLE 3: Enable Redis for Scaling (Step 2)
# ============================================================================
"""
Setup:
1. Install Redis locally or in your cluster:
   
   # Docker
   docker run -d -p 6379:6379 redis:7-alpine
   
   # Or local installation
   brew install redis
   redis-server
   
2. Add to .env:
   
   REDIS_ENABLED=true
   REDIS_URL=redis://localhost:6379/0
   TASK_QUEUE_BACKEND=redis
   
3. Start your app - it will automatically:
   - Connect to Redis on startup
   - Use Redis for task queue
   - Fall back to memory if Redis unavailable
   
4. Observe logs:
   [Redis] Connected to redis://localhost:6379/0
   [TaskQueue] Started backend=redis (requested=redis) workers=2, max_size=200
   
5. Multiple instances can now share the task queue across machines!
"""

# ============================================================================
# EXAMPLE 4: Verify Fallback Works (Step 3)
# ============================================================================
"""
1. Stop Redis intentionally:
   redis-cli shutdown
   
2. Restart your app - it should fall back:
   [Redis] Connection failed: Connection refused
   [Redis] Retry in 5 seconds
   [TaskQueue] Redis backend unavailable; falling back to memory.
   [TaskQueue] Started backend=memory (requested=redis) workers=2, max_size=200
   
3. App continues working with memory queue (single instance only)
   
4. Restart Redis:
   redis-server
   
5. Restart app - it reconnects automatically
"""

# ============================================================================
# EXAMPLE 5: Monitor Task Queue (Step 2)
# ============================================================================
"""
Query queue status via API:
GET /api/ops/status (includes queue section)

Response:
{
  "queue": {
    "started": true,
    "backend": "redis",              # or "memory"
    "backend_requested": "redis",    # what we wanted
    "workers": 2,                    # number of workers
    "queue_size": 5,                 # pending tasks
    "enqueued": 150,                 # total ever queued
    "completed": 145,                # successfully processed
    "failed": 0,                     # failed tasks
    "registered_handlers": [         # available task types
      "market_analysis",
      "auto_trade",
      "forecast"
    ],
    "redis_queue_key": "forex:task_queue"
  }
}
"""

# ============================================================================
# EXAMPLE 6: Custom Auth for Webhooks (Step 1)
# ============================================================================
"""
If your webhook requires authentication:

1. Add to .env:
   
   OPS_ALERT_WEBHOOK_AUTH_HEADER=Authorization
   OPS_ALERT_WEBHOOK_AUTH_VALUE=Bearer your-secret-token
   
2. Or for custom headers:
   
   OPS_ALERT_WEBHOOK_AUTH_HEADER=X-Custom-Header
   OPS_ALERT_WEBHOOK_AUTH_VALUE=secret-value
   
3. Header is automatically added to all webhook requests
"""

# ============================================================================
# EXAMPLE 7: Tune Redis Connection (Step 2)
# ============================================================================
"""
If Redis is slow or distant:

1. Increase timeouts in .env:
   
   REDIS_CONNECT_TIMEOUT_SECONDS=5   # was 2
   REDIS_SOCKET_TIMEOUT_SECONDS=5    # was 2
   REDIS_RETRY_SECONDS=10            # was 5
   
2. Monitor connection logs:
   [Redis] Connected to redis://...
   [Redis] Connection failed: timeout
   [Redis] Retry in 10 seconds
"""

# ============================================================================
# EXAMPLE 8: Scale Workers (Step 2)
# ============================================================================
"""
Adjust task queue concurrency:

1. In .env:
   
   TASK_QUEUE_WORKERS=4     # was 2
   TASK_QUEUE_MAX_SIZE=500  # was 200
   
2. With Redis backend, each instance gets its own workers
   - Instance 1: 4 workers consuming from Redis queue
   - Instance 2: 4 workers consuming from Redis queue
   - Instance 3: 4 workers consuming from Redis queue
   
3. Total throughput = 12 concurrent tasks across cluster!
"""

# ============================================================================
# EXAMPLE 9: Debug Mode - Check What's Enabled (Step 3)
# ============================================================================
"""
From Python console:

from app.services.redis_store import redis_store
from app.services.task_queue_service import task_queue_service

# Check Redis status
print(redis_store.is_enabled())   # True if REDIS_ENABLED or TASK_QUEUE_BACKEND=redis
print(redis_store.is_connected()) # True if connected now

# Check queue status
stats = task_queue_service.get_stats()
print(stats['backend'])           # 'redis' or 'memory'
print(stats['backend_requested']) # What we wanted
print(stats['registered_handlers'])  # Available task types
"""

# ============================================================================
# EXAMPLE 10: Testing Without Redis (Step 3)
# ============================================================================
"""
Run test suite - no live Redis required:

# All 35 tests pass without Redis server:
pytest tests/test_ops_routes.py tests/test_task_queue_service.py tests/test_redis_fallback_integration.py -v

# Or just the Redis/fallback tests:
pytest tests/test_redis_fallback_integration.py -v

# Specific test:
pytest tests/test_redis_fallback_integration.py::test_redis_store_is_disabled_when_no_env_vars -v

Result: 35 passed in 4.96s
"""

# ============================================================================
# ENVIRONMENT VARIABLES SUMMARY
# ============================================================================
"""
Complete list of new environment variables:

# Step 1: Webhook Alerts
OPS_ALERT_HOOKS_ENABLED=true
OPS_ALERT_WEBHOOK_URL=https://hooks.slack.com/...
OPS_ALERT_WEBHOOK_PROVIDER=auto|discord|slack|generic
OPS_ALERT_WEBHOOK_MIN_SEVERITY=info|warning|critical
OPS_ALERT_WEBHOOK_TIMEOUT_SECONDS=5
OPS_ALERT_WEBHOOK_AUTH_HEADER=Authorization
OPS_ALERT_WEBHOOK_AUTH_VALUE=Bearer <token>

# Step 2: Redis Configuration
REDIS_ENABLED=false|true
REDIS_URL=redis://localhost:6379/0
REDIS_CONNECT_TIMEOUT_SECONDS=2
REDIS_SOCKET_TIMEOUT_SECONDS=2
REDIS_RETRY_SECONDS=5

# Step 2: Task Queue
TASK_QUEUE_BACKEND=memory|redis
TASK_QUEUE_WORKERS=2
TASK_QUEUE_MAX_SIZE=200
TASK_QUEUE_REDIS_KEY=forex:task_queue
TASK_QUEUE_REDIS_BLOCK_SECONDS=1

# Step 2: WebSocket Registry
WS_REDIS_REGISTRY_KEY=forex:ws:registry
WS_REDIS_REGISTRY_ENABLED=false|true
"""

# ============================================================================
# TEST RESULTS SUMMARY
# ============================================================================
"""
✅ Step 1: Webhook Alerts (5 tests)
   - test_ops_status_endpoint
   - test_ops_alerts_endpoint
   - test_ops_metrics_endpoint
   - test_emit_alert_hooks_sends_webhook_on_trigger_and_resolve
   - test_ops_readiness_endpoint

✅ Step 2: Task Queue Service (3 tests)
   - test_enqueue_returns_false_when_not_started
   - test_queue_executes_enqueued_tasks
   - test_queue_reports_failed_task

✅ Step 3: Redis Fallback Integration (27 tests)
   - Unit tests: Fallback & Safety (11 tests)
   - Integration tests: Mock Redis (6 tests)
   - Task Queue tests (5 tests)
   - Combined integration tests (5 tests)

TOTAL: 35 passed, 0 failed ✅
"""

# ============================================================================
# WHAT YOU CAN DO NOW
# ============================================================================
"""
1. ✅ Send ops alerts to Slack/Discord/custom webhooks
   - Automatically formatted
   - Severity filtering
   - Authentication support
   - Fallback to console

2. ✅ Scale task queue with Redis
   - Distribute tasks across machines
   - Automatic fallback to memory
   - No single point of failure
   - Graceful degradation

3. ✅ Monitor everything you built
   - /api/ops/status - Full status
   - /api/ops/alerts - Alert list
   - /api/ops/metrics - Prometheus metrics
   - /api/ops/readiness - Health check

4. ✅ Test everything without infrastructure
   - 35 test cases
   - No live Redis needed
   - Runs in <5 seconds
   - Suitable for CI/CD

5. ✅ Scale WebSocket registry with Redis
   - Multiple instances share connection registry
   - Real-time sync across machines
   - Fallback to single-instance memory registry
"""

# ============================================================================
# NEXT ITERATION IDEAS
# ============================================================================
"""
After validating Step 3:

1. Add circuit breaker for Redis failures
   - Track consecutive failures
   - Disable Redis after N failures
   - Re-enable after cooldown

2. Add metrics/observability
   - Prometheus metrics for queue depth
   - Latency tracking
   - Worker utilization

3. Add rate limiting for webhooks
   - Don't spam on repeated alerts
   - Deduplicate similar alerts
   - Add alert batching

4. Add dead-letter queue
   - Capture failed tasks
   - Replay mechanism
   - Analysis/debugging

5. Add alert escalation
   - Retry webhooks with backoff
   - Multiple channel support
   - Human-in-the-loop
"""
