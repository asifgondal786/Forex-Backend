import 'package:shared_preferences/shared_preferences.dart';

class SecurityLockoutService {
  static const int _attemptsPerBundle = 5;
  static const List<Duration> _lockDurations = [
    Duration(minutes: 30),
    Duration(hours: 12),
    Duration(hours: 24),
    Duration(days: 7),
  ];

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  static String _normalizeIdentifier(String identifier) {
    final cleaned = identifier.trim().toLowerCase();
    if (cleaned.isEmpty) {
      return 'unknown_user';
    }

    return cleaned.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  static String _key(String identifier, String suffix) =>
      'login_lockout_${_normalizeIdentifier(identifier)}_$suffix';

  static Future<bool> isLocked(String identifier) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key(identifier, 'lock_until'));
    if (raw == null) {
      return false;
    }

    final until = DateTime.tryParse(raw);
    if (until == null) {
      await prefs.remove(_key(identifier, 'lock_until'));
      return false;
    }

    if (DateTime.now().isAfter(until)) {
      await prefs.remove(_key(identifier, 'lock_until'));
      await prefs.setInt(_key(identifier, 'attempts'), 0);
      return false;
    }

    return true;
  }

  static Future<String> lockMessage(String identifier) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key(identifier, 'lock_until'));
    if (raw == null) {
      return '';
    }

    final until = DateTime.tryParse(raw);
    if (until == null || DateTime.now().isAfter(until)) {
      return '';
    }

    final remaining = until.difference(DateTime.now());
    if (remaining.inDays >= 1) {
      return 'Account locked for ${remaining.inDays}d '
          '${remaining.inHours % 24}h.';
    }
    if (remaining.inHours >= 1) {
      return 'Account locked for ${remaining.inHours}h '
          '${remaining.inMinutes % 60}m.';
    }
    return 'Account locked for ${remaining.inMinutes}m '
        '${remaining.inSeconds % 60}s.';
  }

  static Future<LockoutState> recordFailure(String identifier) async {
    final prefs = await _prefs;
    var bundles = prefs.getInt(_key(identifier, 'bundles')) ?? 0;
    var attempts = prefs.getInt(_key(identifier, 'attempts')) ?? 0;

    attempts += 1;

    if (attempts >= _attemptsPerBundle) {
      final durationIndex = bundles < 0
          ? 0
          : bundles >= _lockDurations.length
              ? _lockDurations.length - 1
              : bundles;
      final until = DateTime.now().add(_lockDurations[durationIndex]);
      bundles += 1;
      attempts = 0;

      await prefs.setInt(_key(identifier, 'bundles'), bundles);
      await prefs.setInt(_key(identifier, 'attempts'), attempts);
      await prefs.setString(_key(identifier, 'lock_until'), until.toIso8601String());

      return LockoutState(
        locked: true,
        lockedUntil: until,
        attemptsLeft: 0,
        bundlesUsed: bundles,
      );
    }

    await prefs.setInt(_key(identifier, 'attempts'), attempts);

    return LockoutState(
      locked: false,
      attemptsLeft: _attemptsPerBundle - attempts,
      bundlesUsed: bundles,
    );
  }

  static Future<void> resetOnSuccess(String identifier) async {
    final prefs = await _prefs;
    await prefs.remove(_key(identifier, 'bundles'));
    await prefs.remove(_key(identifier, 'attempts'));
    await prefs.remove(_key(identifier, 'lock_until'));
  }

  static Future<int> attemptsLeft(String identifier) async {
    final prefs = await _prefs;
    final attempts = prefs.getInt(_key(identifier, 'attempts')) ?? 0;
    final remaining = _attemptsPerBundle - attempts;
    if (remaining < 0) {
      return 0;
    }
    if (remaining > _attemptsPerBundle) {
      return _attemptsPerBundle;
    }
    return remaining;
  }
}

class LockoutState {
  final bool locked;
  final DateTime? lockedUntil;
  final int attemptsLeft;
  final int bundlesUsed;

  const LockoutState({
    required this.locked,
    this.lockedUntil,
    required this.attemptsLeft,
    required this.bundlesUsed,
  });
}

