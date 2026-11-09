/// Build flavor of the application.
enum Flavor { dev, prod }

/// Runtime configuration resolved from `--dart-define-from-file`.
///
/// Secrets are never committed: they live in `env/<flavor>.json`
/// (git-ignored) and are injected at compile time.
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.functionsBaseUrl,
    required this.useEmulator,
    required this.emulatorHost,
  });

  factory AppConfig.fromEnvironment(Flavor flavor) => AppConfig(
    flavor: flavor,
    functionsBaseUrl: const String.fromEnvironment('FUNCTIONS_BASE_URL'),
    useEmulator: const bool.fromEnvironment('USE_FIREBASE_EMULATOR'),
    emulatorHost: const String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2'),
  );

  final Flavor flavor;

  /// Base URL of the HTTPS Cloud Functions, e.g.
  /// `https://europe-west1-yetkaz-dev.cloudfunctions.net`.
  final String functionsBaseUrl;
  final bool useEmulator;
  final String emulatorHost;

  bool get isDev => flavor == Flavor.dev;
}
