"""
Phase 7: Production Auth Validator
Verifies all endpoints have proper authentication
"""

import os
import inspect
from typing import Dict, List, Tuple
from pathlib import Path


class AuthValidator:
    """Validates authentication requirements across all endpoints."""
    
    # Endpoints that MUST require authentication
    PROTECTED_PATTERNS = {
        "/api/accounts",
        "/api/ai-task",
        "/api/advanced-features",
        "/api/settings",
        "/api/subscriptions",
        "/api/notifications",
        "/api/engagement",
        "/api/credential-vault",
        "/api/trading",
        "/api/analysis",
        "/api/forecasts",
    }
    
    # Endpoints that MUST be public (no auth required)
    PUBLIC_PATTERNS = {
        "/api/public/auth/register",
        "/api/public/auth/login",
        "/api/health",
        "/docs",
        "/openapi.json",
        "/favicon.ico",
    }
    
    def __init__(self, app_dir: str = "Backend/app"):
        self.app_dir = Path(app_dir)
        self.issues: List[Dict] = []
        self.protected_endpoints: List[Tuple[str, str, bool]] = []
    
    def scan_routes(self) -> None:
        """Scan all route files for auth requirements."""
        route_files = list(self.app_dir.glob("*_routes.py"))
        
        for route_file in route_files:
            with open(route_file, 'r') as f:
                content = f.read()
            
            # Extract route patterns
            lines = content.split('\n')
            for i, line in enumerate(lines):
                # Check for route decorators
                if '@router.get' in line or '@router.post' in line or '@router.put' in line or '@router.delete' in line:
                    # Extract path
                    path_match = self._extract_path(line)
                    if path_match:
                        # Check if next lines have get_current_user_id
                        has_auth = self._check_auth_in_next_lines(lines, i)
                        
                        # Determine if should have auth
                        should_have_auth = self._should_have_auth(path_match)
                        
                        # Record the endpoint
                        self.protected_endpoints.append((
                            str(route_file.name),
                            path_match,
                            has_auth
                        ))
                        
                        # Check for violations
                        if should_have_auth and not has_auth:
                            self.issues.append({
                                "file": str(route_file.name),
                                "path": path_match,
                                "issue": "Missing authentication on protected endpoint",
                                "severity": "HIGH"
                            })
                        elif not should_have_auth and has_auth and path_match not in self.PUBLIC_PATTERNS:
                            self.issues.append({
                                "file": str(route_file.name),
                                "path": path_match,
                                "issue": "Authentication on public endpoint",
                                "severity": "LOW"
                            })
    
    def _extract_path(self, line: str) -> str:
        """Extract path from route decorator."""
        try:
            start = line.find('"') + 1
            end = line.find('"', start)
            if start > 0 and end > start:
                return line[start:end]
        except:
            pass
        return ""
    
    def _check_auth_in_next_lines(self, lines: List[str], start_idx: int) -> bool:
        """Check if next 5 lines contain get_current_user_id."""
        for i in range(start_idx + 1, min(start_idx + 6, len(lines))):
            if "get_current_user_id" in lines[i]:
                return True
        return False
    
    def _should_have_auth(self, path: str) -> bool:
        """Determine if path should require authentication."""
        # Public endpoints - no auth required
        for public_pattern in self.PUBLIC_PATTERNS:
            if path == public_pattern or path.startswith(public_pattern):
                return False
        
        # Protected endpoints - auth required
        for protected_pattern in self.PROTECTED_PATTERNS:
            if path.startswith(protected_pattern):
                return True
        
        # Default: require auth for safety
        return True
    
    def get_report(self) -> Dict:
        """Get validation report."""
        return {
            "total_endpoints": len(self.protected_endpoints),
            "protected_endpoints": [ep for ep in self.protected_endpoints if ep[2]],
            "unprotected_endpoints": [ep for ep in self.protected_endpoints if not ep[2]],
            "issues": self.issues,
            "issues_count": len(self.issues),
            "critical_issues": [i for i in self.issues if i.get("severity") == "HIGH"],
        }
    
    def print_report(self) -> None:
        """Print validation report."""
        report = self.get_report()
        
        print("\n" + "="*60)
        print("PHASE 7: AUTH VALIDATION REPORT")
        print("="*60)
        
        print(f"\nTotal Endpoints Scanned: {report['total_endpoints']}")
        print(f"Protected Endpoints: {len(report['protected_endpoints'])}")
        print(f"Unprotected Endpoints: {len(report['unprotected_endpoints'])}")
        print(f"\nIssues Found: {report['issues_count']}")
        print(f"Critical Issues: {len(report['critical_issues'])}")
        
        if report['issues']:
            print("\n" + "-"*60)
            print("ISSUES:")
            for issue in report['issues']:
                severity = issue.get('severity', 'UNKNOWN')
                print(f"  [{severity}] {issue['file']}: {issue['path']}")
                print(f"         {issue['issue']}")
        
        if report['critical_issues']:
            print("\n" + "-"*60)
            print("CRITICAL ISSUES REQUIRING FIX:")
            for issue in report['critical_issues']:
                print(f"  - {issue['file']}: {issue['path']}")
            print("\nAction Required: Add get_current_user_id dependency to marked endpoints")
        else:
            print("\n" + "✓"*60)
            print("✓ All endpoints properly authenticated!")
            print("✓ Phase 7 Auth Validation: PASSED")


