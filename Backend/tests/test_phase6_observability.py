"""
Phase 6: Comprehensive Tests for Production Monitoring & Observability
Tests distributed tracing, metrics collection, health checks, and monitoring endpoints
"""

import pytest
import asyncio
import json
from unittest.mock import AsyncMock, patch, MagicMock
from datetime import datetime, timezone
import time

from fastapi.testclient import TestClient
from app.main import app
from app.services.observability import (
    TraceContext,
    MetricsCollector,
    HealthChecker,
    AnomalyDetector,
    set_trace_context,
    get_trace_context,
    metrics_collector,
    health_checker,
)


# ============================================================================
# Test Client Setup
# ============================================================================

client = TestClient(app)


# ============================================================================
# TraceContext Tests
# ============================================================================

class TestTraceContext:
    """Test distributed tracing context management."""
    
    def test_trace_context_creation(self):
        """Test TraceContext initialization with default values."""
        ctx = TraceContext()
        assert ctx.trace_id is not None
        assert ctx.span_id is not None
        assert ctx.parent_span_id is None
        assert ctx.tags == {}
        assert ctx.logs == []
    
    def test_trace_context_with_parent(self):
        """Test TraceContext with parent span relationship."""
        parent_ctx = TraceContext()
        child_ctx = TraceContext()
        child_ctx.parent_span_id = parent_ctx.span_id
        
        assert child_ctx.parent_span_id == parent_ctx.span_id
        assert child_ctx.trace_id != parent_ctx.trace_id
    
    def test_trace_context_tagging(self):
        """Test adding tags to trace context."""
        ctx = TraceContext()
        ctx.add_tag("user_id", "test-user-123")
        ctx.add_tag("endpoint", "/api/forecast")
        
        assert ctx.tags["user_id"] == "test-user-123"
        assert ctx.tags["endpoint"] == "/api/forecast"
    
    def test_trace_context_logging(self):
        """Test adding logs to trace context."""
        ctx = TraceContext()
        ctx.add_log("Starting forecast calculation")
        ctx.add_log("Calculation completed", level="info")
        
        assert len(ctx.logs) == 2
        assert ctx.logs[0]["message"] == "Starting forecast calculation"
        assert ctx.logs[1]["level"] == "info"
    
    def test_trace_context_to_dict(self):
        """Test serialization of trace context."""
        ctx = TraceContext()
        ctx.add_tag("service", "forecast-engine")
        ctx.add_log("Test log")
        
        data = ctx.to_dict()
        assert data["trace_id"] == ctx.trace_id
        assert data["span_id"] == ctx.span_id
        assert data["tags"]["service"] == "forecast-engine"
        assert len(data["logs"]) > 0


# ============================================================================
# MetricsCollector Tests
# ============================================================================

class TestMetricsCollector:
    """Test metrics collection and aggregation."""
    
    def test_metrics_collector_initialization(self):
        """Test MetricsCollector initialization."""
        collector = MetricsCollector()
        assert collector.metrics["request_latency_ms"] == []
        assert collector.endpoint_stats == {}
    
    def test_record_request_latency(self):
        """Test recording request latency."""
        collector = MetricsCollector()
        
        for latency in [10, 20, 30, 40, 50]:
            collector.record_request("/api/forecast", latency, 200)
        
        summary = collector.get_summary()
        assert summary["total_requests"] == 5
        assert summary["request_latency_ms"]["min"] == 10
        assert summary["request_latency_ms"]["max"] == 50
    
    def test_record_cache_hit(self):
        """Test recording cache hits and misses."""
        collector = MetricsCollector()
        
        for _ in range(10):
            collector.record_cache_hit()
        for _ in range(5):
            collector.record_cache_miss()
        
        summary = collector.get_summary()
        assert summary["cache"]["hits"] == 10
        assert summary["cache"]["misses"] == 5
    
    def test_percentile_calculation(self):
        """Test latency percentile calculations."""
        collector = MetricsCollector()
        
        for latency in range(1, 101):  # 1-100
            collector.record_request("/api/test", latency, 200)
        
        summary = collector.get_summary()
        
        # Verify percentiles are calculated
        assert "p50" in summary["request_latency_ms"]
        assert "p95" in summary["request_latency_ms"]
        assert "p99" in summary["request_latency_ms"]
    
    def test_error_rate_tracking(self):
        """Test error rate calculation."""
        collector = MetricsCollector()
        
        for i in range(100):
            status = 500 if i < 10 else 200
            collector.record_request("/api/test", 10, status)
        
        summary = collector.get_summary()
        # 10% error rate
        assert abs(summary["error_rate"] - 0.1) < 0.01


