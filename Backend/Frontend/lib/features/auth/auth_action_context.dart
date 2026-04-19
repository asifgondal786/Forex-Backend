class AuthActionContext {
  const AuthActionContext({
    required this.path,
    required this.params,
  });

  final String path;
  final Map<String, String> params;

  String get mode => (params['mode'] ?? '').trim();
  String get actionCode => (params['oobCode'] ?? '').trim();

  factory AuthActionContext.fromBaseUri([Uri? source]) {
    final uri = source ?? Uri.base;
    final directPath = _normalizePath(uri.path);
    final directParams = Map<String, String>.from(uri.queryParameters);

    final fragment = uri.fragment.trim();
    if (fragment.isEmpty) {
      return AuthActionContext(path: directPath, params: directParams);
    }

    final normalizedFragment =
        fragment.startsWith('/') ? fragment : '/$fragment';
    final fragmentUri = Uri.parse(normalizedFragment);
    final fragmentPath = _normalizePath(fragmentUri.path);
    final fragmentParams =
        Map<String, String>.from(fragmentUri.queryParameters);

    return AuthActionContext(
      path: fragmentPath != '/' ? fragmentPath : directPath,
      params: directParams.isNotEmpty ? directParams : fragmentParams,
    );
  }

  static String _normalizePath(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '/';
    }

    final normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    if (normalized.length > 1 && normalized.endsWith('/')) {
      return normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}

