import 'package:food_delivery/core/config/app_config.dart';
import 'package:food_delivery/core/di/injection.config.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

final GetIt getIt = GetIt.instance;

@InjectableInit()
void configureDependencies(AppConfig config) {
  getIt
    ..registerSingleton<AppConfig>(config)
    ..init(environment: config.flavor.name);
}