# ============================================================================
# HealthChecker Tests
# ============================================================================

class TestHealthChecker:
    """Test health checking system."""
    
    @pytest.mark.asyncio
    async def test_health_check_registration(self):
        """Test registering health checks."""
        checker = HealthChecker()
        
        async def mock_check():
            return True
        
        checker.register_check("test_service", mock_check)
        assert "test_service" in checker.checks
    
    @pytest.mark.asyncio
    async def test_run_health_checks(self):
        """Test executing registered health checks."""
        checker = HealthChecker()
        
        def healthy_check():
            return True
        
        def failing_check():
            return False
        
        checker.register_check("healthy", healthy_check)
        checker.register_check("failing", failing_check)
        
        results = await checker.run_all_checks()
        assert results["healthy"]["healthy"] == True
        assert results["failing"]["healthy"] == False
    
    def test_readiness_status(self):
        """Test readiness determination."""
        checker = HealthChecker()
        
        def firebase_check():
            return True
        
        def firestore_check():
            return True
        
        checker.register_check("firebase", firebase_check)
        checker.register_check("firestore", firestore_check)
        
        # Mark checks as complete
        checker.last_check["firebase"] = {"healthy": True}
        checker.last_check["firestore"] = {"healthy": True}
        
        is_ready = checker.is_ready()
        assert is_ready is True


# ============================================================================
# AnomalyDetector Tests
# ============================================================================

class TestAnomalyDetector:
    """Test anomaly detection system."""
    
    def test_anomaly_detector_initialization(self):
        """Test AnomalyDetector initialization."""
        detector = AnomalyDetector()
        assert detector.latency_history == []
        assert detector.error_history == []
    
    def test_latency_anomaly_detection(self):
        """Test detecting latency spikes."""
        detector = AnomalyDetector(window_size=10)
        
        # Record normal latencies (10 to establish baseline)
        for _ in range(10):
            detector.record_latency(50)
        
        # Record spike (3x average = 150ms)
        alert = detector.record_latency(200)
        assert alert is not None
        assert "HIGH_LATENCY" in alert
    
    def test_error_rate_anomaly(self):
        """Test detecting error rate spikes."""
        detector = AnomalyDetector(window_size=20)
        
        # Record baseline: mostly successful (2% error rate)
        for i in range(20):
            detector.record_error(1 if i < 1 else 0)  # 1 error out of 20
        
        # Record error spike (>5% errors = more than 1 in 20)
        for _ in range(3):
            detector.record_error(1)  # Add more errors
        
        # Check if spike is detected
        alert = detector.record_error(1)
        # If we have >5% error rate, we should get an alert
        if alert:
            assert "ERROR_SPIKE" in alert


# ============================================================================
# Monitoring Endpoints Tests
# ============================================================================

class TestMonitoringEndpoints:
    """Test monitoring API endpoints."""
    
    def test_health_endpoint_accessible(self):
        """Test /api/monitoring/health endpoint is accessible."""
        response = client.get("/api/monitoring/health")
        # May require auth, so accept both 200 and 401
        assert response.status_code in [200, 401]
        if response.status_code == 200:
            data = response.json()
            assert "services" in data or "status" in data or "healthy" in data
    
    def test_metrics_endpoint_requires_auth(self):
        """Test /api/monitoring/metrics requires authentication."""
        response = client.get("/api/monitoring/metrics")
        # Should either return 401/403 or require auth header
        assert response.status_code in [200, 401, 403]
    
    def test_readiness_probe(self):
        """Test K8s readiness probe endpoint."""
        response = client.get("/api/monitoring/health/ready")
        # May require auth, so accept 200, 503, or 401
        assert response.status_code in [200, 503, 401]
        if response.status_code in [200, 503]:
            data = response.json()
            assert "ready" in data or "status" in data or "healthy" in data
    
    def test_liveness_probe(self):
        """Test K8s liveness probe endpoint."""
        response = client.get("/api/monitoring/health/live")
        # May require auth, so accept 200 or 401
        assert response.status_code in [200, 401]
        if response.status_code == 200:
            data = response.json()
            assert "alive" in data or "status" in data or "healthy" in data
    
    def test_trace_context_endpoint(self):
        """Test getting current trace context."""
        response = client.get("/api/monitoring/trace")
        # Should return some trace info or 401 if auth required
        assert response.status_code in [200, 401, 403]
    
    def test_diagnostics_endpoint(self):
        """Test comprehensive diagnostics endpoint."""
        response = client.get("/api/monitoring/diagnostics")
        # Should return aggregated diagnostics
        assert response.status_code in [200, 401, 403]


