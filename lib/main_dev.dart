import 'package:food_delivery/bootstrap.dart';
import 'package:food_delivery/core/config/app_config.dart';

/// `flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json`
Future<void> main() => bootstrap(Flavor.dev);
