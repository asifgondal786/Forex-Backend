# Phase 6: Production Monitoring - Quick Reference Guide

## Quick Start: Using the Monitoring System

### 1. Starting the Backend with Monitoring

```bash
cd Backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

All monitoring endpoints are automatically available on startup.

### 2. Core Monitoring Endpoints

#### Health Status
```bash
# Check if system is healthy
curl http://localhost:8000/api/monitoring/health

# Check if ready to accept traffic (Kubernetes readiness)
curl http://localhost:8000/api/monitoring/health/ready

# Check if system is alive (Kubernetes liveness)
curl http://localhost:8000/api/monitoring/health/live
```

#### Metrics & Performance
```bash
# Get comprehensive metrics (requires auth)
curl -H "Authorization: Bearer <token>" \
  http://localhost:8000/api/monitoring/metrics

# Get per-endpoint statistics (requires auth)
curl -H "Authorization: Bearer <token>" \
  http://localhost:8000/api/monitoring/endpoints

# Get diagnostic information
curl http://localhost:8000/api/monitoring/diagnostics
```

#### Tracing Information
```bash
# Get current request trace context
curl http://localhost:8000/api/monitoring/trace
```

### 3. Trace ID Correlation

Every request returns trace identification headers:

```
X-Trace-ID: [UUID] - Unique identifier for entire request trace
X-Span-ID: [UUID] - Unique identifier for this request segment
X-Parent-Span-ID: [UUID] - Parent span if this is a nested call
```

**Usage**: Use the X-Trace-ID from responses to correlate logs and metrics across services.

### 4. Understanding Metrics Output

**MetricsCollector** tracks:

```json
{
  "total_requests": 150,
  "success_count": 145,
  "error_count": 5,
  "error_rate": 0.0333,
  "request_latency_ms": {
    "min": 5,
    "max": 250,
    "avg": 45.2,
    "p50": 40,
    "p95": 120,
    "p99": 200
  },
  "cache": {
    "hits": 450,
    "misses": 50,
    "hit_rate": 0.9
  },
  "database": {
    "total_queries": 200,
    "avg_query_time_ms": 15.5
  },
  "endpoints": {
    "/api/forecast": {
      "total_requests": 50,
      "total_latency_ms": 2500,
      "error_count": 1,
      "last_called": "2024-01-15T10:30:45.123Z",
      "p95_latency_ms": 95
    }
  }
}
```

### 5. Health Check Status

```json
{
  "services": {
    "firebase": {
      "status": "healthy",
      "response_time_ms": 12.3
    },
    "redis": {
      "status": "healthy",
      "response_time_ms": 5.1
    },
    "firestore": {
      "status": "healthy",
      "response_time_ms": 34.2
    }
  },
  "ready": true
}
```

**Status Values**:
- `healthy`: Service is operating normally
- `unhealthy`: Service is not responding
- `degraded`: Service is responding but slow

### 6. Running Tests

#### Run all Phase 6 tests:
```bash
cd Backend
python -m pytest tests/test_phase6_observability.py -v
```

#### Run specific test suite:
```bash
# Test TraceContext only
python -m pytest tests/test_phase6_observability.py::TestTraceContext -v

# Test MetricsCollector only
python -m pytest tests/test_phase6_observability.py::TestMetricsCollector -v

# Test monitoring endpoints
python -m pytest tests/test_phase6_observability.py::TestMonitoringEndpoints -v
```

#### Run with coverage:
```bash
python -m pytest tests/test_phase6_observability.py --cov=app.services.observability --cov=app.middleware.observability_middleware
```

### 7. Trace Context Example Flow

```
Request to /api/forecast
  ↓
DistributedTracingMiddleware creates:
  - trace_id: "550e8400-e29b-41d4-a716-446655440000"
  - span_id: "660f9511-f40c-52e5-b827-557766551111"
  ↓
RequestValidationMiddleware adds tags:
  - user_id: "user123"
  - endpoint: "/api/forecast"
  ↓
MetricsMiddleware records:
  - latency_ms: 45
  - status: 200
  ↓
