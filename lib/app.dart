import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/di/injection.dart';
import 'package:food_delivery/core/l10n/gen/app_localizations.dart';
import 'package:food_delivery/core/network/connectivity_cubit.dart';
import 'package:food_delivery/core/notifications/push_notification_service.dart';
import 'package:food_delivery/core/router/routes.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/widgets/no_internet_banner.dart';
import 'package:food_delivery/features/address/presentation/bloc/address_cubits.dart';
import 'package:food_delivery/features/auth/presentation/bloc/session_cubit.dart';
import 'package:food_delivery/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:food_delivery/features/settings/domain/entities/app_settings.dart';
import 'package:food_delivery/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class App extends StatefulWidget {
  const App({required this.router, super.key});

  final GoRouter router;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  StreamSubscription<String>? _pushTaps;

  @override
  void initState() {
    super.initState();
    // Notification tapped while the app is running → open that order.
    _pushTaps = getIt<PushNotificationService>().onOrderOpened.listen(
      (id) => widget.router.push(Routes.order(id)),
    );
  }

  @override
  void dispose() {
    unawaited(_pushTaps?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: getIt<SessionCubit>()),
        BlocProvider.value(value: getIt<SettingsCubit>()),
        BlocProvider.value(value: getIt<CartCubit>()),
        BlocProvider.value(value: getIt<CurrentAddressCubit>()),
        BlocProvider.value(value: getIt<ConnectivityCubit>()),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        buildWhen: (a, b) =>
            a.settings.language != b.settings.language ||
            a.settings.themeMode != b.settings.themeMode,
        builder: (context, state) {
          final language = state.settings.language;
          return MaterialApp.router(
            onGenerateTitle: (context) => AppLocalizations.of(context).appName,
            debugShowCheckedModeBanner: false,
            routerConfig: widget.router,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: switch (state.settings.themeMode) {
              AppThemeMode.light => ThemeMode.light,
              AppThemeMode.dark => ThemeMode.dark,
              AppThemeMode.system => ThemeMode.system,
            },
            locale: language == null ? null : Locale(language.name),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            // Fallback to Uzbek when the device language is not supported.
            localeResolutionCallback: (device, supported) => supported.firstWhere(
              (l) => l.languageCode == device?.languageCode,
              orElse: () => const Locale('uz'),
            ),
            builder: (context, child) => NoInternetBanner(child: child ?? const SizedBox.shrink()),
          );
        },
      ),
    );
  }
}