class RateLimitValidator:
    """Validates rate limiting configuration."""
    
    def __init__(self):
        self.limits = {
            "/api/ai-task": (10, "minute"),      # High-compute
            "/api/advanced-features": (20, "minute"),  # Medium-compute
            "/api/accounts": (50, "minute"),     # Low-compute
            "/api/trading": (30, "minute"),      # Medium-compute
            "/api/forecasts": (50, "minute"),    # Low-compute
            "/api/public/auth": (5, "minute"),   # Auth endpoints
        }
    
    def validate(self) -> Dict:
        """Validate rate limiting configuration."""
        try:
            # Check if rate limiting middleware exists
            middleware_file = Path("Backend/app/middleware/rate_limiting.py")
            if not middleware_file.exists():
                return {
                    "status": "MISSING",
                    "message": "rate_limiting.py middleware not found",
                    "file": str(middleware_file)
                }
            
            with open(middleware_file, 'r') as f:
                content = f.read()
            
            # Check for rate limit implementation
            checks = {
                "has_rate_limit_check": "rate_limit" in content.lower(),
                "has_request_counting": "request_count" in content.lower() or "window" in content.lower(),
                "has_429_response": "429" in content,
            }
            
            return {
                "status": "CONFIGURED",
                "checks": checks,
                "limits": self.limits,
                "all_configured": all(checks.values())
            }
        except Exception as e:
            return {
                "status": "ERROR",
                "error": str(e)
            }


class AsyncSafetyValidator:
    """Validates async/await patterns."""
    
    BLOCKING_PATTERNS = [
        "requests.get",
        "requests.post",
        "requests.put",
        ".get()",  # Synchronous dict.get() in async
        ".execute()",
        "time.sleep",
    ]
    
    def __init__(self, app_dir: str = "Backend/app"):
        self.app_dir = Path(app_dir)
        self.issues: List[Dict] = []
    
    def scan_files(self) -> None:
        """Scan for potential blocking calls in async code."""
        py_files = list(self.app_dir.rglob("*.py"))
        
        for py_file in py_files:
            with open(py_file, 'r') as f:
                content = f.read()
            
            lines = content.split('\n')
            in_async_function = False
            
            for i, line in enumerate(lines):
                if "async def " in line:
                    in_async_function = True
                elif line.startswith("def ") or line.startswith("class "):
                    in_async_function = False
                
                if in_async_function:
                    for pattern in self.BLOCKING_PATTERNS:
                        if pattern in line and "await" not in line:
                            self.issues.append({
                                "file": str(py_file),
                                "line": i + 1,
                                "pattern": pattern,
                                "issue": f"Potential blocking call in async function: {line.strip()}"
                            })
    
    def get_report(self) -> Dict:
        """Get async safety report."""
        return {
            "total_issues": len(self.issues),
            "issues": self.issues,
            "status": "PASS" if not self.issues else "REVIEW_NEEDED"
        }


if __name__ == "__main__":
    # Run validators
    print("\n" + "="*60)
    print("PHASE 7: PRODUCTION HARDENING VALIDATION")
    print("="*60)
    
    # Auth validation
    print("\n1. AUTH VALIDATION")
    auth_validator = AuthValidator()
    auth_validator.scan_routes()
    auth_validator.print_report()
    
    # Rate limiting validation
    print("\n2. RATE LIMITING VALIDATION")
    rate_validator = RateLimitValidator()
    rate_report = rate_validator.validate()
    print(f"Status: {rate_report.get('status')}")
    print(f"Configured: {rate_report.get('all_configured', False)}")
    
    # Async safety validation
    print("\n3. ASYNC SAFETY VALIDATION")
    async_validator = AsyncSafetyValidator()
    async_validator.scan_files()
    async_report = async_validator.get_report()
    print(f"Status: {async_report['status']}")
    print(f"Issues Found: {async_report['total_issues']}")
    if async_report['issues']:
        for issue in async_report['issues'][:5]:  # Show first 5
            print(f"  - {issue['file']}:{issue['line']}: {issue['issue']}")
    
    print("\n" + "="*60)
    print("VALIDATION COMPLETE")
    print("="*60)
