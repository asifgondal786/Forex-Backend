import 'package:flutter/foundation.dart';

const String _apiBaseUrlDefine = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);
const String _appWebUrlDefine = String.fromEnvironment(
  'APP_WEB_URL',
  defaultValue: '',
);

void ensureReleaseBuildConfig() {
  if (kReleaseMode) {
    assert(
      _apiBaseUrlDefine != '',
      'Missing --dart-define=API_BASE_URL for release builds.',
    );
    assert(
      _appWebUrlDefine != '',
      'Missing --dart-define=APP_WEB_URL for release builds.',
    );
  }
}

