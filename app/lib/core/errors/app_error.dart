class AppError implements Exception {
  const AppError(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;

  /// Returns a user-facing message for any thrown [error].
  ///
  /// [AppError]s already carry a friendly message, so their text is used as-is.
  /// Anything else (raw network/platform exceptions) is collapsed to a generic
  /// fallback so raw exception details never reach the UI.
  static String messageFor(Object? error) {
    if (error is AppError) return error.message;

    // Detect common network/connectivity failures and give a helpful message
    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection refused') ||
        raw.contains('network request failed') ||
        raw.contains('no address associated') ||
        raw.contains('connection timed out') ||
        raw.contains('etimedout')) {
      return 'No internet connection. Check your connection and try again.';
    }

    return 'Something went wrong. Please try again.';
  }
}
