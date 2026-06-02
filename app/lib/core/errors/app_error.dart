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
    return 'Something went wrong. Please try again.';
  }
}
