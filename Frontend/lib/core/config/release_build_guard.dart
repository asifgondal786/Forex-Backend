const bool _isReleaseBuild = bool.fromEnvironment('dart.vm.product');
const String _apiBaseUrlDefine = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);
const String _appWebUrlDefine = String.fromEnvironment(
  'APP_WEB_URL',
  defaultValue: '',
);

class _ReleaseBuildGuard {
  const _ReleaseBuildGuard({
    required bool isValid,
    required String message,
  }) : assert(isValid, message);
}

const _ReleaseBuildGuard _apiBaseUrlGuard = _ReleaseBuildGuard(
  isValid: !_isReleaseBuild || _apiBaseUrlDefine != '',
  message: 'Missing --dart-define=API_BASE_URL for release builds. Example: '
      '--dart-define=API_BASE_URL=https://api.your-domain.com',
);

const _ReleaseBuildGuard _appWebUrlGuard = _ReleaseBuildGuard(
  isValid: !_isReleaseBuild || _appWebUrlDefine != '',
  message: 'Missing --dart-define=APP_WEB_URL for release builds. Example: '
      '--dart-define=APP_WEB_URL=https://app.your-domain.com',
);

void ensureReleaseBuildConfig() {
  _apiBaseUrlGuard;
  _appWebUrlGuard;
}
