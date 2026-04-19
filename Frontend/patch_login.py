import re

path = r"D:\Tajir\Frontend\lib\features\auth\login_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

rate_limit_fields = """
  // --- Rate limiting (5 attempts, 20-min lockout) ---
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 20);
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  bool get _isLockedOut {
    if (_lockedUntil == null) return false;
    if (DateTime.now().isAfter(_lockedUntil!)) {
      _lockedUntil = null;
      _failedAttempts = 0;
      return false;
    }
    return true;
  }

  String get _lockoutMessage {
    if (_lockedUntil == null) return "";
    final remaining = _lockedUntil!.difference(DateTime.now());
    final mins = remaining.inMinutes;
    final secs = remaining.inSeconds % 60;
    return "Too many attempts. Try again in ${mins}m ${secs}s.";
  }"""

content = content.replace("  String? _errorMessage;", "  String? _errorMessage;\n" + rate_limit_fields, 1)

old2 = "if (!_validateInputs()) return;"
new2 = """if (_isLockedOut) {
      setState(() => _errorMessage = _lockoutMessage);
      return;
    }
    if (!_validateInputs()) return;"""
content = content.replace(old2, new2, 1)

old3 = "setState(() => _errorMessage = _friendlyLoginError(code));"
new3 = """_failedAttempts++;
      if (_failedAttempts >= _maxAttempts) {
        _lockedUntil = DateTime.now().add(_lockoutDuration);
        setState(() => _errorMessage = "Account locked for 20 minutes after $_maxAttempts failed attempts.");
      } else {
        final rem = _maxAttempts - _failedAttempts;
        setState(() => _errorMessage = "${_friendlyLoginError(code)} ($rem attempt${rem == 1 ? "" : "s"} left)");
      }"""
content = content.replace(old3, new3, 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("Done.")
for i, line in enumerate(content.splitlines(), 1):
    if any(x in line for x in ["_maxAttempts", "_isLockedOut", "_failedAttempts"]):
        print(f"  L{i}: {line.strip()}")
