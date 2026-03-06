import 'package:flutter/foundation.dart';

String normalizeRuntimeBaseUrl(
  String value, {
  String defaultScheme = 'https',
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  final withScheme =
      trimmed.startsWith('http://') || trimmed.startsWith('https://')
          ? trimmed
          : '$defaultScheme://$trimmed';

  return withScheme.endsWith('/')
      ? withScheme.substring(0, withScheme.length - 1)
      : withScheme;
}

String? resolveCurrentWebOrigin() {
  if (!kIsWeb) {
    return null;
  }

  final scheme = Uri.base.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return null;
  }

  final origin = Uri.base.origin.trim();
  if (origin.isEmpty || origin == 'null') {
    return null;
  }

  return normalizeRuntimeBaseUrl(origin, defaultScheme: scheme);
}

String resolveAppWebUrl(String value) {
  final explicit = normalizeRuntimeBaseUrl(value);
  if (explicit.isNotEmpty) {
    _assertSecureRuntimeUrl(explicit, label: 'APP_WEB_URL');
    return explicit;
  }

  final currentOrigin = resolveCurrentWebOrigin();
  if (currentOrigin != null && currentOrigin.isNotEmpty) {
    _assertSecureRuntimeUrl(currentOrigin, label: 'APP_WEB_URL');
    return currentOrigin;
  }

  throw StateError('APP_WEB_URL is not configured.');
}

bool isLocalRuntimeUrl(String value) {
  try {
    final host = Uri.parse(value).host.toLowerCase();
    return host == 'localhost' || host == '127.0.0.1';
  } catch (_) {
    return false;
  }
}

void assertSecureRuntimeUrl(
  String value, {
  required String label,
  bool allowHttpInRelease = false,
}) {
  _assertSecureRuntimeUrl(
    value,
    label: label,
    allowHttpInRelease: allowHttpInRelease,
  );
}

void _assertSecureRuntimeUrl(
  String value, {
  required String label,
  bool allowHttpInRelease = false,
}) {
  if (kDebugMode || allowHttpInRelease) {
    return;
  }
  if (isLocalRuntimeUrl(value)) {
    return;
  }
  if (value.toLowerCase().startsWith('http://')) {
    throw StateError('$label must use HTTPS in production.');
  }
}
