/// Sink for unexpected errors (Crashlytics in production).
///
/// Kept as a tiny static hook so data-layer code can report without
/// depending on Firebase directly; bootstrap wires the real implementation.
abstract final class ErrorReporter {
  static void Function(Object error, StackTrace? stackTrace)? _sink;

  // ignore: avoid_setters_without_getters
  static set sink(void Function(Object error, StackTrace? stackTrace) value) => _sink = value;

  static void report(Object error, [StackTrace? stackTrace]) => _sink?.call(error, stackTrace);
}