Response includes headers:
  - X-Trace-ID: 550e8400-e29b-41d4-a716-446655440000
  - X-Span-ID: 660f9511-f40c-52e5-b827-557766551111
  ↓
Client can use X-Trace-ID to find logs
```

### 8. Anomaly Detection Alerts

The system automatically detects:

**Latency Spikes**:
- Alert when p95 latency > 3x baseline average
- Example: Baseline 50ms, Alert when > 150ms

**Error Spikes**:
- Alert when error rate > 5% above baseline
- Example: Baseline 1%, Alert when > 6%

**Access Log Anomalies**:
- Monitor endpoint status codes
- Track per-endpoint error rates

### 9. Integration with External Monitoring

#### Prometheus Format (via /api/monitoring/metrics)
```
# Request metrics
request_latency_p95{endpoint="/api/forecast"} 120
request_error_rate{endpoint="/api/forecast"} 0.01
cache_hit_rate{cache="forexrates"} 0.95

# Health metrics
component_health{component="firebase"} 1
component_health{component="redis"} 1
```

#### Trace Export
```bash
# Get trace in JSON format
curl http://localhost:8000/api/monitoring/trace | jq '.' 
```

### 10. Kubernetes Deployment

Add to your Kubernetes deployment YAML:

```yaml
livenessProbe:
  httpGet:
    path: /api/monitoring/health/live
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /api/monitoring/health/ready
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 10
```

### 11. Common Issues & Troubleshooting

**Problem**: Metrics endpoint returns 401 Unauthorized
- **Solution**: Add Bearer token: `Authorization: Bearer <your_token>`

**Problem**: Health checks show "unhealthy" for Redis
- **Solution**: Redis is optional. System will continue with memory-based cache
- **Check**: Verify REDIS_URL environment variable if needed

**Problem**: Trace IDs not propagating between services
- **Solution**: Ensure X-Trace-ID header is passed in outbound requests
- **Implementation**: Use `ctx.to_headers()` when making inter-service calls

**Problem**: High latency percentiles but low average
- **Solution**: Indicates outlier requests. Check error logs at that timestamp
- **Action**: Use X-Trace-ID to find corresponding logs

### 12. Performance Tuning Tips

**Reduce Monitoring Overhead**:
1. Metrics collection is asynchronous - no blocking
2. Health checks run in parallel
3. Trace context uses memory-efficient UUID format

**Optimize Alerting**:
1. Set p95 thresholds above 99% of normal operations
2. Allow 5-10 minute grace period for metric stabilization
3. Correlate latency with CPU/memory metrics

**Scale Monitoring**:
1. For multi-instance deployments, use Redis-backed metrics
2. Configure log aggregation for trace export
3. Use Prometheus scraping for long-term analytics

## Key Files

| File | Purpose | Key Classes |
|------|---------|-------------|
| `app/services/observability.py` | Core observability | TraceContext, MetricsCollector, HealthChecker, AnomalyDetector |
| `app/middleware/observability_middleware.py` | Request instrumentation | DistributedTracingMiddleware, ErrorTrackingMiddleware, MetricsMiddleware |
| `app/monitoring_routes.py` | Monitoring API | monitoring_router with 7 endpoints |
| `app/main.py` | Integration point | Middleware registration, health check setup |
| `tests/test_phase6_observability.py` | Test suite | 34 comprehensive tests |

## Environment Variables

None required for Phase 6! All configuration is automatic.

Optional:
- `MONITORING_ROUTES_AVAILABLE`: Auto-detected (defaults to True if imports work)
- `REDIS_URL`: For Redis-backed metrics (optional for scaling)

## Next Steps

1. **Deploy to production** with monitoring enabled
2. **Configure alerting** based on your SLAs
3. **Monitor baseline metrics** for first 24 hours
4. **Set up dashboards** in monitoring tool (Grafana, DataDog, etc.)
5. **Create runbooks** for common alerts

## Support & Documentation

- **API Documentation**: Auto-generated at `/docs` (Swagger UI)
- **Test Suite**: `tests/test_phase6_observability.py`
- **Implementation Docs**: See individual module docstrings
- **Monitoring Guide**: This file

---

**Phase 6 is fully integrated and production-ready!** 🚀
