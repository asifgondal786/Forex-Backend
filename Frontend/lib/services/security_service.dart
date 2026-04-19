import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static const String _twoFaEnabledKey = 'security_two_fa_enabled';
  static const String _twoFaSecretKey = 'security_two_fa_secret';
  static const String _pendingTwoFaSecretKey =
      'security_pending_two_fa_secret';
  static const String _trustedDeviceTokenKey = 'tajir_device_token';
  static const String _trustedDevicesKey = 'security_trusted_devices';
  static const String _tradeTokenKey = 'security_trade_token';
  static const String _tradePayloadKey = 'security_trade_payload';
  static const String _tradeTokenExpiryKey = 'security_trade_token_expiry';
  static const String _tradePinHashKey = 'security_trade_pin_hash';

  static const String _placeholderQrBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jxaoAAAAASUVORK5CYII=';

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  static Future<Map<String, String>> _getDeviceInfo() async {
    return {
      'platform': _platformLabel(),
      'model': kIsWeb ? 'browser' : 'local-device',
      'os_version': defaultTargetPlatform.name,
      'app_version': kDebugMode ? 'debug' : 'release',
    };
  }

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static String _generateSecret() {
    final timestamp = DateTime.now().millisecondsSinceEpoch
        .toRadixString(36)
        .toUpperCase();
    return 'TAJIR$timestamp';
  }

  static String _generateTradeToken() {
    final token = DateTime.now().microsecondsSinceEpoch % 1000000;
    return token.toString().padLeft(6, '0');
  }

  static String _hashTradePin(String pin) =>
      Object.hashAll(pin.codeUnits).toUnsigned(32).toRadixString(16);

  static Future<List<Map<String, dynamic>>> _loadTrustedDevices() async {
    final prefs = await _prefs;
    final stored = prefs.getStringList(_trustedDevicesKey) ?? const [];
    final devices = stored
        .map((item) => jsonDecode(item))
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .where(_isTrustedDeviceActive)
        .toList();
    await _saveTrustedDevices(devices);
    return devices;
  }

  static Future<void> _saveTrustedDevices(
    List<Map<String, dynamic>> devices,
  ) async {
    final prefs = await _prefs;
    await prefs.setStringList(
      _trustedDevicesKey,
      devices.map(jsonEncode).toList(),
    );
  }

  static bool _isTrustedDeviceActive(Map<String, dynamic> device) {
    final expiresAt = DateTime.tryParse(device['expires_at']?.toString() ?? '');
    return expiresAt != null && expiresAt.isAfter(DateTime.now());
  }

  static Future<Map<String, dynamic>> setup2FA() async {
    final prefs = await _prefs;
    final secret = _generateSecret();
    await prefs.setString(_pendingTwoFaSecretKey, secret);
    return {
      'qr_code_base64': _placeholderQrBase64,
      'secret': secret,
    };
  }

  static Future<bool> verify2FASetup(String code) async {
    if (code.trim().length != 6) return false;
    final prefs = await _prefs;
    final pendingSecret = prefs.getString(_pendingTwoFaSecretKey);
    if (pendingSecret == null || pendingSecret.isEmpty) return false;

    await prefs.setBool(_twoFaEnabledKey, true);
    await prefs.setString(_twoFaSecretKey, pendingSecret);
    await prefs.remove(_pendingTwoFaSecretKey);
    return true;
  }

  static Future<bool> confirmLogin2FA(String code) async {
    final enabled = await is2FAEnabled();
    if (!enabled) return false;
    return code.trim().length == 6;
  }

  static Future<bool> is2FAEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_twoFaEnabledKey) ?? false;
  }

  static Future<bool> disable2FA(String code) async {
    if (code.trim().length != 6) return false;
    final prefs = await _prefs;
    await prefs.remove(_twoFaEnabledKey);
    await prefs.remove(_twoFaSecretKey);
    await prefs.remove(_pendingTwoFaSecretKey);
    return true;
  }

  static Future<bool> registerTrustedDevice({int trustDays = 30}) async {
    try {
      final prefs = await _prefs;
      final devices = await _loadTrustedDevices();
      final token =
          'device_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
      final deviceInfo = await _getDeviceInfo();
      final now = DateTime.now();

      devices.add({
        'device_token': token,
        'device_info': deviceInfo,
        'created_at': now.toIso8601String(),
        'expires_at': now.add(Duration(days: trustDays)).toIso8601String(),
      });

      await _saveTrustedDevices(devices);
      await prefs.setString(_trustedDeviceTokenKey, token);
      return true;
    } catch (e) {
      debugPrint('registerTrustedDevice error: $e');
      return false;
    }
  }

  static Future<bool> isDeviceTrusted() async {
    final prefs = await _prefs;
    final token = prefs.getString(_trustedDeviceTokenKey);
    if (token == null || token.isEmpty) return false;

    final devices = await _loadTrustedDevices();
    return devices.any((device) => device['device_token'] == token);
  }

  static Future<bool> revokeThisDevice() async {
    final prefs = await _prefs;
    final token = prefs.getString(_trustedDeviceTokenKey);
    if (token == null || token.isEmpty) return false;

    final devices = await _loadTrustedDevices();
    final remaining =
        devices.where((device) => device['device_token'] != token).toList();
    await _saveTrustedDevices(remaining);
    await prefs.remove(_trustedDeviceTokenKey);
    return true;
  }

  static Future<bool> revokeAllDevices() async {
    final prefs = await _prefs;
    await prefs.remove(_trustedDevicesKey);
    await prefs.remove(_trustedDeviceTokenKey);
    return true;
  }

  static Future<List<Map<String, dynamic>>> listTrustedDevices() async {
    return _loadTrustedDevices();
  }

  static Future<bool> saveTradePin(String pin) async {
    if (pin.length != 6 || int.tryParse(pin) == null) {
      return false;
    }

    final prefs = await _prefs;
    await prefs.setString(_tradePinHashKey, _hashTradePin(pin));
    return true;
  }

  static Future<bool> hasTradePin() async {
    final prefs = await _prefs;
    final stored = prefs.getString(_tradePinHashKey);
    return stored != null && stored.isNotEmpty;
  }

  static Future<bool> verifyTradePin(String pin) async {
    if (pin.length != 6 || int.tryParse(pin) == null) {
      return false;
    }

    final prefs = await _prefs;
    final stored = prefs.getString(_tradePinHashKey);
    if (stored == null || stored.isEmpty) {
      return false;
    }

    return stored == _hashTradePin(pin);
  }

  static Future<void> clearTradePin() async {
    final prefs = await _prefs;
    await prefs.remove(_tradePinHashKey);
  }

  static Future<String?> generateTradeToken(
    Map<String, dynamic> tradePayload,
  ) async {
    try {
      final prefs = await _prefs;
      final token = _generateTradeToken();
      await prefs.setString(_tradeTokenKey, token);
      await prefs.setString(_tradePayloadKey, jsonEncode(tradePayload));
      await prefs.setString(
        _tradeTokenExpiryKey,
        DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
      );
      return token;
    } catch (e) {
      debugPrint('generateTradeToken error: $e');
      return null;
    }
  }

  static Future<bool> confirmTrade(
    String token,
    Map<String, dynamic> tradePayload,
  ) async {
    final prefs = await _prefs;
    final storedToken = prefs.getString(_tradeTokenKey);
    final storedPayload = prefs.getString(_tradePayloadKey);
    final expiryString = prefs.getString(_tradeTokenExpiryKey);
    final expiry =
        expiryString != null ? DateTime.tryParse(expiryString) : null;

    final isValid = storedToken == token &&
        storedPayload == jsonEncode(tradePayload) &&
        expiry != null &&
        expiry.isAfter(DateTime.now());

    if (isValid) {
      await prefs.remove(_tradeTokenKey);
      await prefs.remove(_tradePayloadKey);
      await prefs.remove(_tradeTokenExpiryKey);
    }

    return isValid;
  }
}

