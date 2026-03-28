// ============================================================
// Phase 14 — Flutter Security Service
// D:\Tajir\Frontend\lib\services\security_service.dart
// ============================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'api_service.dart';  // your existing ApiService

class SecurityService {
  static const _storage = FlutterSecureStorage();
  static const _deviceTokenKey = 'tajir_device_token';

  // ─────────────────────────────────────────────
  // HELPERS — Device Info
  // ─────────────────────────────────────────────

  static Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = packageInfo.version;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final info = await deviceInfo.androidInfo;
      return {
        'platform': 'android',
        'model': info.model,
        'os_version': 'Android ${info.version.release}',
        'app_version': appVersion,
      };
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final info = await deviceInfo.iosInfo;
      return {
        'platform': 'ios',
        'model': info.model,
        'os_version': '${info.systemName} ${info.systemVersion}',
        'app_version': appVersion,
      };
    }
    return {
      'platform': 'unknown',
      'model': 'unknown',
      'os_version': 'unknown',
      'app_version': appVersion,
    };
  }

  // ─────────────────────────────────────────────
  // 2FA
  // ─────────────────────────────────────────────

  /// Initiate 2FA setup — returns QR code base64 and secret
  static Future<Map<String, dynamic>> setup2FA() async {
    final response = await ApiService.post('/security/2fa/setup', {});
    return response;
  }

  /// Submit TOTP code to enable 2FA after setup
  static Future<bool> verify2FASetup(String code) async {
    try {
      final response = await ApiService.post('/security/2fa/verify', {'code': code});
      return response['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Check TOTP code at login time
  static Future<bool> confirmLogin2FA(String code) async {
    try {
      final response = await ApiService.post('/security/2fa/confirm-login', {'code': code});
      return response['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Check if 2FA is enabled for current user
  static Future<bool> is2FAEnabled() async {
    try {
      final response = await ApiService.get('/security/2fa/status');
      return response['is_enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Disable 2FA — requires valid TOTP code
  static Future<bool> disable2FA(String code) async {
    try {
      final response = await ApiService.post('/security/2fa/disable', {'code': code});
      return response['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // DEVICE TRUST
  // ─────────────────────────────────────────────

  /// Register this device as trusted. Stores token in secure storage.
  static Future<bool> registerTrustedDevice({int trustDays = 30}) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final response = await ApiService.post('/security/devices/register', {
        'device_info': deviceInfo,
        'trust_days': trustDays,
      });

      final token = response['device_token'] as String?;
      if (token != null) {
        await _storage.write(key: _deviceTokenKey, value: token);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Check if this device is currently trusted. Returns true → skip 2FA prompt.
  static Future<bool> isDeviceTrusted() async {
    try {
      final token = await _storage.read(key: _deviceTokenKey);
      if (token == null) return false;

      final deviceInfo = await _getDeviceInfo();
      final response = await ApiService.post('/security/devices/check', {
        'device_token': token,
        'device_info': deviceInfo,
      });

      return response['is_trusted'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Revoke this device's trust (logout + untrust)
  static Future<bool> revokeThisDevice() async {
    try {
      final token = await _storage.read(key: _deviceTokenKey);
      if (token == null) return false;

      await ApiService.post('/security/devices/revoke', {'device_token': token});
      await _storage.delete(key: _deviceTokenKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Revoke all trusted devices (security incident response)
  static Future<bool> revokeAllDevices() async {
    try {
      await ApiService.post('/security/devices/revoke-all', {});
      await _storage.delete(key: _deviceTokenKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// List all trusted devices for the settings screen
  static Future<List<Map<String, dynamic>>> listTrustedDevices() async {
    try {
      final response = await ApiService.get('/security/devices/list');
      return List<Map<String, dynamic>>.from(response['devices'] ?? []);
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────
  // TRADE CONFIRMATION TOKEN
  // ─────────────────────────────────────────────

  /// Generate a confirmation token for a trade. Returns the token string.
  static Future<String?> generateTradeToken(Map<String, dynamic> tradePayload) async {
    try {
      final response = await ApiService.post('/security/trade/generate-token', {
        'trade_payload': tradePayload,
      });
      return response['token'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Confirm a trade using the token. Returns true if confirmed successfully.
  static Future<bool> confirmTrade(String token, Map<String, dynamic> tradePayload) async {
    try {
      final response = await ApiService.post('/security/trade/confirm', {
        'token': token,
        'trade_payload': tradePayload,
      });
      return response['confirmed'] == true;
    } catch (_) {
      return false;
    }
  }
}