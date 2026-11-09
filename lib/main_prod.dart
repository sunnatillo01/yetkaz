import 'package:food_delivery/bootstrap.dart';
import 'package:food_delivery/core/config/app_config.dart';

/// `flutter run --flavor prod -t lib/main_prod.dart --dart-define-from-file=env/prod.json`
Future<void> main() => bootstrap(Flavor.prod);