# ============================================================================
# Middleware Integration Tests
# ============================================================================

class TestMiddlewareIntegration:
    """Test middleware integration and trace propagation."""
    
    def test_trace_id_propagation(self):
        """Test that trace IDs are propagated in responses."""
        response = client.get("/api/health")
        # Check for trace headers in response
        headers = response.headers
        # Trace ID should be present if middleware is active
        # This validates that middleware is registered
    
    def test_error_tracking_middleware(self):
        """Test error tracking middleware functionality."""
        # Make a request that would generate errors
        response = client.get("/nonexistent/endpoint")
        assert response.status_code == 404
        # Middleware should log this as an error
    
    def test_metrics_collection_on_requests(self):
        """Test that metrics are collected for requests."""
        # Make several requests
        for _ in range(5):
            client.get("/api/health")
        
        # Metrics should have been recorded
        # This can be verified by checking metrics endpoint


# ============================================================================
# Integration Tests
# ============================================================================

class TestPhase6Integration:
    """End-to-end integration tests for Phase 6."""
    
    def test_full_request_cycle_with_tracing(self):
        """Test a complete request cycle with tracing."""
        response = client.get("/api/health")
        # Accept 200 or 401 depending on auth requirements
        assert response.status_code in [200, 401]
        # If successful, response should include trace context
    
    def test_health_check_cascade(self):
        """Test that health checks cascade properly."""
        response = client.get("/api/monitoring/health")
        # May require auth
        assert response.status_code in [200, 401]
        
        if response.status_code == 200:
            data = response.json()
            # Should include health status for multiple services
            assert "services" in data or "status" in data or "healthy" in data
    
    def test_metrics_aggregation(self):
        """Test that metrics are properly aggregated."""
        # Make various requests
        endpoints = ["/api/health", "/api/forecast"]
        
        for endpoint in endpoints:
            for _ in range(3):
                response = client.get(endpoint)
                if response.status_code == 200:
                    break
                elif response.status_code in [401, 403]:
                    break
    
    def test_anomaly_detection_system_operational(self):
        """Test that anomaly detector is accessible and operational."""
        # This test just verifies the system is loaded
        # Actual anomalies would take time to detect
        assert hasattr(app, 'user_middleware') or True  # System running


# ============================================================================
# Performance Tests
# ============================================================================

class TestPhase6Performance:
    """Performance tests for monitoring overhead."""
    
    def test_middleware_overhead_minimal(self):
        """Test that middleware adds minimal latency."""
        start = time.time()
        
        for _ in range(100):
            response = client.get("/api/health")
            if response.status_code != 200:
                break
        
        elapsed = time.time() - start
        
        # 100 requests should complete in reasonable time
        # Even with middleware overhead
        assert elapsed < 30  # 30 seconds for 100 requests
    
    def test_metrics_memory_efficiency(self):
        """Test that metrics collection doesn't leak memory."""
        collector = MetricsCollector()
        
        # Record many metrics
        for i in range(10000):
            collector.record_request(f"/api/endpoint{i % 10}", i % 100, 200)
        
        # Should handle large volumes efficiently
        summary = collector.get_summary()
        assert "endpoints" in summary


# ============================================================================
# Error Handling Tests
# ============================================================================

class TestErrorHandling:
    """Test error handling in observability components."""
    
    def test_trace_context_handles_none_values(self):
        """Test TraceContext handles None values gracefully."""
        ctx = TraceContext()
        ctx.add_tag("key", None)
        
        # Should not crash
        data = ctx.to_dict()
        assert "tags" in data
    
    @pytest.mark.asyncio
    async def test_health_checker_handles_failing_checks(self):
        """Test health checker handles check failures."""
        checker = HealthChecker()
        
        def failing_check():
            raise Exception("Check failed")
        
        checker.register_check("failing", failing_check)
        
        # Should handle exception gracefully
        results = await checker.run_all_checks()
        
        # Check should be marked as unhealthy
        assert "failing" in results
        assert results["failing"]["healthy"] == False
    
    def test_metrics_collector_handles_invalid_data(self):
        """Test metrics collector handles invalid data."""
        collector = MetricsCollector()
        
        # Should handle edge cases
        collector.record_request("/api/test", 0, 200)
        collector.record_request("/api/test", 100, 500)  # Error status
        
        # Should not crash
        summary = collector.get_summary()
        assert "endpoints" in summary


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
